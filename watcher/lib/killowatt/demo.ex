defmodule Killowatt.Demo do
  @moduledoc """
  one incident, two watchers. the armed one stops the loop; the one in
  watch mode sees everything and touches nothing. run it with;

      mix run -e "Killowatt.Demo.run()"
  """

  @tick_ms 2_000
  @runaway_at_tick 180
  @end_tick 600

  def run do
    base = %{
      daily_limit: 250_00,
      hourly_limit: 60_00,
      burst_window_ms: 600_000,
      burst_limit: 40_00,
      exempt: ["rds-prod-backups"],
      action: "hard_stop"
    }

    {:ok, _} = Killowatt.Accounts.start_account("acme-armed", base)
    {:ok, _} = Killowatt.Accounts.start_account("acme-watch", Map.put(base, :action, "alert_only"))

    IO.puts("killowatt watcher; one incident, two accounts, two postures")
    IO.puts("acme-armed → hard_stop, acme-watch → alert_only; same limits, same loop")
    IO.puts("")

    for t <- 0..@end_tick do
      at = t * @tick_ms

      for account <- ["acme-armed", "acme-watch"] do
        record(account, at, "api-gateway", 2)
        record(account, at, "rds-prod-backups", 14)
        durable = if t >= @runaway_at_tick, do: 1 + 55, else: 1
        record(account, at, "durable-objects", durable)
      end

      if rem(t, 120) == 0 do
        armed = Killowatt.AccountWatcher.state("acme-armed")
        watch = Killowatt.AccountWatcher.state("acme-watch")

        IO.puts(
          "t+#{fmt(at)}  armed tripped=#{armed.tripped} prevented=#{money(armed.prevented_cents)}  |  watch seeing=#{watch.watching} saved=#{money(watch.would_have_saved_cents)}"
        )
      end
    end

    # let the last casts land before we read the final state
    Process.sleep(100)
    armed = Killowatt.AccountWatcher.state("acme-armed")
    watch = Killowatt.AccountWatcher.state("acme-watch")

    IO.puts("")
    IO.puts("the pitch, side by side")
    IO.puts("  armed   tripped=#{armed.tripped}; prevented #{money(armed.prevented_cents)}")
    IO.puts("  watch   touched nothing; would have saved #{money(watch.would_have_saved_cents)}")
    IO.puts("  watch mode is how you earn the right to arm the breaker")
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
