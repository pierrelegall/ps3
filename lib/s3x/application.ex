defmodule S3x.Application do
  @moduledoc """
  Application module that initializes the S3x storage backend.

  S3x provides an S3-compatible API via a Plug router (`S3x.Router`).
  It does not manage its own HTTP server. Mount `S3x.Router` in your
  web server (Phoenix, Bandit, or Cowboy).

  ## Configuration

  Configure the storage backend in your `config/dev.exs`:

      config :s3x,
        storage_backend: S3x.Storage.Filesystem, # default
        storage_root: "./s3" # default

  And in your `config/test.exs`:

      config :s3x,
        storage_backend: S3x.Storage.Memory

  ## Mounting S3x.Router

  ### With Phoenix

      # In your router.ex
      forward "/s3", S3x.Router

  ### With Bandit

      children = [
        {Bandit, plug: S3x.Router, scheme: :http, port: 9000}
      ]

  ### With Cowboy

      children = [
        {Plug.Cowboy, scheme: :http, plug: S3x.Router, port: 9000}
      ]

  """
  use Application

  @impl true
  def start(_type, _args) do
    S3x.Storage.init()

    children = []

    opts = [strategy: :one_for_one, name: S3x.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
