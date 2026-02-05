defmodule PS3.Storage do
  @moduledoc """
  Storage backend behavior for PS3.

  PS3 supports pluggable storage backends to allow different storage strategies:
  - `PS3.Storage.Filesystem` - Store data on disk (default, production use)
  - `PS3.Storage.Memory` - Store data in ETS tables (fast, for testing)

  ## Configuration

  Configure the storage backend in your project's config:

      config :ps3,
        storage_backend: PS3.Storage.Filesystem,  # default
        storage_root: "./s3"                      # used by Filesystem backend

      # In test.exs for faster tests:
      config :ps3,
        storage_backend: PS3.Storage.Memory

  """

  @default_backend PS3.Storage.Filesystem

  @doc """
  Returns the storage root directory (if applicable to the backend).
  """
  @callback storage_root() :: String.t() | nil

  @doc """
  Initializes the storage backend.
  """
  @callback init() :: :ok | {:error, term()}

  @doc """
  Clean the storage backend.
  """
  @callback clean_up() :: :ok | {:error, term()}

  @doc """
  Lists all buckets.
  """
  @callback list_buckets() :: {:ok, list(map())} | {:error, term()}

  @doc """
  Creates a bucket.
  """
  @callback create_bucket(bucket :: String.t()) :: {:ok, String.t()} | {:error, term()}

  @doc """
  Deletes a bucket.
  """
  @callback delete_bucket(bucket :: String.t()) :: :ok | {:error, term()}

  @doc """
  Lists objects in a bucket.
  """
  @callback list_objects(bucket :: String.t()) :: {:ok, list(map())} | {:error, term()}

  @doc """
  Stores an object.
  """
  @callback put_object(bucket :: String.t(), key :: String.t(), data :: binary()) ::
              {:ok, String.t()} | {:error, term()}

  @doc """
  Retrieves an object.
  """
  @callback get_object(bucket :: String.t(), key :: String.t()) ::
              {:ok, binary()} | {:error, term()}

  @doc """
  Deletes an object.
  """
  @callback delete_object(bucket :: String.t(), key :: String.t()) :: :ok | {:error, term()}

  # Delegating functions

  @doc """
  Returns the configured storage backend module.
  """
  def backend do
    Application.get_env(:ps3, :storage_backend, @default_backend)
  end

  @doc """
  Sets the storage backend module.

  Returns `:ok` if the module implements the `PS3.Storage` behaviour,
  or `{:error, :invalid_backend}` otherwise.
  """
  def backend(module) do
    case implements_storage?(module) do
      true ->
        Application.put_env(:ps3, :storage_backend, module)
        :ok

      false ->
        {:error, :invalid_backend}
    end
  end

  @doc """
  Resets the storage backend to the default (`#{inspect(@default_backend)}`).
  """
  def reset_backend do
    Application.delete_env(:ps3, :storage_backend)
  end

  @doc """
  Returns the storage root directory.
  """
  def storage_root, do: backend().storage_root()

  @doc """
  Initializes the storage backend.
  """
  def init, do: backend().init()

  @doc """
  Cleans the storage backend.
  """
  def clean_up, do: backend().clean_up()

  @doc """
  Lists all buckets.
  """
  def list_buckets, do: backend().list_buckets()

  @doc """
  Creates a bucket.
  """
  def create_bucket(bucket), do: backend().create_bucket(bucket)

  @doc """
  Deletes a bucket.
  """
  def delete_bucket(bucket), do: backend().delete_bucket(bucket)

  @doc """
  Lists objects in a bucket.
  """
  def list_objects(bucket), do: backend().list_objects(bucket)

  @doc """
  Stores an object.
  """
  def put_object(bucket, key, data), do: backend().put_object(bucket, key, data)

  @doc """
  Retrieves an object.
  """
  def get_object(bucket, key), do: backend().get_object(bucket, key)

  @doc """
  Deletes an object.
  """
  def delete_object(bucket, key), do: backend().delete_object(bucket, key)

  defp implements_storage?(module) when is_atom(module) do
    case Code.ensure_loaded?(module) do
      true ->
        module.module_info(:attributes)
        |> Keyword.get_values(:behaviour)
        |> List.flatten()
        |> Enum.member?(PS3.Storage)

      _ ->
        false
    end
  end
end
