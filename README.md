<h3 align="center">
  PS3
</h3>

<div align="center">
  <a href="https://github.com/pierrelegall/ps3/stargazers"><img src="https://img.shields.io/github/stars/pierrelegall/ps3?colorA=363a4f&colorB=b7bdf8&style=for-the-badge"></a>
  <a href="https://github.com/pierrelegall/ps3/issues"><img src="https://img.shields.io/github/issues/pierrelegall/ps3?colorA=363a4f&colorB=f5a97f&style=for-the-badge"></a>
  <a href="https://github.com/pierrelegall/ps3/contributors"><img src="https://img.shields.io/github/contributors/pierrelegall/ps3?colorA=363a4f&colorB=a6da95&style=for-the-badge"></a>
</div>

# About

Pluggable S3 srever for Elixir/Phoenix applications designed for **dev** & **test** environments.

Benefits in **dev**:
- No need of an external server/dependency
- On disk storage, in the project directory by default

Benefits in **test**:
- No need of an external server/dependency
- In memory storage (very fast, no SSD wear, and no temporary directories management)
- Concurrent tests work with `async: true` (with sandbox mode)

## Installation

Add `ps3` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ps3, "~> 0.1.0", only: [:dev, :test]},
    # [...]
  ]
end
```

## Configuration

**Warning**: Configure PS3 in environment-specific config files (`config/dev.exs`, `config/test.exs`), **NOT** in `config/config.exs`. PS3 is not designed for production environments.

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

And enable sandbox mode in `test/test_helper.exs`:

```elixir
# test/test_helper.exs
PS3.Storage.Memory.Sandbox.mode(:auto)
ExUnit.start()
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

Finally, access PS3 at `http://localhost:4000/s3/` (or your Phoenix app's URL).

> **Note**: PS3 works with any Plug-compatible web server (Bandit, Cowboy, etc.)

## Usage

Configure your S3 client to point to your local PS3 instance:

```elixir
# config/dev.exs or config/test.exs
config :ex_aws,
  access_key_id: "any",
  secret_access_key: "any"

config :ex_aws, :s3,
  scheme: "http://",
  host: "localhost",
  port: 4000,
  region: "local"
```

Then use `ExAws` as normal:

```elixir
# Put an object
ExAws.S3.put_object("my-bucket", "file.txt", "Hello, World!")
|> ExAws.request()

# Get an object
ExAws.S3.get_object("my-bucket", "file.txt")
|> ExAws.request()

# List objects
ExAws.S3.list_objects("my-bucket")
|> ExAws.request()
```

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

<p align="center">
  Copyright &copy; 2025 <a href="https://github.com/pierrelegall" target="_blank">Pierre Le Gall</a>
</p>

<p align="center">
  <a href="https://github.com/pierrelegall/ps3/blob/main/LICENSE.md"><img src="https://img.shields.io/static/v1.svg?style=for-the-badge&label=License&message=GPL%20v3&logoColor=d9e0ee&colorA=363a4f&colorB=b7bdf8"/></a>
</p>
