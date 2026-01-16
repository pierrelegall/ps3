defmodule PS3.Application do
  @moduledoc """
  Application module that initializes the PS3 storage backend.

  PS3 provides an S3-compatible API via a Plug router (`PS3.Router`).
  It does not manage its own HTTP server. Mount `PS3.Router` in your
  web server (Phoenix, Bandit, or Cowboy).

  ## Configuration

  Configure the storage backend in your `config/dev.exs`:

      config :ps3,
        storage_backend: PS3.Storage.Filesystem, # default
        storage_root: "./s3" # default

  And in your `config/test.exs`:

      config :ps3,
        storage_backend: PS3.Storage.Memory

  ## Mounting PS3.Router

  ### With Phoenix

      # In your router.ex
      forward "/s3", PS3.Router

  ### With Bandit

      children = [
        {Bandit, plug: PS3.Router, scheme: :http, port: 9000}
      ]

  ### With Cowboy

      children = [
        {Plug.Cowboy, scheme: :http, plug: PS3.Router, port: 9000}
      ]

  """
  use Application

  @impl true
  def start(_type, _args) do
    # Create ownership registry table for sandbox mode
    # This table tracks which processes own which sandbox tables
    :ets.new(:ps3_sandbox_ownership, [:set, :public, :named_table])

    PS3.Storage.init()

    children = []

    opts = [strategy: :one_for_one, name: PS3.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
