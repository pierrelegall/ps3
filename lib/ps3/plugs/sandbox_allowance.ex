defmodule PS3.Plugs.SandboxAllowance do
  @moduledoc """
  Plug that automatically allows HTTP handler processes to use a test's sandbox.

  When a request includes the `x-ps3-sandbox-owner` header, this plug decodes
  the owner PID and calls `PS3.Storage.Memory.Sandbox.allow/3` to grant the
  current connection process access to the owner's sandbox tables.

  ## Usage

  Add this plug to your router pipeline:

      plug PS3.Plugs.SandboxAllowance

  In tests, encode the owner PID and send it as a header:

      setup do
        pid = PS3.Storage.Memory.Sandbox.start_owner!()
        on_exit(fn -> PS3.Storage.Memory.Sandbox.stop_owner(pid) end)
        owner = PS3.Storage.Memory.Sandbox.encode_metadata(pid)
        {:ok, sandbox_owner: owner}
      end

      test "uses test sandbox", %{sandbox_owner: owner} do
        {:ok, _} =
          ExAws.S3.put_bucket("test", "local")
          |> ExAws.request(headers: [{"x-ps3-sandbox-owner", owner}])
      end

  This pattern matches `Phoenix.Ecto.SQL.Sandbox` plug behavior.
  """

  @behaviour Plug

  alias PS3.Storage.Memory.Sandbox

  @header_name "x-ps3-sandbox-owner"

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    case Plug.Conn.get_req_header(conn, @header_name) do
      [encoded | _] ->
        allow_from_header(conn, encoded)

      [] ->
        conn
    end
  end

  defp allow_from_header(conn, encoded) do
    owner = Sandbox.decode_metadata(encoded)

    case Sandbox.allow(owner, self()) do
      {:already, :allowed} ->
        # Handler may be reused across requests from different test processes.
        # If already allowed by a different owner, re-allow for the new one.
        case Sandbox.lookup_owner(self()) do
          {:ok, ^owner} -> :ok
          _ -> Sandbox.force_allow(owner, self())
        end

      _ ->
        :ok
    end

    conn
  rescue
    _ -> conn
  end
end
