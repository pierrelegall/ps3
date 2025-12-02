defmodule S3x.Storage do
  @moduledoc """
  Storage backend for S3x that handles file operations on the local filesystem.
  """

  @storage_root Application.compile_env(:s3x, :storage_root, "./.s3")

  @doc """
  Returns the storage root directory.
  """
  def storage_root, do: System.get_env("S3X_STORAGE_ROOT", @storage_root)

  @doc """
  Initializes the storage directory.
  """
  def init do
    File.mkdir_p(storage_root())
  end

  @doc """
  Lists all buckets.
  """
  def list_buckets do
    with {:ok, files} <- File.ls(storage_root()) do
      buckets =
        files
        |> Enum.filter(&File.dir?(bucket_path(&1)))
        |> Enum.map(fn name ->
          stat = File.stat!(bucket_path(name))
          %{name: name, creation_date: stat.mtime}
        end)

      {:ok, buckets}
    end
  end

  @doc """
  Creates a bucket.
  """
  def create_bucket(bucket) do
    path = bucket_path(bucket)

    if File.exists?(path) do
      {:error, :bucket_already_exists}
    else
      case File.mkdir_p(path) do
        :ok -> {:ok, bucket}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc """
  Deletes a bucket.
  """
  def delete_bucket(bucket) do
    path = bucket_path(bucket)

    if not File.exists?(path) do
      {:error, :no_such_bucket}
    else
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
  def list_objects(bucket) do
    path = bucket_path(bucket)

    if not File.exists?(path) do
      {:error, :no_such_bucket}
    else
      objects = list_objects_recursive(path, "")
      {:ok, objects}
    end
  end

  @doc """
  Stores an object.
  """
  def put_object(bucket, key, data) do
    bucket_dir = bucket_path(bucket)

    if not File.exists?(bucket_dir) do
      {:error, :no_such_bucket}
    else
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
  def get_object(bucket, key) do
    path = object_path(bucket, key)

    if File.exists?(path) do
      File.read(path)
    else
      {:error, :no_such_key}
    end
  end

  @doc """
  Deletes an object.
  """
  def delete_object(bucket, key) do
    path = object_path(bucket, key)

    if File.exists?(path) do
      File.rm(path)
    else
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
        Enum.flat_map(files, fn file ->
          full_path = Path.join(dir, file)
          relative_key = if prefix == "", do: file, else: Path.join(prefix, file)

          if File.dir?(full_path) do
            list_objects_recursive(full_path, relative_key)
          else
            stat = File.stat!(full_path)

            [
              %{
                key: relative_key,
                size: stat.size,
                last_modified: stat.mtime
              }
            ]
          end
        end)

      {:error, _} ->
        []
    end
  end
end
