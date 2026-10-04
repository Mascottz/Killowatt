defmodule Killowatt.Demo do
  @moduledoc """
  replays the same runaway durable objects loop the rust core uses, but through
  the supervised watcher. run it with;

      mix run -e "Killowatt.Demo.run()"
  """

  @tick_ms 2_000
  @runaway_at_tick 180
  @end_tick 600

  def run do
    policy = %{
      daily_limit: 250_00,
      hourly_limit: 60_00,
      burst_window_ms: 600_000,
      burst_limit: 40_00,
      exempt: ["rds-prod-backups"],
      action: "hard_stop"
    }

    {:ok, _} = Killowatt.Accounts.start_account("acme-prod", policy)

    IO.puts("killowatt watcher; replaying the runaway loop through one supervised process")
    IO.puts("watching acme-prod; burst $40.00 per 10m, hourly $60.00, action hard_stop")
    IO.puts("")

    for t <- 0..@end_tick do
      at = t * @tick_ms

      record("acme-prod", at, "api-gateway", 2)
      record("acme-prod", at, "rds-prod-backups", 14)

      durable = if t >= @runaway_at_tick, do: 1 + 55, else: 1
      record("acme-prod", at, "durable-objects", durable)

      if rem(t, 60) == 0 do
        s = Killowatt.AccountWatcher.state("acme-prod")
        IO.puts("t+#{fmt(at)}  tripped=#{s.tripped}  prevented=#{money(s.prevented_cents)}")
      end
    end

    # let the last casts land before we read the final state
    Process.sleep(100)
    s = Killowatt.AccountWatcher.state("acme-prod")

    IO.puts("")
    IO.puts("summary")
    IO.puts("  tripped             #{s.tripped}")
    IO.puts("  prevented after     #{money(s.prevented_cents)}")
  end

  defp record(account, at_ms, service, cents) do
    Killowatt.AccountWatcher.record(account, %{at_ms: at_ms, service: service, cents: cents})
  end

  defp fmt(ms) do
    secs = div(ms, 1000)

    "#{String.pad_leading(Integer.to_string(div(secs, 60)), 2, "0")}:#{
      String.pad_leading(Integer.to_string(rem(secs, 60)), 2, "0")
    }"
  end

  defp money(cents) do
    "$#{div(cents, 100)}.#{String.pad_leading(Integer.to_string(rem(cents, 100)), 2, "0")}"
  end
end
