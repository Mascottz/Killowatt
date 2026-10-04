defmodule Killowatt.Enforcement.Cloudflare do
  @moduledoc """
  suspends the worker behind the service that tripped, via the cloudflare api.

  needs; CLOUDFLARE_API_TOKEN and CLOUDFLARE_ACCOUNT_ID in the environment,
  and optionally KILOWATT_WORKER_MAP as service=worker pairs, comma separated.
  without the map the service name is used as the worker name.

  the call toggles the worker's workers.dev subdomain off, which takes it out
  of serving. reversible; enabling it again restores traffic, and that undo
  rides along with every order.
  """

  def suspend(service) do
    with {:ok, token} <- env("CLOUDFLARE_API_TOKEN"),
         {:ok, account_id} <- env("CLOUDFLARE_ACCOUNT_ID") do
      worker = worker_for(service)

      url =
        String.to_charlist(
          "https://api.cloudflare.com/client/v4/accounts/#{account_id}/workers/scripts/#{worker}/subdomain"
        )

      request =
        {url,
         [
           {~c"authorization", String.to_charlist("Bearer " <> token)},
           {~c"content-type", ~c"application/json"}
         ], ~c"application/json", :json.encode(%{"enabled" => false})}

      case :httpc.request(:post, request, [{:timeout, 15_000}], []) do
        {:ok, {{_, status, _}, _headers, _body}} when status in 200..299 ->
          :ok

        {:ok, {{_, status, _}, _headers, body}} ->
          {:error, {:http, status, IO.iodata_to_binary(body)}}

        {:error, reason} ->
          {:error, {:transport, reason}}
      end
    end
  end

  defp env(name) do
    case System.get_env(name) do
      nil -> {:error, {:missing_env, name}}
      "" -> {:error, {:missing_env, name}}
      value -> {:ok, value}
    end
  end

  # KILOWATT_WORKER_MAP="durable-objects=do-api,api=main-api"
  defp worker_for(service) do
    case System.get_env("KILOWATT_WORKER_MAP") do
      nil ->
        service

      "" ->
        service

      mapping ->
        mapping
        |> String.split(",", trim: true)
        |> Enum.map(fn pair ->
          case String.split(pair, "=", parts: 2) do
            [k, v] -> {String.trim(k), String.trim(v)}
            _ -> nil
          end
        end)
        |> Enum.reject(&is_nil/1)
        |> Map.new()
        |> Map.get(service, service)
    end
  end
end
