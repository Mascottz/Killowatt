defmodule Killowatt.AlertsDeliveryTest do
  use ExUnit.Case

  # notices go where the humans are; slack, discord, or the log, and a
  # dead webhook never takes the watcher down with it.

  test "the slack text is the same calm one-liner" do
    t =
      Killowatt.Alerts.Slack.text(%{
        account: "acme-prod",
        kind: "hard stop",
        message: "durable-objects blew the burst window; $40.20 of $40.00 allowed"
      })

    assert t =~ "acme-prod"
    assert t =~ "hard stop"
    assert t =~ "$40.20 of $40.00 allowed"
  end

  test "the discord content matches the slack one-liner" do
    notice = %{account: "a", kind: "watching", message: "m"}
    assert Killowatt.Alerts.Discord.content(notice) == Killowatt.Alerts.Slack.text(notice)
  end

  test "the log is the sink when no webhook is configured" do
    System.delete_env("KILOWATT_SLACK_WEBHOOK")
    System.delete_env("KILOWATT_DISCORD_WEBHOOK")
    Application.delete_env(:killowatt_watcher, :sink)
    assert Killowatt.Alerts.current_sink() == Killowatt.Alerts.Log
  end

  test "the slack sink is chosen when its webhook is set" do
    System.put_env("KILOWATT_SLACK_WEBHOOK", "https://hooks.example/x")
    Application.delete_env(:killowatt_watcher, :sink)
    assert Killowatt.Alerts.current_sink() == Killowatt.Alerts.Slack
    System.delete_env("KILOWATT_SLACK_WEBHOOK")
  end

  test "a configured sink receives every notice" do
    Application.put_env(:killowatt_watcher, :sink, {:test, self()})
    Killowatt.Alerts.notice(%{account: "a", kind: "hard stop", message: "m"})
    assert_receive {:alert_delivered, %{kind: "hard stop"}}, 1000
    Application.delete_env(:killowatt_watcher, :sink)
  end

  test "delivery errors do not crash the watcher" do
    # a webhook that resolves nowhere; deliver must answer {:error, _}, not raise
    System.put_env("KILOWATT_SLACK_WEBHOOK", "http://127.0.0.1:1/nope")
    result = Killowatt.Alerts.Slack.deliver(%{account: "a", kind: "k", message: "m"})
    assert match?({:error, _}, result)
    System.delete_env("KILOWATT_SLACK_WEBHOOK")
  end
end
