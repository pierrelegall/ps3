defmodule PS3.SandboxReqPlugin do
  @moduledoc """
  Req request step that injects the `x-ps3-sandbox-owner` header when the
  memory sandbox is enabled.

  Register it in `test/test_helper.exs` via:

      Application.put_env(:ps3, :client,
        Keyword.put(
          Application.get_env(:ps3, :client, []),
          :req_steps,
          [sandbox_header: &PS3.SandboxReqPlugin.attach_header/1]
        )
      )
  """

  alias PS3.Storage.Memory.Sandbox

  @header "x-ps3-sandbox-owner"

  @doc "Req request step — injects sandbox owner header if sandbox is active."
  def attach_header(%Req.Request{} = req) do
    case sandbox_header() do
      {_k, _v} = header -> Req.Request.put_header(req, @header, elem(header, 1))
      nil -> req
    end
  end

  defp sandbox_header do
    if Sandbox.enabled?() do
      case find_sandbox_owner() do
        {:ok, owner} -> {@header, Sandbox.encode_metadata(owner)}
        :not_found -> nil
      end
    end
  end

  defp find_sandbox_owner do
    callers = [self() | Process.get(:"$callers", [])]

    result =
      Enum.reduce_while(callers, :not_found, fn pid, :not_found ->
        case Sandbox.lookup_owner(pid) do
          {:ok, owner} -> {:halt, {:ok, owner}}
          :not_found -> {:cont, :not_found}
        end
      end)

    case result do
      {:ok, _} = found -> found
      :not_found -> auto_checkout()
    end
  end

  defp auto_checkout do
    case Sandbox.checkout() do
      :ok -> {:ok, self()}
      {:already, :owner} -> {:ok, self()}
      {:already, :allowed} -> Sandbox.lookup_owner(self())
    end
  end
end
