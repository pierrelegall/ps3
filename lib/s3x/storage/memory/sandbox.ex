defmodule S3x.Storage.Memory.Sandbox do
  @moduledoc """
  Process-isolated storage for concurrent tests using per-process ETS tables.
  """

  @buckets_table_key {__MODULE__, :buckets_table}
  @objects_table_key {__MODULE__, :objects_table}

  @doc """
  Returns the buckets table reference for the current process.

  Creates the table lazily if it doesn't exist yet.
  """
  @spec get_buckets_table() :: :ets.tid()
  def get_buckets_table do
    case Process.get(@buckets_table_key) do
      nil -> create_buckets_table()
      table -> table
    end
  end

  @doc """
  Returns the objects table reference for the current process.

  Creates the table lazily if it doesn't exist yet.
  """
  @spec get_objects_table() :: :ets.tid()
  def get_objects_table do
    case Process.get(@objects_table_key) do
      nil -> create_objects_table()
      table -> table
    end
  end

  defp create_buckets_table do
    table = :ets.new(:buckets, [:set, :public])
    Process.put(@buckets_table_key, table)
    table
  end

  defp create_objects_table do
    table = :ets.new(:objects, [:set, :public])
    Process.put(@objects_table_key, table)
    table
  end
end
