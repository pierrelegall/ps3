defmodule PS3 do
  @moduledoc """
  PS3 - S3-compatible server for dev & test environments.

  Provides a minimal S3 API implementation via a Plug router (`PS3.Router`)
  that mounts in any Plug-compatible web server (Phoenix, Bandit, Cowboy).

  ## Features

  - Bucket operations: create, delete, list
  - Object operations: put, get, delete, list
  - S3-compatible XML responses
  - Two storage backends: Filesystem (dev) and Memory (test)

  ## Configuration

  Configure per environment in `config/dev.exs` and `config/test.exs`:

      # config/dev.exs
      config :ps3,
        storage_backend: PS3.Storage.Filesystem, # default
        storage_root: "./s3"                     # default

      # config/test.exs
      config :ps3,
        storage_backend: PS3.Storage.Memory

  ## Mounting

  See `PS3.Application` for mounting examples.
  """
end
