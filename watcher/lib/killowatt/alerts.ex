defmodule Killowatt.Alerts do
  @moduledoc """
  collects notices from the watchers and says them out loud. later this
  becomes webhooks, slack, and whatever else the humans are using.
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

  @impl true
  def handle_cast({:notice, m}, acc) do
    Logger.warning("[killowatt] #{m.account} → #{m.kind}; #{m.message}")
    {:noreply, [m | acc]}
  end

  @impl true
  def handle_call(:history, _from, acc) do
    {:reply, Enum.reverse(acc), acc}
  end
end
