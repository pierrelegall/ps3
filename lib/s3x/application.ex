defmodule S3x.Application do
  @moduledoc """
  Application module that starts the S3x HTTP server.

  Configuration priority (highest to lowest):
  1. CLI options passed via application start arguments
  2. Environment variables (PORT, S3X_STORAGE_ROOT)
  3. Application config (configured in parent project's config.exs)
  4. Defaults (port: 9000, storage_root: "./.s3")

  ## Configuration in parent project

  In your project's `config/config.exs`:

      config :s3x,
        port: 9000,
        storage_root: "./s3x_data"

  ## CLI options

  Start with custom options:

      Application.put_env(:s3x, :port, 8080)
      Application.ensure_all_started(:s3x)

  """
  use Application

  @impl true
  def start(_type, args) do
    port = get_config(:port, args, "PORT", 9000)
    _storage_root = get_config(:storage_root, args, "S3X_STORAGE_ROOT", "./.s3")

    # Initialize the configured storage backend
    S3x.Storage.init()

    children = [
      {Bandit, plug: S3x.Router, scheme: :http, port: port}
    ]

    opts = [strategy: :one_for_one, name: S3x.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Private helpers

  defp get_config(key, args, env_var, default) do
    # Priority: CLI args > Environment variable > Application config > Default
    cond do
      value = Keyword.get(args, key) ->
        normalize_value(value)

      value = System.get_env(env_var) ->
        normalize_value(value)

      value = Application.get_env(:s3x, key) ->
        normalize_value(value)

      true ->
        normalize_value(default)
    end
  end

  defp normalize_value(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> value
    end
  end

  defp normalize_value(value), do: value
end
