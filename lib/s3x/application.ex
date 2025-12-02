defmodule S3x.Application do
  @moduledoc """
  Application module that starts the S3x HTTP server.
  """
  use Application

  @impl true
  def start(_type, _args) do
    port = System.get_env("PORT", "9000") |> String.to_integer()

    children = [
      {Bandit, plug: S3x.Router, scheme: :http, port: port}
    ]

    opts = [strategy: :one_for_one, name: S3x.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
