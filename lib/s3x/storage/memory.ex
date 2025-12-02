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
  Initializes the ETS tables for buckets and objects.
  """
  @impl true
  def init do
    # Create tables if they don't exist
    # Use :set for both (unique keys)
    # Make them :public so any process can access
    # Use :named_table so we can reference by name
    if :ets.whereis(@buckets_table) == :undefined do
      :ets.new(@buckets_table, [:set, :public, :named_table])
    end

    if :ets.whereis(@objects_table) == :undefined do
      :ets.new(@objects_table, [:set, :public, :named_table])
    end

    :ok
  end

  @doc """
  Lists all buckets.
  """
  @impl true
  def list_buckets do
    buckets =
      @buckets_table
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
    case :ets.insert_new(@buckets_table, {bucket, DateTime.utc_now()}) do
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
        :ets.delete(@buckets_table, bucket)
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
          @objects_table
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
        :ets.insert(@objects_table, {{bucket, key}, data, size, last_modified})
        {:ok, key}
    end
  end

  @doc """
  Retrieves an object.
  """
  @impl true
  def get_object(bucket, key) do
    case :ets.lookup(@objects_table, {bucket, key}) do
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
    case :ets.lookup(@objects_table, {bucket, key}) do
      [{{^bucket, ^key}, _data, _size, _modified}] ->
        :ets.delete(@objects_table, {bucket, key})
        :ok

      [] ->
        {:error, :no_such_key}
    end
  end

  # Private helpers

  defp bucket_exists?(bucket) do
    case :ets.lookup(@buckets_table, bucket) do
      [{^bucket, _}] -> true
      [] -> false
    end
  end

  defp bucket_has_objects?(bucket) do
    # Check if there are any objects in this bucket
    match_spec = [
      {{{:"$1", :_}, :_, :_, :_}, [{:==, :"$1", bucket}], [true]}
    ]

    case :ets.select(@objects_table, match_spec, 1) do
      {_results, _continuation} -> true
      :"$end_of_table" -> false
    end
  end
end
