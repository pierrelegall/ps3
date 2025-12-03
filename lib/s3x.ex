defmodule S3x do
  @moduledoc """
  S3x - S3-compatible server for dev & test environments.

  Provides a minimal S3 API implementation via a Plug router (`S3x.Router`)
  that mounts in any Plug-compatible web server (Phoenix, Bandit, Cowboy).

  ## Features

  - Bucket operations: create, delete, list
  - Object operations: put, get, delete, list
  - S3-compatible XML responses
  - Two storage backends: Filesystem (dev) and Memory (test)

  ## Configuration

  Configure per environment in `config/dev.exs` and `config/test.exs`:

      # config/dev.exs
      config :s3x,
        storage_backend: S3x.Storage.Filesystem, # default
        storage_root: "./s3"                     # default

      # config/test.exs
      config :s3x,
        storage_backend: S3x.Storage.Memory

  ## Mounting

  See `S3x.Application` for mounting examples.
  """
end
