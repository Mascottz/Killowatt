defmodule Killowatt.Metering.Client do
  @moduledoc """
  the metering contract; a producer of usage events. anything that can turn
  provider data into events with a service and integer cents can sit here.
  """

  @type event :: %{service: String.t(), cents: non_neg_integer()}

  @callback fetch_events(cursor :: term()) ::
              {:ok, [event()], new_cursor :: term()} | {:error, term()}
end

defmodule Killowatt.Metering.FakeClient do
  @moduledoc """
  a deterministic producer for offline runs; a quiet account that grows a
  durable objects retry loop after poll eight.
  """
  @behaviour Killowatt.Metering.Client

  @impl true
  def fetch_events(cursor) do
    runaway? = cursor >= 8

    events = [
      %{service: "api-gateway", cents: 30},
      %{service: "rds-prod-backups", cents: 110},
      %{service: "durable-objects", cents: if(runaway?, do: 470, else: 20)}
    ]

    {:ok, events, cursor + 1}
  end
end

defmodule Killowatt.Metering.CloudflareClient do
  @moduledoc """
  live metering from cloudflare graphql analytics; usage counts in, cents out.

  needs two environment variables; CLOUDFLARE_API_TOKEN and
  CLOUDFLARE_ACCOUNT_TAG. the cursor is an hour index starting at midnight
  utc today, so each poll meters one closed hour.

  the query targets the durable objects dataset; confirm the dataset and
  field names against your account's schema before you arm anything, because
  cloudflare ships new datasets regularly.
  """
  @behaviour Killowatt.Metering.Client

  @endpoint ~c"https://api.cloudflare.com/client/v4/graphql"

  # placeholder price in cents per million operations; replace with the
  # published pricing for your plan before you trust the dollars.
  @do_cents_per_million_ops 50

  @query """
  query ($accountTag: string!, $since: Time!, $until: Time!) {
    viewer {
      accounts(filter: { accountTag: $accountTag }) {
        durableObjectsPeriodGroups(
          limit: 1000
          filter: { datetime_geq: $since, datetime_lt: $until }
        ) {
          sum { requests }
        }
      }
    }
  }
  """

  @impl true
  def fetch_events(cursor) do
    with {:ok, token} <- env("CLOUDFLARE_API_TOKEN"),
         {:ok, account_tag} <- env("CLOUDFLARE_ACCOUNT_TAG"),
         {:ok, body} <- post(token, account_tag, cursor),
         {:ok, ops} <- extract_ops(body) do
      cents = div(ops * @do_cents_per_million_ops, 1_000_000)
      {:ok, [%{service: "durable-objects", cents: cents}], cursor + 1}
    end
  end

  defp env(name) do
    case System.get_env(name) do
      nil -> {:error, {:missing_env, name}}
      "" -> {:error, {:missing_env, name}}
      value -> {:ok, value}
    end
  end

  defp post(token, account_tag, cursor) do
    payload =
      :json.encode(%{
        "query" => @query,
        "variables" => %{
          "accountTag" => account_tag,
          "since" => hour_iso(cursor),
          "until" => hour_iso(cursor + 1)
        }
      })

    request =
      {@endpoint,
       [{~c"authorization", String.to_charlist("Bearer " <> token)}],
       ~c"application/json", payload}

    case :httpc.request(:post, request, [{:timeout, 15_000}], []) do
      {:ok, {{_, 200, _}, _headers, body}} -> {:ok, IO.iodata_to_binary(body)}
      {:ok, {{_, status, _}, _headers, body}} -> {:error, {:http, status, IO.iodata_to_binary(body)}}
      {:error, reason} -> {:error, {:transport, reason}}
    end
  end

  defp extract_ops(body) do
    decoded = :json.decode(body)

    groups =
      get_in(decoded, ["data", "viewer", "accounts"])
      |> List.wrap()
      |> List.first()
      |> case do
        nil -> []
        account -> account["durableObjectsPeriodGroups"] || []
      end

    ops =
      groups
      |> Enum.map(fn g -> get_in(g, ["sum", "requests"]) || 0 end)
      |> Enum.sum()

    {:ok, ops}
  rescue
    e -> {:error, {:parse, Exception.message(e)}}
  end

  defp hour_iso(hour_index) do
    now = DateTime.utc_now()
    base = %{now | hour: 0, minute: 0, second: 0, microsecond: {0, 0}}
    base |> DateTime.add(hour_index * 3600, :second) |> DateTime.to_iso8601()
  end
end
