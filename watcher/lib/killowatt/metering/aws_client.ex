defmodule Killowatt.Metering.AwsClient do
  @moduledoc """
  live metering from aws cost explorer; dollars in, cents out.

  needs AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY in the environment;
  AWS_REGION is used for signing only, because cost explorer is global,
  and defaults to us-east-1. the cursor is an hour index starting at
  midnight utc today, matching the cloudflare client, so each poll meters
  one closed hour. cost explorer needs the identity to have
  ce:GetCostAndUsage, and hourly granularity is only served for the last
  fourteen days; polls outside that window come back empty rather than
  erroring.
  """
  @behaviour Killowatt.Metering.Client

  alias Killowatt.Enforcement.Aws.Sigv4

  @region_default "us-east-1"
  @target "AWSInsightsIndexService.GetCostAndUsage"

  @impl true
  def fetch_events(cursor) do
    with {:ok, access_key} <- env("AWS_ACCESS_KEY_ID"),
         {:ok, secret} <- env("AWS_SECRET_ACCESS_KEY") do
      region = System.get_env("AWS_REGION") || @region_default
      host = "ce.#{region}.amazonaws.com"
      since = hour_iso(cursor)
      until = hour_iso(cursor + 1)

      body =
        :json.encode(%{
          "TimePeriod" => %{"Start" => day_of(since), "End" => day_after(since)},
          "Granularity" => "HOURLY",
          "Metrics" => ["UnblendedCost"],
          "GroupBy" => [%{"Type" => "DIMENSION", "Key" => "SERVICE"}]
        })
        |> IO.iodata_to_binary()

      amz_date = Sigv4.timestamp()

      {auth, payload, _} =
        Sigv4.authorization_json(host, body, @target, region, "ce", access_key, secret, amz_date)

      request =
        {String.to_charlist("https://#{host}/"),
         [
           {~c"authorization", String.to_charlist(auth)},
           {~c"x-amz-date", String.to_charlist(amz_date)},
           {~c"x-amz-target", String.to_charlist(@target)},
           {~c"content-type", ~c"application/x-amz-amz-json-1.1"}
         ], ~c"application/x-amz-amz-json-1.1", payload}

      case :httpc.request(:post, request, [{:timeout, 15_000}], []) do
        {:ok, {{_, 200, _}, _headers, resp}} ->
          {:ok, parse(IO.iodata_to_binary(resp), since, until), cursor + 1}

        {:ok, {{_, status, _}, _headers, resp}} ->
          {:error, {:http, status, IO.iodata_to_binary(resp)}}

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

  @doc "turn a GetCostAndUsage body into metered events; pure, and pinned by tests"
  def parse(body, since, until) when is_binary(body) do
    decoded = :json.decode(body)

    decoded
    |> get_in(["ResultsByTime"])
    |> List.wrap()
    |> Enum.filter(fn r -> hour_in_window?(r, since, until) end)
    |> Enum.flat_map(fn r -> r["Groups"] || [] end)
    |> Enum.map(fn g ->
      service = g |> get_in(["Keys"]) |> List.wrap() |> List.first() || "aws"
      amount = g |> get_in(["Metrics", "UnblendedCost", "Amount"]) || "0"
      {service, amount}
    end)
    |> Enum.map(fn {service, amount} ->
      %{service: String.downcase(service), cents: dollars_to_cents(amount)}
    end)
    |> Enum.reject(fn e -> e.cents == 0 end)
  rescue
    _ -> []
  end

  defp hour_in_window?(result, since, until) do
    case result["TimePeriod"] do
      %{"Start" => s, "End" => e} -> s >= since and e <= until
      _ -> true
    end
  end

  defp dollars_to_cents(amount) when is_binary(amount) do
    case Float.parse(amount) do
      {dollars, _} -> round(dollars * 100)
      :error -> 0
    end
  end

  defp dollars_to_cents(amount) when is_number(amount), do: round(amount * 100)

  defp hour_iso(hour_index) do
    now = DateTime.utc_now()
    base = %{now | hour: 0, minute: 0, second: 0, microsecond: {0, 0}}
    base |> DateTime.add(hour_index * 3600, :second) |> DateTime.to_iso8601()
  end

  # cost explorer day windows; start inclusive, end exclusive, dates only.
  defp day_of(iso), do: String.slice(iso, 0, 10)

  defp day_after(iso) do
    {:ok, dt, _} = DateTime.from_iso8601(iso)
    dt |> DateTime.add(86_400, :second) |> DateTime.to_iso8601() |> String.slice(0, 10)
  end
end
