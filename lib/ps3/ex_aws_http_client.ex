defmodule PS3.ExAwsHttpClient do
  @moduledoc """
  ExAws HTTP client that transparently injects sandbox headers in test.

  When the sandbox is enabled, this client:
  1. Walks `[self() | Process.get(:"$callers", [])]` to find an existing sandbox owner
  2. If none found, auto-checks out a sandbox for the current process
  3. Injects the `x-ps3-sandbox-owner` header
  4. Delegates to `ExAws.Request.Req` for the actual HTTP call

  When the sandbox is disabled, requests pass straight through to `ExAws.Request.Req`.
  """

  alias PS3.Storage.Memory.Sandbox

  def request(method, url, body \\ "", headers \\ [], http_opts \\ []) do
    headers = maybe_inject_sandbox_header(headers)
    apply(ExAws.Request.Req, :request, [method, url, body, headers, http_opts])
  end

  defp maybe_inject_sandbox_header(headers) do
    cond do
      Sandbox.enabled?() ->
        case find_sandbox_owner() do
          {:ok, owner} ->
            [{"x-ps3-sandbox-owner", Sandbox.encode_metadata(owner)} | headers]
          :not_found ->
            headers
        end

      true ->
        headers
    end
  end

  defp find_sandbox_owner do
    callers = [self() | Process.get(:"$callers", [])]

    Enum.reduce_while(callers, :not_found, fn pid, :not_found ->
      case Sandbox.lookup_owner(pid) do
        {:ok, owner} -> {:halt, {:ok, owner}}
        :not_found -> {:cont, :not_found}
      end
    end)
    |> case do
      {:ok, _owner} = found -> found
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
