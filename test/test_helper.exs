# Start a test HTTP server with Bandit for integration tests
{:ok, _} = Bandit.start_link(plug: PS3.Router, scheme: :http, port: 9000)

# Configure ExAws for integration tests
Application.put_env(:ex_aws, :access_key_id, "test")
Application.put_env(:ex_aws, :secret_access_key, "test")
Application.put_env(:ex_aws, :http_client, PS3.ExAwsHttpClient)

Application.put_env(:ex_aws, :s3,
  scheme: "http://",
  host: "localhost",
  port: 9000,
  region: "local"
)

# Start tests!
ExUnit.start()
