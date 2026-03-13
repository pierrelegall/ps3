# Start a test HTTP server with Bandit for integration tests
{:ok, _} = Bandit.start_link(plug: PS3.Router, scheme: :http, port: 9000)

# Configure PS3.Client for integration tests, injecting sandbox headers via Req step
Application.put_env(:ps3, :client,
  Keyword.put(
    Application.get_env(:ps3, :client, []),
    :req_steps,
    [sandbox_header: &PS3.SandboxReqPlugin.attach_header/1]
  )
)

# Start tests!
ExUnit.start()
