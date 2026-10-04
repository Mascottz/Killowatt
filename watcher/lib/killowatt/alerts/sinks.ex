defmodule Killowatt.Alerts.Sink do
  @moduledoc """
  where notices go. a sink delivers one notice and answers :ok; delivery
  must never crash the watcher, so the caller wraps it.
  """

  @callback deliver(notice :: map()) :: :ok | {:error, term()}
end

defmodule Killowatt.Alerts.Log do
  @moduledoc "the default sink; the log line already happened, so there is nothing to do."
  @behaviour Killowatt.Alerts.Sink

  @impl true
  def deliver(_notice), do: :ok
end

defmodule Killowatt.Alerts.Slack do
  @moduledoc """
  posts notices to a slack incoming webhook; KILOWATT_SLACK_WEBHOOK in the
  environment. the text is the same one-liner the log shows, because calm
  does not stop at the edge of the system.
  """
  @behaviour Killowatt.Alerts.Sink

  def text(notice) do
    "[killowatt] #{notice.account} → #{notice.kind}; #{notice.message}"
  end

  @impl true
  def deliver(notice) do
    with {:ok, url} <- webhook("KILOWATT_SLACK_WEBHOOK") do
      Killowatt.Alerts.Webhook.post(url, %{"text" => text(notice)})
    end
  end

  defp webhook(var) do
    case System.get_env(var) do
      nil -> {:error, {:missing_env, var}}
      "" -> {:error, {:missing_env, var}}
      value -> {:ok, String.to_charlist(value)}
    end
  end
end

defmodule Killowatt.Alerts.Discord do
  @moduledoc """
  posts notices to a discord webhook; KILOWATT_DISCORD_WEBHOOK in the
  environment. same one-liner as slack and the log.
  """
  @behaviour Killowatt.Alerts.Sink

  def content(notice) do
    "[killowatt] #{notice.account} → #{notice.kind}; #{notice.message}"
  end

  @impl true
  def deliver(notice) do
    with {:ok, url} <- webhook("KILOWATT_DISCORD_WEBHOOK") do
      Killowatt.Alerts.Webhook.post(url, %{"content" => content(notice)})
    end
  end

  defp webhook(var) do
    case System.get_env(var) do
      nil -> {:error, {:missing_env, var}}
      "" -> {:error, {:missing_env, var}}
      value -> {:ok, String.to_charlist(value)}
    end
  end
end

defmodule Killowatt.Alerts.Webhook do
  @moduledoc false

  # one small json post; shared by slack and discord.
  def post(url, payload) do
    request =
      {url, [{~c"content-type", ~c"application/json"}], ~c"application/json",
       :json.encode(payload)}

    case :httpc.request(:post, request, [{:timeout, 10_000}], []) do
      {:ok, {{_, status, _}, _headers, _body}} when status in 200..299 ->
        :ok

      {:ok, {{_, status, _}, _headers, body}} ->
        {:error, {:http, status, IO.iodata_to_binary(body)}}

      {:error, reason} ->
        {:error, {:transport, reason}}
    end
  end
end
