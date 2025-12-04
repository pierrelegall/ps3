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
- **Supports concurrent test execution** with `S3x.Storage.Memory.Sandbox`

## Testing with Sandbox (Concurrent Tests)

S3x provides `S3x.Storage.Memory.Sandbox` inspired by `Ecto.Adapters.SQL.Sandbox` to enable concurrent test execution with the Memory backend.

### Setup

In your `config/test.exs`:

```elixir
config :s3x,
  storage_backend: S3x.Storage.Memory,
  sandbox_mode: true
```

In your test files:

```elixir
defmodule MyApp.S3Test do
  use ExUnit.Case, async: true  # Enable concurrent tests!

  setup do
    :ok = S3x.Storage.Memory.Sandbox.checkout()
  end

  test "creates bucket" do
    {:ok, "test-bucket"} = S3x.Storage.create_bucket("test-bucket")
    # Each test has isolated storage - no interference from other tests
  end
end
```

### How It Works

- **Isolated mode**: Each test must explicitly checkout storage via `S3x.Storage.Memory.Sandbox.checkout()`
- **Per-process ETS tables**: Each test process gets its own unnamed ETS tables
- **Automatic cleanup**: Tables are automatically deleted when the test process exits
- **Concurrent execution**: Tests can run in parallel with `async: true` without interference

Unlike `Ecto.Adapters.SQL.Sandbox` which uses database transactions, `S3x.Storage.Memory.Sandbox` creates per-process ETS tables owned by each test process for simpler implementation.

See `S3x.Storage.Memory.Sandbox` documentation for more details.
