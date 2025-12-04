ExUnit.start()

# Configure Memory backend for tests
Application.put_env(:s3x, :storage_backend, S3x.Storage.Memory)

# Enable sandbox mode for concurrent test isolation
Application.put_env(:s3x, :sandbox_mode, true)

# Start a test HTTP server with Bandit for integration tests
{:ok, _} = Bandit.start_link(plug: S3x.Router, scheme: :http, port: 9000)
