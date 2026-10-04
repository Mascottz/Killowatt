defmodule Killowatt.AccountWatcherTest do
  use ExUnit.Case

  # the semantics, pinned down on the beam too; one process per account,
  # windows roll, exempt never counts, watch mode never touches anything.

  defp policy(action \\ "hard_stop") do
    %{
      daily_limit: 250_00,
      hourly_limit: 60_00,
      burst_window_ms: 600_000,
      burst_limit: 40_00,
      exempt: ["backups"],
      action: action
    }
  end

  defp start(action \\ "hard_stop") do
    account = "acct-#{System.unique_integer([:positive])}"
    {:ok, _} = Killowatt.Accounts.start_account(account, policy(action))
    account
  end

  defp record(account, at_s, service, cents) do
    Killowatt.AccountWatcher.record(account, %{
      at_ms: at_s * 1000,
      service: service,
      cents: cents
    })
  end

  defp state(account) do
    # the call lines up behind every cast in the mailbox, so the read
    # always sees the whole stream
    Killowatt.AccountWatcher.state(account)
  end

  test "calm traffic never trips" do
    account = start()
    Enum.each(0..59, fn m -> record(account, m * 60, "api", 30) end)
    s = state(account)
    refute s.tripped
    refute s.watching
  end

  test "the burst window trips the breaker" do
    account = start()
    # 100 cents every 10s; the 41st event pushes the window past $40.00
    Enum.each(0..49, fn i -> record(account, i * 10, "api", 100) end)
    s = state(account)
    assert s.tripped
  end

  test "after a trip, non-exempt spend is prevented and exempt is not" do
    account = start()
    Enum.each(0..40, fn i -> record(account, i * 10, "api", 100) end)
    assert state(account).tripped

    record(account, 500, "api", 250)
    record(account, 510, "backups", 999)
    s = state(account)
    assert s.prevented_cents == 250
  end

  test "watch mode sees the breach without tripping" do
    account = start("alert_only")
    Enum.each(0..49, fn i -> record(account, i * 10, "api", 100) end)
    s = state(account)
    refute s.tripped
    assert s.watching
    # every non-exempt charge from the first breach onward is counted
    assert s.would_have_saved_cents == 100 * 10
  end

  test "exempt services cannot trip the breaker" do
    account = start()
    Enum.each(0..99, fn i -> record(account, i * 10, "backups", 500) end)
    s = state(account)
    refute s.tripped
    refute s.watching
  end

  test "the approaching notice fires before the trip" do
    account = start()
    Enum.each(0..40, fn i -> record(account, i * 10, "api", 100) end)
    _ = state(account)

    assert Enum.any?(Killowatt.Alerts.history(), fn n ->
             n.account == account and n.kind == "approaching"
           end)

    assert Enum.any?(Killowatt.Alerts.history(), fn n ->
             n.account == account and n.kind == "hard stop"
           end)
  end

  test "the daily limit trips the slow burn the small windows miss" do
    account = start()
    # $9.00 every 30 minutes; never close to the burst or hourly caps, but
    # it passes the $250.00 daily cap just past hour twelve
    Enum.each(0..27, fn i -> record(account, i * 1_800, "api", 900) end)
    s = state(account)
    assert s.tripped
  end
end
