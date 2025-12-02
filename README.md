# S3x

A simple S3-compatible storage server written in pure Elixir, designed for development environments to avoid complex configuration.

## Features

- S3-compatible HTTP API
- Bucket operations (create, delete, list)
- Object operations (get, put, delete, list)
- Filesystem-based or in memory-based storage backend
- Simple configuration with sensible defaults
- Flexible configuration (application config, environment variables, or runtime options)

## Getting Started

### Installation

Add `s3x` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:s3x, "~> 0.1.0"}
  ]
end
```

### Configuration

S3x can be configured in multiple ways with the following priority (highest to lowest):

1. CLI options (runtime configuration via `Application.put_env/3`)
2. Environment variables
3. Application config
4. Defaults

#### Application Configuration

In your project's `config/dev.exs`:

```elixir
config :s3x,
  port: 9000,                              # default
  storage_root: "./s3",                    # default
  storage_backend: S3x.Storage.Filesystem  # default
```

#### Storage Backends

S3x supports pluggable storage backends:

**Filesystem Backend (Default)**
- Stores data on disk using the local filesystem
- Best for: Development, production, persistent storage
- Configuration:

```elixir
# config/dev.exs or config/prod.exs
config :s3x,
  storage_backend: S3x.Storage.Filesystem,
  storage_root: "./s3x_data"
```

**Memory Backend (ETS)**
- Stores data in memory using Erlang Term Storage (ETS)
- Best for: Fast tests, temporary storage, avoiding disk I/O
- Data is cleared when the application stops
- Configuration:

```elixir
# config/test.exs
config :s3x,
  storage_backend: S3x.Storage.Memory
```

Benefits of the Memory backend for testing:
- Much faster tests (no disk I/O)
- No SSD wear during test runs
- Automatic cleanup when tests complete
- No need to manage temporary directories

#### Environment Variables

Override configuration with environment variables:

```sh
PORT=8000 mix run --no-halt
S3X_STORAGE_ROOT=/path/to/storage mix run --no-halt
```

#### Runtime Configuration

Set configuration at runtime:

```elixir
Application.put_env(:s3x, :port, 8080)
Application.put_env(:s3x, :storage_root, "/tmp/s3x_data")
Application.ensure_all_started(:s3x)
```

### Running the Server

For standalone usage, add S3x to your application's supervision tree or start it directly:

```sh
mix run --no-halt
```

The server will start on the configured port (default: 9000) and store data in the configured directory (default: `./.s3`).

### Usage Examples

Using the AWS CLI or any S3-compatible client:

```sh
# Configure endpoint
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
alias s3="aws s3 --endpoint-url http://localhost:9000"

# Create a bucket
s3 mb s3://my-bucket

# Upload a file
s3 cp myfile.txt s3://my-bucket/

# List objects
s3 ls s3://my-bucket/

# Download a file
s3 cp s3://my-bucket/myfile.txt downloaded.txt

# Delete an object
s3 rm s3://my-bucket/myfile.txt

# Delete a bucket
s3 rb s3://my-bucket
```

## Development

Run tests:

```sh
mix test
```

Run Credo for code quality:

```sh
mix credo
```

Format code:

```sh
mix format
```
