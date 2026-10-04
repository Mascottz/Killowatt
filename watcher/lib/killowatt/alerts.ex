defmodule Killowatt.Alerts do
  @moduledoc """
  collects notices from the watchers, says them out loud, and hands them to
  the sink. the sink is picked once per notice; KILOWATT_SLACK_WEBHOOK or
  KILOWATT_DISCORD_WEBHOOK in the environment, the log otherwise. delivery
  is wrapped so a dead webhook can never take the watcher down with it.
  """
  use GenServer

  require Logger

  def start_link(_init) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_init), do: {:ok, []}

  def notice(map), do: GenServer.cast(__MODULE__, {:notice, map})

  def history, do: GenServer.call(__MODULE__, :history)

  # what would receive the next notice; exposed so tests can pin it.
  def current_sink do
    case Application.get_env(:killowatt_watcher, :sink) do
      nil -> from_env()
      sink -> sink
    end
  end

  @impl true
  def handle_cast({:notice, m}, acc) do
    Logger.warning("[killowatt] #{m.account} → #{m.kind}; #{m.message}")
    deliver(m)
    {:noreply, [m | acc]}
  end

  @impl true
  def handle_call(:history, _from, acc) do
    {:reply, Enum.reverse(acc), acc}
  end

  defp deliver(m) do
    case current_sink() do
      {:test, pid} when is_pid(pid) ->
        send(pid, {:alert_delivered, m})

      mod ->
        try do
          case mod.deliver(m) do
            :ok ->
              :ok

            {:error, reason} ->
              Logger.warning("[killowatt] alert delivery failed; #{inspect(reason)}")
          end
        rescue
          e ->
            Logger.warning("[killowatt] alert delivery crashed; #{Exception.message(e)}")
        end
    end
  end

  defp from_env do
    cond do
      present?("KILOWATT_SLACK_WEBHOOK") -> Killowatt.Alerts.Slack
      present?("KILOWATT_DISCORD_WEBHOOK") -> Killowatt.Alerts.Discord
      true -> Killowatt.Alerts.Log
    end
  end

  defp present?(var) do
    case System.get_env(var) do
      nil -> false
      "" -> false
      _ -> true
    end
  end
end
