defmodule S3x.Storage.Memory.Sandbox do
  @moduledoc """
  Process-isolated storage for concurrent tests using per-process ETS tables.

  ## Configuration

  In your `config/test.exs`:

      config :s3x,
        storage_backend: S3x.Storage.Memory,
        sandbox_mode: true

  ## Usage

  In test files with `async: true`:

      setup do
        :ok = S3x.Storage.Memory.Sandbox.checkout()
      end

  ## How It Works

  - **Per-process isolation**: Each test must explicitly checkout storage
  - **Checkout**: Creates unnamed ETS tables for the current process
  - **ETS ownership**: Tables are owned by the test process and die with it
  - **Automatic cleanup**: No manual cleanup needed
  """

  @buckets_table_key {__MODULE__, :buckets_table}
  @objects_table_key {__MODULE__, :objects_table}

  @doc """
  Checks out isolated ETS tables for the current process.

  Creates two unnamed ETS tables (buckets and objects) owned by the calling process.
  These tables will be automatically deleted when the process exits.

  Must be called before using storage operations in tests.

  ## Examples

      setup do
        :ok = S3x.Storage.Memory.Sandbox.checkout()
      end
  """
  @spec checkout() :: :ok | {:error, :already_checked_out}
  def checkout do
    case Process.get(@buckets_table_key) do
      nil ->
        # Create unnamed ETS tables owned by this process
        buckets_table = :ets.new(:buckets, [:set, :public])
        objects_table = :ets.new(:objects, [:set, :public])

        # Store table references in process dictionary
        Process.put(@buckets_table_key, buckets_table)
        Process.put(@objects_table_key, objects_table)
        :ok

      _existing ->
        {:error, :already_checked_out}
    end
  end

  @doc """
  Checks in (releases) ETS tables for the current process.

  This is optional - tables are automatically deleted when the process exits.

  ## Examples

      S3x.Storage.Memory.Sandbox.checkin()
  """
  @spec checkin() :: :ok
  def checkin do
    # Delete the ETS tables if they exist
    case Process.get(@buckets_table_key) do
      nil -> :ok
      table -> :ets.delete(table)
    end

    case Process.get(@objects_table_key) do
      nil -> :ok
      table -> :ets.delete(table)
    end

    # Remove references from process dictionary
    Process.delete(@buckets_table_key)
    Process.delete(@objects_table_key)
    :ok
  end

  @doc """
  Returns the buckets table reference for the current process.

  Raises if not checked out.
  """
  @spec get_buckets_table() :: :ets.tid()
  def get_buckets_table do
    case Process.get(@buckets_table_key) do
      nil -> raise_not_checked_out()
      table -> table
    end
  end

  @doc """
  Returns the objects table reference for the current process.

  Raises if not checked out.
  """
  @spec get_objects_table() :: :ets.tid()
  def get_objects_table do
    case Process.get(@objects_table_key) do
      nil -> raise_not_checked_out()
      table -> table
    end
  end

  defp raise_not_checked_out do
    raise """
    The current process has not checked out sandbox storage.

    You must call S3x.Storage.Memory.Sandbox.checkout() before using storage operations.

    In your test file, add:

        setup do
          :ok = S3x.Storage.Memory.Sandbox.checkout()
        end

    See S3x.Storage.Memory.Sandbox documentation for more details.
    """
  end
end
