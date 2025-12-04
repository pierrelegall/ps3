# S3x

Pluggable S3-compatible server. It is designed for **dev** & **test** environments, and it shouldn't be use in production.

## Installation

Add `s3x` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:s3x, "~> 0.1.0", only: [:dev, :test]},
    # [...]
  ]
end
```

## Configuration

**Warning**: Configure S3x in environment-specific config files (`config/dev.exs`, `config/test.exs`), **NOT** in `config/config.exs`.

Configure the storage backend per environment:

```elixir
# config/dev.exs
config :s3x,
  storage_backend: S3x.Storage.Filesystem, # default
  storage_root: "./s3" # default

# config/test.exs
config :s3x,
  storage_backend: S3x.Storage.Memory,
  sandbox_mode: true # Enable for concurrent tests (async: true)
```

Then Mount S3x at a specific path in your Phoenix application:

```elixir
# lib/your_app_web/router.ex
defmodule AppWeb.Router do
  use AppWeb, :router

  scope "/" do
    forward "/s3", S3x.Router
  end
end
```

Access S3x at `http://localhost:4000/s3/` (or your Phoenix app's URL).

> **Note**: S3x works with any Plug-compatible web server (Bandit, Cowboy, etc.)

## Storage backends

### Filesystem (default)

- Stores data on disk using the local filesystem
- Best for: Development, production, persistent storage

```elixir
# config/dev.exs or config/prod.exs
config :s3x,
  storage_backend: S3x.Storage.Filesystem,
  storage_root: "./s3x_data"
```

### Memory

- Stores data in memory using Erlang Term Storage (ETS)
- Best for: Fast tests, temporary storage, avoiding disk I/O
- Data is cleared when the application stops

Benefits for testing:
- Concurrent tests work with `async: true` (when `sandbox_mode: true`)
- Much faster than disk-based storage
- No SSD wear during test runs
- No need to manage temporary directories
