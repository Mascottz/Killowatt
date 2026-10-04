defmodule Killowatt.AccountWatcher do
  @moduledoc """
  one process, one account. it holds the rolling ledger, evaluates the policy,
  and raises an alert the moment a window blows its limit. it never calls a
  cloud api itself; it decides, and the platform acts.

  in watch mode (action alert_only) it does the seeing without the stopping;
  the account keeps spending and the watcher counts what would have been saved.
  """
  use GenServer

  @hour_ms 3_600_000

  def start_link({account, policy, opts}) do
    GenServer.start_link(__MODULE__, {account, policy, opts}, name: via(account))
  end

  defp via(account), do: {:via, Registry, {Killowatt.Registry, account}}

  def record(account, event), do: GenServer.cast(via(account), {:record, event})

  def state(account), do: GenServer.call(via(account), :state)

  @impl true
  def init({account, policy, opts}) do
    {:ok,
     %{
       account: account,
       policy: policy,
       enforce: Keyword.get(opts, :enforce, :dry_run),
       ledger: [],
       tripped: false,
       warned: false,
       watching: false,
       prevented_cents: 0,
       would_have_saved_cents: 0
     }}
  end

  @impl true
  def handle_cast({:record, event}, s) do
    cond do
      s.tripped ->
        {:noreply, %{s | prevented_cents: blocked_cents(s, event)}}

      exempt?(s.policy, event.service) ->
        {:noreply, %{s | ledger: prune([event | s.ledger], event.at_ms)}}

      true ->
        ledger = prune([event | s.ledger], event.at_ms)
        s = %{s | ledger: ledger}
        burst = spent(ledger, event.at_ms, s.policy.burst_window_ms, s.policy)
        hour = spent(ledger, event.at_ms, @hour_ms, s.policy)

        breach =
          cond do
            burst > s.policy.burst_limit ->
              {burst, s.policy.burst_limit, "burst window"}

            hour > s.policy.hourly_limit ->
              {hour, s.policy.hourly_limit, "hourly limit"}

            true ->
              nil
          end

        case breach do
          nil ->
            {:noreply, maybe_warn(s, event, burst)}

          {spend, limit, window_name} when s.policy.action == "alert_only" ->
            watch(s, event, spend, limit, window_name)

          {spend, limit, window_name} ->
            trip(s, event, spend, limit, window_name)
        end
    end
  end

  @impl true
  def handle_call(:state, _from, s) do
    {:reply, s, s}
  end

  # after a trip, exempt services keep running; only the rest counts
  # as prevented spend.
  defp blocked_cents(s, event) do
    if event.service in s.policy.exempt,
      do: s.prevented_cents,
      else: s.prevented_cents + event.cents
  end

  defp maybe_warn(s, event, burst) do
    if not s.warned and burst >= trunc(s.policy.burst_limit * 0.8) do
      Killowatt.Alerts.notice(%{
        account: s.account,
        kind: "approaching",
        message:
          "burst window at #{pct(burst, s.policy.burst_limit)}; #{event.service} is the loud one"
      })

      %{s | warned: true}
    else
      s
    end
  end

  # watch mode; the limit broke, nothing gets touched, and from the first
  # breach onward every charge is counted as would-have-saved.
  defp watch(s, event, spend, limit, window_name) do
    if not s.watching do
      Killowatt.Alerts.notice(%{
        account: s.account,
        kind: "watching",
        message:
          "#{event.service} blew the #{window_name}; #{money(spend)} of #{money(limit)} allowed, nothing touched"
      })
    end

    {:noreply,
     %{
       s
       | watching: true,
         would_have_saved_cents: s.would_have_saved_cents + event.cents
     }}
  end

  defp trip(s, event, spend, limit, window_name) do
    {:noreply, do_trip(s, event, spend, limit, window_name)}
  end

  defp do_trip(s, event, spend, limit, window_name) do
    Killowatt.Alerts.notice(%{
      account: s.account,
      kind: "hard stop",
      message:
        "#{event.service} blew the #{window_name}; #{money(spend)} of #{money(limit)} allowed"
    })

    Killowatt.Enforcement.dispatch(s.account, event.service, s.policy.action, s.enforce)

    %{s | tripped: true}
  end

  defp prune(ledger, now_ms) do
    horizon = now_ms - @hour_ms
    Enum.filter(ledger, fn e -> e.at_ms >= horizon end)
  end

  defp exempt?(policy, service), do: service in policy.exempt

  defp spent(ledger, now_ms, window_ms, policy) do
    horizon = now_ms - window_ms

    ledger
    |> Enum.filter(fn e -> e.at_ms >= horizon and not exempt?(policy, e.service) end)
    |> Enum.reduce(0, fn e, acc -> acc + e.cents end)
  end

  defp pct(spend, limit), do: "#{Float.round(spend / limit * 100, 0)}%"

  defp money(cents) do
    "$#{div(cents, 100)}.#{String.pad_leading(Integer.to_string(rem(cents, 100)), 2, "0")}"
  end
end
