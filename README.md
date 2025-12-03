# S3x

Pluggable S3-compatible server. It is designed for dev & test environments. This should NOT be use for production.

## Features

- S3-compatible HTTP API
- Two storage backends: `Filesystem` (default, for dev) and `Memory` (for test)
- Compatible with any Plug-compatible web server (Phoenix, Bandit, Cowboy)

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

**Warning**: Configure S3x in environment-specific config files (`config/dev.exs`, `config/test.exs`), NOT in `config/config.exs`.

Configure the storage backend per environment:

```elixir
# config/dev.exs
config :s3x,
  storage_backend: S3x.Storage.Filesystem, # default
  storage_root: "./s3"                     # default

# config/test.exs
config :s3x,
  storage_backend: S3x.Storage.Memory
```

## Mounting

### On Phoenix

Mount S3x at a specific path in your Phoenix application:

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

### On Bandit

```elixir
# In your application.ex
children = [
  {Bandit, plug: S3x.Router, scheme: :http, port: 9000}
]
```

### On Cowboy

```elixir
# Add to mix.exs deps
{:plug_cowboy, "~> 2.0"}

# In your application.ex
children = [
  {Plug.Cowboy, scheme: :http, plug: S3x.Router, port: 9000}
]
```

### Storage backends

#### Filesystem (default)

- Stores data on disk using the local filesystem
- Best for: Development, production, persistent storage

```elixir
# config/dev.exs or config/prod.exs
config :s3x,
  storage_backend: S3x.Storage.Filesystem,
  storage_root: "./s3x_data"
```

#### Memory

- Stores data in memory using Erlang Term Storage (ETS)
- Best for: Fast tests, temporary storage, avoiding disk I/O
- Data is cleared when the application stops

```elixir
# config/test.exs
config :s3x,
  storage_backend: S3x.Storage.Memory
```

Benefits for testing:
- Much faster tests (no disk I/O)
- No SSD wear during test runs
- Automatic cleanup when tests complete
- No need to manage temporary directories
