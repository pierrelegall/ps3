defmodule S3x do
  @moduledoc """
  S3x - A simple S3-compatible storage server in pure Elixir.

  S3x provides a minimal implementation of the S3 API for development environments.
  It supports basic bucket and object operations with a filesystem backend.

  ## Features

  - Bucket operations: create, delete, list
  - Object operations: put, get, delete, list
  - S3-compatible XML responses
  - Filesystem-based storage

  ## Configuration

  - `PORT`: HTTP server port (default: 9000)
  - `S3X_STORAGE_ROOT`: Storage directory (default: ./.s3)
  """
end
