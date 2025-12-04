defmodule S3x.Storage.Memory do
  @moduledoc """
  In-memory storage backend for S3x using ETS (Erlang Term Storage).
  """

  @behaviour S3x.Storage

  # Default global table names
  @buckets_table :s3x_buckets
  @objects_table :s3x_objects

  @doc """
  Returns `nil` as storage root (not used by memory backend).
  """
  @impl true
  def storage_root do
    nil
  end

  @doc """
  Initializes the Memory backend.

  ## Behavior by mode:

  - **Non-sandbox mode** (default): Creates global named ETS tables
    (`:s3x_buckets`, `:s3x_objects`) if they don't exist. Named tables persist
    until explicitly deleted or the VM shuts down, and are shared across all
    processes.

  - **Sandbox mode** (`sandbox_mode: true`): Creates per-process unnamed ETS tables
    for the current process via `S3x.Storage.Memory.Sandbox`. Each process gets
    isolated tables that are automatically cleaned up when the process exits.
    While tables are normally created lazily on first access, calling `init/0`
    explicitly ensures they exist upfront.

  This is idempotent and can be called multiple times safely.
  """
  @impl true
  def init do
    case sandbox_mode?() do
      true ->
        # Initialize sandbox tables for the current process
        S3x.Storage.Memory.Sandbox.get_buckets_table()
        S3x.Storage.Memory.Sandbox.get_objects_table()
        :ok

      false ->
        # Create named tables if they don't exist
        if :ets.whereis(@buckets_table) == :undefined do
          :ets.new(@buckets_table, [:set, :public, :named_table])
        end

        if :ets.whereis(@objects_table) == :undefined do
          :ets.new(@objects_table, [:set, :public, :named_table])
        end

        :ok
    end
  end

  @doc """
  Cleans up the Memory backend storage.
  """
  @impl true
  def clean do
    :ets.delete_all_objects(get_buckets_table())
    :ets.delete_all_objects(get_objects_table())
    :ok
  end

  @doc """
  Lists all buckets.
  """
  @impl true
  def list_buckets do
    buckets =
      get_buckets_table()
      |> :ets.tab2list()
      |> Enum.map(fn {name, creation_date} ->
        %{name: name, creation_date: creation_date}
      end)

    {:ok, buckets}
  end

  @doc """
  Creates a bucket.
  """
  @impl true
  def create_bucket(bucket) do
    case :ets.insert_new(get_buckets_table(), {bucket, DateTime.utc_now()}) do
      true -> {:ok, bucket}
      false -> {:error, :bucket_already_exists}
    end
  end

  @doc """
  Deletes a bucket.
  """
  @impl true
  def delete_bucket(bucket) do
    cond do
      not bucket_exists?(bucket) ->
        {:error, :no_such_bucket}

      bucket_has_objects?(bucket) ->
        {:error, :bucket_not_empty}

      true ->
        :ets.delete(get_buckets_table(), bucket)
        :ok
    end
  end

  @doc """
  Lists objects in a bucket.
  """
  @impl true
  def list_objects(bucket) do
    cond do
      not bucket_exists?(bucket) ->
        {:error, :no_such_bucket}

      true ->
        objects =
          get_objects_table()
          |> :ets.tab2list()
          |> Enum.filter(fn {{b, _key}, _data, _size, _modified} -> b == bucket end)
          |> Enum.map(fn {{_bucket, key}, _data, size, last_modified} ->
            %{
              key: key,
              size: size,
              last_modified: last_modified
            }
          end)

        {:ok, objects}
    end
  end

  @doc """
  Stores an object.
  """
  @impl true
  def put_object(bucket, key, data) do
    cond do
      not bucket_exists?(bucket) ->
        {:error, :no_such_bucket}

      true ->
        size = byte_size(data)
        last_modified = DateTime.utc_now()
        :ets.insert(get_objects_table(), {{bucket, key}, data, size, last_modified})
        {:ok, key}
    end
  end

  @doc """
  Retrieves an object.
  """
  @impl true
  def get_object(bucket, key) do
    case :ets.lookup(get_objects_table(), {bucket, key}) do
      [{{^bucket, ^key}, data, _size, _modified}] ->
        {:ok, data}

      [] ->
        {:error, :no_such_key}
    end
  end

  @doc """
  Deletes an object.
  """
  @impl true
  def delete_object(bucket, key) do
    case :ets.lookup(get_objects_table(), {bucket, key}) do
      [{{^bucket, ^key}, _data, _size, _modified}] ->
        :ets.delete(get_objects_table(), {bucket, key})
        :ok

      [] ->
        {:error, :no_such_key}
    end
  end

  # Private helpers

  defp get_buckets_table do
    case sandbox_mode?() do
      true -> S3x.Storage.Memory.Sandbox.get_buckets_table()
      false -> @buckets_table
    end
  end

  defp get_objects_table do
    case sandbox_mode?() do
      true -> S3x.Storage.Memory.Sandbox.get_objects_table()
      false -> @objects_table
    end
  end

  defp sandbox_mode? do
    Application.get_env(:s3x, :sandbox_mode) == true
  end

  defp bucket_exists?(bucket) do
    case :ets.lookup(get_buckets_table(), bucket) do
      [{^bucket, _}] -> true
      [] -> false
    end
  end

  defp bucket_has_objects?(bucket) do
    match_spec = [{{{bucket, :_}, :_, :_, :_}, [], [true]}]
    :ets.select_count(get_objects_table(), match_spec) > 0
  end
end
