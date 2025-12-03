ExUnit.start()

# Start a test HTTP server with Bandit for integration tests
{:ok, _} = Bandit.start_link(plug: S3x.Router, scheme: :http, port: 9000)
