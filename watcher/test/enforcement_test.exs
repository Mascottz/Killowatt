defmodule Killowatt.EnforcementTest do
  use ExUnit.Case

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

  defp start(opts \\ []) do
    account = "enf-#{System.unique_integer([:positive])}"
    {:ok, _} = Killowatt.Accounts.start_account(account, policy(), opts)
    account
  end

  test "dry run reports the order without touching anything" do
    assert {:ok, order} =
             Killowatt.Enforcement.dispatch("acct", "durable-objects", "hard_stop", :dry_run)

    assert order.action == "suspend"
    assert order.undo == "re-enable durable-objects"
  end

  test "watch mode never enforces, whatever mode is asked for" do
    assert {:ok, :watching} =
             Killowatt.Enforcement.dispatch("acct", "api", "alert_only", :cloudflare)
  end

  test "a tripped watcher dispatches through its configured mode" do
    account = start(enforce: {:test, self()})
    Enum.each(0..40, fn i ->
      Killowatt.AccountWatcher.record(account, %{at_ms: i * 10_000, service: "api", cents: 100})
    end)

    assert_receive {:enforcement_order, %{action: "suspend", service: "api"}}, 1000
  end

  test "a tripped watcher defaults to dry run" do
    account = start()
    Enum.each(0..40, fn i ->
      Killowatt.AccountWatcher.record(account, %{at_ms: i * 10_000, service: "api", cents: 100})
    end)

    _ = Killowatt.AccountWatcher.state(account)

    assert Enum.any?(Killowatt.Alerts.history(), fn n ->
             n.account == account and n.kind == "enforced" and
               String.contains?(n.message, "dry run")
           end)
  end
end
