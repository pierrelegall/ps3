defmodule PS3.Storage.Filesystem do
  @moduledoc """
  Filesystem-based storage backend for PS3.

  Stores buckets and objects on the local filesystem.
  """

  @behaviour PS3.Storage

  @default_storage_root "./.s3"

  @doc """
  Returns the storage root directory.

  Defaults to `#{@default_storage_root}` if not configured.
  """
  @impl true
  def storage_root do
    Application.get_env(:ps3, :storage_root) || @default_storage_root
  end

  @doc """
  Sets the storage root directory.
  """
  def storage_root(path) when is_binary(path) do
    cond do
      valid_path?(path) ->
        Application.put_env(:ps3, :storage_root, path)
        :ok

      true ->
        {:error, "Invalid path"}
    end
  end

  @doc """
  Resets the storage root to the default (`#{@default_storage_root}`).
  """
  def reset_storage_root do
    Application.delete_env(:ps3, :storage_root)
  end

  @doc """
  Initializes the storage directory.
  """
  @impl true
  def init do
    File.rm_rf(storage_root())
    File.mkdir_p(storage_root())
    :ok
  end

  @doc """
  Clean the storage directory.
  """
  @impl true
  def clean_up do
    File.rm_rf(storage_root())
    :ok
  end

  @doc """
  Lists all buckets.
  """
  @impl true
  def list_buckets do
    with {:ok, files} <- File.ls(storage_root()) do
      buckets =
        files
        |> Enum.filter(&File.dir?(bucket_path(&1)))
        |> Enum.map(fn name ->
          stat = File.stat!(bucket_path(name), time: :posix)
          %{name: name, creation_date: DateTime.from_unix!(stat.mtime)}
        end)

      {:ok, buckets}
    end
  end

  @doc """
  Creates a bucket.
  """
  @impl true
  def create_bucket(bucket) do
    path = bucket_path(bucket)

    cond do
      File.exists?(path) ->
        {:error, :bucket_already_exists}

      true ->
        case File.mkdir_p(path) do
          :ok -> {:ok, bucket}
          {:error, reason} -> {:error, reason}
        end
    end
  end

  @doc """
  Deletes a bucket.
  """
  @impl true
  def delete_bucket(bucket) do
    path = bucket_path(bucket)

    cond do
      not File.exists?(path) ->
        {:error, :no_such_bucket}

      true ->
        case File.ls(path) do
          {:ok, []} ->
            File.rmdir(path)

          {:ok, _} ->
            {:error, :bucket_not_empty}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  @doc """
  Lists objects in a bucket.
  """
  @impl true
  def list_objects(bucket) do
    path = bucket_path(bucket)

    cond do
      not File.exists?(path) ->
        {:error, :no_such_bucket}

      true ->
        objects = list_objects_recursive(path, "")
        {:ok, objects}
    end
  end

  @doc """
  Stores an object.
  """
  @impl true
  def put_object(bucket, key, data) do
    bucket_dir = bucket_path(bucket)

    cond do
      not File.exists?(bucket_dir) ->
        {:error, :no_such_bucket}

      true ->
        object_path = object_path(bucket, key)
        object_dir = Path.dirname(object_path)

        with :ok <- File.mkdir_p(object_dir),
             :ok <- File.write(object_path, data) do
          {:ok, key}
        end
    end
  end

  @doc """
  Retrieves an object.
  """
  @impl true
  def get_object(bucket, key) do
    path = object_path(bucket, key)

    cond do
      File.exists?(path) ->
        File.read(path)

      true ->
        {:error, :no_such_key}
    end
  end

  @doc """
  Deletes an object.
  """
  @impl true
  def delete_object(bucket, key) do
    path = object_path(bucket, key)

    cond do
      File.exists?(path) ->
        File.rm(path)

      true ->
        {:error, :no_such_key}
    end
  end

  # Private helpers

  defp bucket_path(bucket) do
    Path.join(storage_root(), bucket)
  end

  defp object_path(bucket, key) do
    Path.join(bucket_path(bucket), key)
  end

  defp list_objects_recursive(dir, prefix) do
    case File.ls(dir) do
      {:ok, files} ->
        Enum.flat_map(files, &process_file(dir, prefix, &1))

      {:error, _} ->
        []
    end
  end

  defp process_file(dir, prefix, file) do
    full_path = Path.join(dir, file)

    relative_key =
      cond do
        prefix == "" -> file
        true -> Path.join(prefix, file)
      end

    cond do
      File.dir?(full_path) ->
        list_objects_recursive(full_path, relative_key)

      true ->
        stat = File.stat!(full_path, time: :posix)

        [
          %{
            key: relative_key,
            size: stat.size,
            last_modified: DateTime.from_unix!(stat.mtime)
          }
        ]
    end
  end

  defp valid_path?(path) do
    path != ""
  end
end
