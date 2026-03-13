<h3 align="center">
  PS3
</h3>

<div align="center">
  <a href="https://github.com/pierrelegall/ps3/stargazers">
    <img src="https://img.shields.io/github/stars/pierrelegall/ps3?colorA=363a4f&colorB=b7bdf8&style=for-the-badge">
  </a>
  <a href="https://github.com/pierrelegall/ps3/issues">
    <img src="https://img.shields.io/github/issues/pierrelegall/ps3?colorA=363a4f&colorB=f5a97f&style=for-the-badge">
  </a>
  <a href="https://github.com/pierrelegall/ps3/contributors">
    <img src="https://img.shields.io/github/contributors/pierrelegall/ps3?colorA=363a4f&colorB=a6da95&style=for-the-badge">
  </a>
</div>

# About

Pluggable S3 server for Elixir/Phoenix applications storing data in memory or on the filesystem.

Benefits with the `Memory` back-end (designed for **test** env):
- Still no need of an external service (like [Minio](https://www.min.io/))
- Very fast, no SSD wear, and no temporary directories management
- Concurrent tests work with `async: true` thanks to sandboxing

Benefits with the `Filesystem` back-end (designed for **dev** env):
- No need of an external service (like [Minio](https://www.min.io/))
- Simple disk storage (by default in your project `s3` directory)

## Installation

Add `ps3` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    # [...]
    {:ps3, "~> 0.1.0", only: [:dev, :test]},
    # [...]
  ]
end
```

## Configuration

> **Warning**: Configure PS3 server-side features in environment-specific config files (`config/dev.exs`, `config/test.exs`), **NOT** in `config/config.exs`. PS3 is not designed for production environments.

> **Note**: PS3 works with any Plug-compatible web server (Bandit, Cowboy, etc.)

Configure the storage backend per environment:

```elixir
# config/dev.exs
config :ps3,
  storage_backend: PS3.Storage.Filesystem, # default
  storage_root: "./s3" # default

# config/test.exs
config :ps3,
  storage_backend: PS3.Storage.Memory
```

And enable the sandbox in `test/test_helper.exs`:

```elixir
# test/test_helper.exs
PS3.Storage.Memory.Sandbox.mode(:auto)
```

Then, mount PS3 at a specific path in your Phoenix application:

```elixir
# lib/your_app_web/router.ex
defmodule AppWeb.Router do
  use AppWeb, :router

  scope "/" do
    forward "/s3", PS3.Router
  end
end
```

Finally, you can access PS3 at `http://localhost:4000/s3` (or your Phoenix app's URL). You need to use a S3 client which injects sandbox header when sandboxing enabled. To do so, we recommend to use the PS3 built-in S3 client: `PS3.Client`. It needs to be configured as below:

```elixir
# config/dev.exs
config :ps3, :client,
  endpoint: "http://localhost:4000/s3"

# config/test.exs (note the port is different)
config :ps3, :client,
  endpoint: "http://localhost:4002/s3"

# config/prod.exs
config :ps3, :client,
  endpoint: "https://your.s3.service.net",
  access_key_id: System.fetch_env!("S3_ACCESS_KEY_ID"),
  secret_access_key: System.fetch_env!("S3_SECRET_ACCESS_KEY"),
  region: System.fetch_env!("S3_REGION")
```

## Client usage

The `PS3.Client` is a very simple S3 client, i.e.:

```elixir
# Put an object
PS3.Client.put_object("my-bucket", "file.txt", "Hello, World!")

# Get an object
PS3.Client.get_object("my-bucket", "file.txt")

# List objects
PS3.Client.list_objects("my-bucket")
```

## Questions

### Does `PS3` work only with the built-in `PS3.Client`?

`PS3`'s `Memory` back-end (used in tests) isolates data per-test-process using an ETS-based sandbox system (PS3.Storage.Memory.Sandbox). For this to work across process boundaries (test process → HTTP handler process), PS3 needs to know which test owns the request. It does this via a custom `x-ps3-sandbox-owner` header containing the test's Erlang PID/
If `PS3.Client` is the recommended client to use with `PS3` for now, clients like `ExAws` can inject header like done by `PS3.Client`. So `PS3.Client` is not the only compatible client.

### `mix ecto.setup` fail because S3 endpoint is not yet up, how can I do?

`PS3` is mounted as a `Plug` route inside the Phoenix endpoint (via forward "/s3", PS3.Router in the router). This means PS3's HTTP server is only available when the Phoenix endpoint is actually listening for HTTP connections. No HTTP server means the `ExAws.S3` client can't reach `localhost:4000/s3/…`, so any seed or task that stores files through PS3 via ExAws will fail.

The workaround is to start the server before seeding data. To do so, add this line at the top of your `./priv/repo/seed.exs`:

```elixir
# In ./priv/repo/seed.exs

# Ensure the Phoenix endpoint is serving HTTP so the local S3 routes
# (PS3) are reachable for image uploads during seeding.
[ip: ip, port: port] = Web7.Endpoint.config(:http)

case :gen_tcp.connect(ip, port, [], 500) do
  {:ok, socket} ->
    :noop

  {:error, _} ->
    {:ok, _} = Bandit.start_link(plug: Web7.Endpoint, port: port, ip: ip)
end
 ```

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

<p align="center">
  Copyright &copy; 2025-2026 <a href="https://github.com/pierrelegall" target="_blank">Pierre Le Gall</a>
</p>

<p align="center">
  <a href="https://github.com/pierrelegall/ps3/blob/main/LICENSE.md"><img src="https://img.shields.io/static/v1.svg?style=for-the-badge&label=License&message=GPL%20v3&logoColor=d9e0ee&colorA=363a4f&colorB=b7bdf8"/></a>
</p>
