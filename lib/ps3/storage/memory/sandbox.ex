defmodule PS3.Storage.Memory.Sandbox do
  @moduledoc """
  Process-isolated storage for concurrent tests using per-process ETS tables.

  This module provides an ownership model similar to `Ecto.Adapters.SQL.Sandbox`,
  allowing integration tests to share sandbox tables across process boundaries
  (e.g., test process and HTTP handler process).

  ## Ownership Model

  Each test process can "own" a set of sandbox tables and explicitly "allow"
  other processes (like HTTP handlers) to use them. This enables:

  - Concurrent unit tests with isolated data
  - Integration tests where HTTP handlers access the test's sandbox
  - Async test execution without race conditions

  ## Modes

  - `:auto` - Processes automatically get a sandbox on first access (default)
  - `:manual` - Processes must explicitly checkout or be allowed
  - `{:shared, pid}` - All processes use the specified owner's sandbox

  ## Usage

  ### Unit Tests (auto mode)

  In auto mode, each process gets its own sandbox automatically:

      # test/test_helper.exs
      PS3.Storage.Memory.Sandbox.mode(:auto)

      # Tests run with async: true and isolated data

  ### Integration Tests

  For integration tests that make HTTP requests:

      setup do
        pid = PS3.Storage.Memory.Sandbox.start_owner!()
        on_exit(fn -> PS3.Storage.Memory.Sandbox.stop_owner(pid) end)

        # Encode owner for HTTP header
        owner = PS3.Storage.Memory.Sandbox.encode_metadata(pid)
        {:ok, sandbox_owner: owner}
      end

      test "HTTP request uses test sandbox", %{sandbox_owner: owner} do
        {:ok, _} =
          ExAws.S3.put_bucket("test", "local")
          |> ExAws.request(headers: [{"x-ps3-sandbox-owner", owner}])
      end

  See `Ecto.Adapters.SQL.Sandbox` for more details on the ownership pattern.
  """

  @registry_table :ps3_sandbox_ownership

  # ============================================================================
  # Sandbox Status
  # ============================================================================

  @doc """
  Returns `true` if sandbox mode is enabled.

  Sandbox is enabled when `mode/1` has been called with a valid mode
  (`:auto`, `:manual`, or `{:shared, pid}`).

  ## Examples

      iex> PS3.Storage.Memory.Sandbox.enabled?()
      false

      iex> PS3.Storage.Memory.Sandbox.mode(:auto)
      :ok

      iex> PS3.Storage.Memory.Sandbox.enabled?()
      true

  """
  @spec enabled?() :: boolean()
  def enabled? do
    mode() != nil
  end

  # ============================================================================
  # Ownership API (matching Ecto.Adapters.SQL.Sandbox)
  # ============================================================================

  @doc """
  Checks out a sandbox for the current process.

  Creates ETS tables for the current process and registers it as owner.

  ## Return values

  - `:ok` - Successfully checked out
  - `{:already, :owner}` - Process is already an owner
  - `{:already, :allowed}` - Process is already allowed by another owner

  ## Examples

      iex> PS3.Storage.Memory.Sandbox.checkout()
      :ok

      iex> PS3.Storage.Memory.Sandbox.checkout()
      {:already, :owner}

  """
  @spec checkout(keyword()) :: :ok | {:already, :owner | :allowed}
  def checkout(opts \\ []) do
    _ = opts

    case lookup_status(self()) do
      {:ok, :owner, _tables} ->
        {:already, :owner}

      {:ok, {:allowed, _owner}, _} ->
        {:already, :allowed}

      :not_found ->
        tables = create_tables()
        register_owner(self(), tables)
        :ok
    end
  end

  @doc """
  Checks in the sandbox for the current process.

  Removes ownership, deletes ETS tables, and cleans up any allowances.

  ## Examples

      iex> PS3.Storage.Memory.Sandbox.checkout()
      :ok

      iex> PS3.Storage.Memory.Sandbox.checkin()
      :ok

  """
  @spec checkin() :: :ok
  def checkin do
    pid = self()

    case lookup_status(pid) do
      {:ok, :owner, {buckets, objects}} ->
        # Remove any processes that were allowed by this owner
        cleanup_allowances(pid)

        # Delete ETS tables
        safe_delete_table(buckets)
        safe_delete_table(objects)

        # Remove from registry
        :ets.delete(@registry_table, pid)

      _ ->
        :ok
    end

    :ok
  end

  @doc """
  Allows a process to use another process's sandbox.

  The `parent` must be an owner (have checked out). The `allow` process
  will then be able to access the parent's sandbox tables.

  ## Parameters

  - `parent` - The owner PID whose sandbox to share
  - `allow` - The PID to grant access to
  - `opts` - Options (currently unused, for Ecto API compatibility)

  ## Return values

  - `:ok` - Successfully allowed
  - `{:already, :owner}` - The `allow` process is already an owner
  - `{:already, :allowed}` - The `allow` process is already allowed
  - `:not_found` - The `parent` is not an owner

  ## Examples

      iex> PS3.Storage.Memory.Sandbox.checkout()
      :ok

      iex> PS3.Storage.Memory.Sandbox.allow(self(), spawn(fn -> :ok end))
      :ok

  """
  @spec allow(pid(), pid(), keyword()) :: :ok | {:already, :owner | :allowed} | :not_found
  def allow(parent, allow, opts \\ []) do
    _ = opts

    case lookup_status(parent) do
      {:ok, :owner, _tables} ->
        case lookup_status(allow) do
          {:ok, :owner, _} ->
            {:already, :owner}

          {:ok, {:allowed, _}, _} ->
            {:already, :allowed}

          :not_found ->
            register_allowed(allow, parent)
            :ok
        end

      _ ->
        :not_found
    end
  end

  @doc """
  Forces a process to use another process's sandbox, replacing any existing allowance.

  Unlike `allow/3`, this unconditionally updates the allowance even if the
  process is already allowed by a different owner. Used by `SandboxAllowance`
  when a long-lived handler process is reused across different test requests.
  """
  @spec force_allow(pid(), pid()) :: :ok | :not_found
  def force_allow(parent, allow) do
    case lookup_status(parent) do
      {:ok, :owner, _tables} ->
        register_allowed(allow, parent)
        :ok

      _ ->
        :not_found
    end
  end

  @doc """
  Returns the current sandbox mode.

  Returns `:auto`, `:manual`, `{:shared, pid}`, or `nil` if not set.
  """
  @spec mode() :: :auto | :manual | {:shared, pid()} | nil
  def mode do
    Application.get_env(:ps3, :memory_sandbox_mode)
  end

  @doc """
  Sets the sandbox mode.

  ## Modes

  - `:auto` - Processes automatically get a sandbox on first access
  - `:manual` - Processes must explicitly checkout or be allowed
  - `{:shared, pid}` - All processes use the specified owner's sandbox

  ## Return values

  - `:ok` - Mode set successfully
  - `:already_shared` - Already in shared mode with this pid
  - `:not_owner` - Shared pid is registered but not as owner
  - `:not_found` - Shared pid is not in registry

  ## Examples

      iex> PS3.Storage.Memory.Sandbox.mode(:manual)
      :ok

      iex> PS3.Storage.Memory.Sandbox.checkout()
      :ok

      iex> PS3.Storage.Memory.Sandbox.mode({:shared, self()})
      :ok

  """
  @spec mode(:auto | :manual | {:shared, pid()}) ::
          :ok | :already_shared | :not_owner | :not_found
  def mode(mode) when mode in [:auto, :manual] do
    Application.put_env(:ps3, :memory_sandbox_mode, mode)
    :ok
  end

  def mode({:shared, pid}) when is_pid(pid) do
    current_mode = mode()

    if current_mode == {:shared, pid} do
      :already_shared
    else
      case lookup_status(pid) do
        {:ok, :owner, _tables} ->
          Application.put_env(:ps3, :memory_sandbox_mode, {:shared, pid})
          :ok

        {:ok, {:allowed, _}, _} ->
          :not_owner

        :not_found ->
          :not_found
      end
    end
  end

  @doc """
  Resets the sandbox mode, disabling the sandbox.
  """
  @spec reset_mode() :: :ok
  def reset_mode do
    Application.delete_env(:ps3, :memory_sandbox_mode)
    :ok
  end

  @doc """
  Starts an owner process.

  Spawns a linked process that checks out a sandbox. The owner process
  is linked to the calling process, so it will be terminated when the
  test process exits.

  This is the recommended API for test setup.

  ## Options

  - `:shared` - If `true`, sets the sandbox to shared mode so all processes
    use this owner's sandbox. Useful for non-async tests. Default: `false`.

  ## Examples

      # Async test (default)
      setup do
        pid = PS3.Storage.Memory.Sandbox.start_owner!()
        on_exit(fn -> PS3.Storage.Memory.Sandbox.stop_owner(pid) end)
        {:ok, owner: pid}
      end

      # Non-async test (shared mode)
      setup do
        pid = PS3.Storage.Memory.Sandbox.start_owner!(shared: true)
        on_exit(fn -> PS3.Storage.Memory.Sandbox.stop_owner(pid) end)
        {:ok, owner: pid}
      end

      # Phoenix DataCase style
      def setup_sandbox(tags) do
        pid = PS3.Storage.Memory.Sandbox.start_owner!(shared: not tags[:async])
        on_exit(fn -> PS3.Storage.Memory.Sandbox.stop_owner(pid) end)
      end

  """
  @spec start_owner!(keyword()) :: pid()
  def start_owner!(opts \\ []) do
    caller = self()

    {:ok, pid} =
      Task.start_link(fn ->
        checkout(opts)

        # Notify caller that checkout is complete
        send(caller, {:sandbox_owner_ready, self()})

        # Keep the process alive
        Process.sleep(:infinity)
      end)

    # Wait for checkout to complete
    receive do
      {:sandbox_owner_ready, ^pid} ->
        if opts[:shared] do
          mode({:shared, pid})
        end

        pid
    after
      5000 -> raise "Timeout waiting for sandbox owner to start"
    end
  end

  @doc """
  Stops an owner process.

  Terminates the owner process and cleans up its sandbox tables.

  ## Examples

      pid = PS3.Storage.Memory.Sandbox.start_owner!()
      PS3.Storage.Memory.Sandbox.stop_owner(pid)
      :ok

  """
  @spec stop_owner(pid()) :: :ok
  def stop_owner(pid) do
    # Reset shared mode if this pid was the shared owner
    case mode() do
      {:shared, ^pid} -> mode(:auto)
      _ -> :ok
    end

    # Clean up ownership entry before killing the process
    case lookup_status(pid) do
      {:ok, :owner, {buckets, objects}} ->
        cleanup_allowances(pid)
        safe_delete_table(buckets)
        safe_delete_table(objects)
        :ets.delete(@registry_table, pid)

      _ ->
        :ok
    end

    # Unlink and kill the process
    Process.unlink(pid)
    Process.exit(pid, :shutdown)
    :ok
  end

  @doc """
  Looks up which PID owns the sandbox for the given process.

  Returns `{:ok, owner_pid}` if the process is an owner or is allowed by an owner,
  or `:not_found` if the process has no sandbox.

  ## Examples

      iex> PS3.Storage.Memory.Sandbox.checkout()
      :ok

      iex> PS3.Storage.Memory.Sandbox.lookup_owner(self())
      {:ok, self()}

  """
  @spec lookup_owner(pid()) :: {:ok, pid()} | :not_found
  def lookup_owner(pid) do
    case lookup_status(pid) do
      {:ok, :owner, _tables} -> {:ok, pid}
      {:ok, {:allowed, owner}, _} -> {:ok, owner}
      :not_found -> :not_found
    end
  end

  # ============================================================================
  # Table Access (called by PS3.Storage.Memory)
  # ============================================================================

  @doc """
  Returns the buckets table reference for the current process.

  Resolves tables through the ownership chain:
  1. If process is owner, returns its tables
  2. If process is allowed, returns owner's tables
  3. If shared mode, returns shared owner's tables
  4. If auto mode, creates new tables
  5. If manual mode, raises error

  """
  @spec get_buckets_table() :: :ets.tid()
  def get_buckets_table do
    case find_tables(self()) do
      {:ok, {buckets, _objects}} ->
        buckets

      :not_found ->
        handle_not_found(:buckets)
    end
  end

  @doc """
  Returns the objects table reference for the current process.

  Uses the same resolution logic as `get_buckets_table/0`.
  """
  @spec get_objects_table() :: :ets.tid()
  def get_objects_table do
    case find_tables(self()) do
      {:ok, {_buckets, objects}} ->
        objects

      :not_found ->
        handle_not_found(:objects)
    end
  end

  # ============================================================================
  # Metadata Encoding (matching Phoenix.Ecto.SQL.Sandbox)
  # ============================================================================

  @doc """
  Encodes an owner PID for transport (e.g., HTTP header).

  ## Examples

      iex> pid = PS3.Storage.Memory.Sandbox.start_owner!()
      iex> encoded = PS3.Storage.Memory.Sandbox.encode_metadata(pid)
      iex> is_binary(encoded)
      true

  """
  @spec encode_metadata(pid()) :: binary()
  def encode_metadata(pid) when is_pid(pid) do
    pid
    |> :erlang.term_to_binary()
    |> Base.url_encode64()
  end

  @doc """
  Decodes an owner PID from transport encoding.

  ## Examples

      iex> pid = PS3.Storage.Memory.Sandbox.start_owner!()
      iex> encoded = PS3.Storage.Memory.Sandbox.encode_metadata(pid)
      iex> PS3.Storage.Memory.Sandbox.decode_metadata(encoded)
      pid

  """
  @spec decode_metadata(binary()) :: pid()
  def decode_metadata(encoded) when is_binary(encoded) do
    encoded
    |> Base.url_decode64!()
    |> :erlang.binary_to_term()
  end

  # ============================================================================
  # Internal Helpers
  # ============================================================================

  @doc false
  @spec find_tables(pid()) :: {:ok, {:ets.tid(), :ets.tid()}} | :not_found
  def find_tables(pid) do
    case lookup_status(pid) do
      {:ok, :owner, tables} ->
        {:ok, tables}

      {:ok, {:allowed, owner}, _} ->
        find_owner_tables(owner)

      :not_found ->
        find_tables_in_shared_mode()
    end
  end

  defp find_owner_tables(owner) do
    case lookup_status(owner) do
      {:ok, :owner, tables} -> {:ok, tables}
      _ -> :not_found
    end
  end

  defp find_tables_in_shared_mode do
    case mode() do
      {:shared, shared_pid} -> find_owner_tables(shared_pid)
      _ -> :not_found
    end
  end

  defp lookup_status(pid) do
    case :ets.lookup(@registry_table, pid) do
      [{^pid, :owner, tables}] -> {:ok, :owner, tables}
      [{^pid, {:allowed, owner}}] -> {:ok, {:allowed, owner}, nil}
      [] -> :not_found
    end
  end

  defp handle_not_found(table_type) do
    case mode() do
      :auto ->
        # Auto-create tables for this process
        tables = create_tables()
        register_owner(self(), tables)

        case table_type do
          :buckets -> elem(tables, 0)
          :objects -> elem(tables, 1)
        end

      :manual ->
        raise """
        Sandbox is not checked out for process #{inspect(self())}.

        You must call PS3.Storage.Memory.Sandbox.checkout() or be allowed by an owner.
        For integration tests, use PS3.Storage.Memory.Sandbox.start_owner!() in setup.
        """

      {:shared, _} ->
        raise """
        Shared sandbox owner is not available.

        The shared owner process may have exited. Check your test setup.
        """

      nil ->
        raise """
        Sandbox is not enabled.

        Call PS3.Storage.Memory.Sandbox.mode(:auto) in test_helper.exs to enable sandbox.
        """
    end
  end

  defp create_tables do
    buckets = :ets.new(:sandbox_buckets, [:set, :public])
    objects = :ets.new(:sandbox_objects, [:set, :public])
    {buckets, objects}
  end

  defp register_owner(pid, tables) do
    :ets.insert(@registry_table, {pid, :owner, tables})
  end

  defp register_allowed(pid, owner) do
    :ets.insert(@registry_table, {pid, {:allowed, owner}})
  end

  defp cleanup_allowances(owner_pid) do
    # Find and remove all processes allowed by this owner
    match_spec = [{{:"$1", {:allowed, owner_pid}}, [], [:"$1"]}]
    allowed_pids = :ets.select(@registry_table, match_spec)

    Enum.each(allowed_pids, fn pid ->
      :ets.delete(@registry_table, pid)
    end)
  end

  defp safe_delete_table(table) do
    :ets.delete(table)
  rescue
    ArgumentError -> :ok
  end
end
