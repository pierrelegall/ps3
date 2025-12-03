defmodule S3x.Storage.Memory.Server do
  @moduledoc """
  GenServer that owns the ETS tables for the Memory storage backend.

  This server ensures that the ETS tables persist for the lifetime of the
  Memory backend usage. The tables are created as public so they can be
  accessed by any process, but are owned by this server to prevent them
  from being deleted when individual processes exit.
  """
  use GenServer

  @buckets_table :s3x_buckets
  @objects_table :s3x_objects

  @doc """
  Starts the Memory server and creates the ETS tables.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, Keyword.put_new(opts, :name, __MODULE__))
  end

  @doc """
  Ensures the server is running and tables are initialized.

  This is idempotent and can be called multiple times safely.
  Uses a global lock to prevent race conditions during concurrent initialization.
  """
  def ensure_started do
    :global.trans({__MODULE__, :start}, fn ->
      case Process.whereis(__MODULE__) do
        nil ->
          # Server not running, start it
          case start_link() do
            {:ok, _pid} -> :ok
            {:error, {:already_started, _pid}} -> :ok
            {:error, reason} -> {:error, reason}
          end

        pid ->
          # Server exists, verify it's alive and tables exist
          if Process.alive?(pid) and tables_exist?() do
            :ok
          else
            # Clean up dead process or missing tables
            if Process.alive?(pid), do: GenServer.stop(pid, :normal)

            # Start fresh
            case start_link() do
              {:ok, _pid} -> :ok
              {:error, {:already_started, _pid}} -> :ok
              {:error, reason} -> {:error, reason}
            end
          end
      end
    end)
  end

  @doc """
  Returns the name of the buckets ETS table.
  """
  def buckets_table, do: @buckets_table

  @doc """
  Returns the name of the objects ETS table.
  """
  def objects_table, do: @objects_table

  defp tables_exist? do
    :ets.whereis(@buckets_table) != :undefined and
      :ets.whereis(@objects_table) != :undefined
  end

  @impl true
  def init(:ok) do
    # Create the ETS tables if they don't exist
    # Tables are public so any process can read/write
    # but owned by this GenServer so they persist
    if :ets.whereis(@buckets_table) == :undefined do
      :ets.new(@buckets_table, [:set, :public, :named_table])
    end

    if :ets.whereis(@objects_table) == :undefined do
      :ets.new(@objects_table, [:set, :public, :named_table])
    end

    {:ok, :ok}
  end
end
