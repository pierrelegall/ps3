defmodule S3x.Storage.Memory do
  @moduledoc """
  In-memory storage backend for S3x using ETS (Erlang Term Storage).

  This backend stores all data in memory using ETS tables, making it ideal for:
  - Fast test execution (no disk I/O)
  - Development environments where persistence isn't needed
  - Avoiding SSD wear during testing

  Data is automatically cleared when the application stops.

  ## Configuration

  In your project's `config/test.exs`:

      config :s3x,
        storage_backend: S3x.Storage.Memory

  """

  @behaviour S3x.Storage

  # Default global table names
  @buckets_table :s3x_buckets
  @objects_table :s3x_objects

  @doc """
  Returns a dummy storage root (not used by memory backend).
  """
  @impl true
  def storage_root do
    ":memory:"
  end

  @doc """
  Initializes the Memory backend by ensuring the server is running.

  The server owns the ETS tables to ensure they persist for the lifetime of the backend.
  This is idempotent and can be called multiple times safely.
  """
  @impl true
  def init do
    S3x.Storage.Memory.Server.ensure_started()
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
    # Check if there are any objects in this bucket
    match_spec = [
      {{{:"$1", :_}, :_, :_, :_}, [{:==, :"$1", bucket}], [true]}
    ]

    case :ets.select(get_objects_table(), match_spec, 1) do
      {_results, _continuation} -> true
      :"$end_of_table" -> false
    end
  end
end
