defmodule Killowatt.Metering.Demo do
  @moduledoc """
  the live metering pipeline without the cloud; a fake producer, a real
  watcher, real windows, a real trip. run it with;

      mix run -e "Killowatt.Metering.Demo.run()"
  """

  def run do
    policies = Killowatt.PolicyRegistry.load!()

    {:ok, _} = Killowatt.Accounts.start_account("acme-prod", policies["acme-prod"])

    {:ok, _} =
      Killowatt.Metering.Poller.start_link(
        name: :metering_demo,
        account: "acme-prod",
        client: Killowatt.Metering.FakeClient,
        interval_ms: 60,
        clock_step_ms: 60_000
      )

    IO.puts("killowatt metering; fake producer, real watcher")
    IO.puts("one simulated minute per poll; the loop starts at poll eight")
    IO.puts("")
    watch_until_trip(0)
  end

  defp watch_until_trip(n) when n >= 80 do
    IO.puts("no trip after 80 checks; something is off")
  end

  defp watch_until_trip(n) do
    Process.sleep(60)
    s = Killowatt.AccountWatcher.state("acme-prod")
    rep = Killowatt.Metering.Poller.report(:metering_demo)

    cond do
      s.tripped ->
        # let a few more polls land so the prevented number has a pulse
        Process.sleep(400)
        s = Killowatt.AccountWatcher.state("acme-prod")
        rep = Killowatt.Metering.Poller.report(:metering_demo)
        IO.puts("")
        IO.puts("tripped after #{rep.polls} polls and #{rep.events} metered events")
        IO.puts("prevented #{money(s.prevented_cents)} so far, and the loop keeps knocking")

      rem(n, 6) == 0 ->
        IO.puts("poll #{String.pad_leading(Integer.to_string(rep.polls), 2, "0")}; calm, #{rep.events} events metered")
        watch_until_trip(n + 1)

      true ->
        watch_until_trip(n + 1)
    end
  end

  defp money(cents) do
    "$#{div(cents, 100)}.#{String.pad_leading(Integer.to_string(rem(cents, 100)), 2, "0")}"
  end
end
