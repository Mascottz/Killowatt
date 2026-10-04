defmodule Killowatt.Metering.Poller do
  @moduledoc """
  pulls usage events from a metering client on an interval and records them
  on the account's watcher. timestamps advance by a fixed step, so a demo can
  compress an hour into a second; in production set clock_step_ms to the poll
  interval and time is real again.
  """
  use GenServer
  require Logger

  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def report(server \\ __MODULE__), do: GenServer.call(server, :report)

  @impl true
  def init(opts) do
    interval = Keyword.get(opts, :interval_ms, 60_000)

    state = %{
      account: Keyword.fetch!(opts, :account),
      client: Keyword.get(opts, :client, Killowatt.Metering.CloudflareClient),
      interval_ms: interval,
      clock_step_ms: Keyword.get(opts, :clock_step_ms, interval),
      sim_ms: System.system_time(:millisecond),
      cursor: Keyword.get(opts, :cursor, 0),
      polls: 0,
      events: 0
    }

    schedule(interval)
    {:ok, state}
  end

  @impl true
  def handle_info(:poll, s) do
    s = %{s | polls: s.polls + 1, sim_ms: s.sim_ms + s.clock_step_ms}

    case s.client.fetch_events(s.cursor) do
      {:ok, fetched, cursor} ->
        Enum.each(fetched, fn e ->
          Killowatt.AccountWatcher.record(s.account, %{
            at_ms: s.sim_ms,
            service: e.service,
            cents: e.cents
          })
        end)

        schedule(s.interval_ms)
        {:noreply, %{s | cursor: cursor, events: s.events + length(fetched)}}

      {:error, reason} ->
        Logger.warning("[killowatt] metering poll failed; #{inspect(reason)}")
        schedule(s.interval_ms)
        {:noreply, s}
    end
  end

  @impl true
  def handle_call(:report, _from, s) do
    {:reply, %{polls: s.polls, events: s.events, sim_ms: s.sim_ms}, s}
  end

  defp schedule(ms), do: Process.send_after(self(), :poll, ms)
end
