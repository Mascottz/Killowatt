# the live watcher; run from the watcher directory with;
#
#   mix run ../scripts/watch-live.exs
#
# it starts one watcher per policy in the registry, then meters the account
# named by KILOWATT_METER_ACCOUNT (or the first policy account) through the
# live cloudflare poller. enforcement mode comes from KILOWATT_ENFORCE_MODE;
# dry_run (the default), cloudflare, or aws.
#
# needs CLOUDFLARE_API_TOKEN and CLOUDFLARE_ACCOUNT_TAG in the environment.
# dry run touches nothing; the other two act for real.

enforce_mode =
  case System.get_env("KILOWATT_ENFORCE_MODE", "dry_run") do
    "cloudflare" -> :cloudflare
    "aws" -> :aws
    _ -> :dry_run
  end

{:ok, policies} = Killowatt.PolicyRegistry.load()

accounts =
  Enum.map(policies, fn {account, policy} ->
    {:ok, _} = Killowatt.Accounts.start_account(account, policy, enforce: enforce_mode)
    account
  end)

meter_account =
  System.get_env("KILOWATT_METER_ACCOUNT") || List.first(Enum.sort(accounts))

case {System.get_env("CLOUDFLARE_API_TOKEN"), System.get_env("CLOUDFLARE_ACCOUNT_TAG")} do
  {nil, _} ->
    IO.puts("no CLOUDFLARE_API_TOKEN in the environment; nothing to meter yet")
    IO.puts("create the token per docs/METERING.md, then run scripts/check-cloudflare.sh")
    System.halt(1)

  {_, nil} ->
    IO.puts("no CLOUDFLARE_ACCOUNT_TAG in the environment; the poller needs it")
    IO.puts("scripts/check-cloudflare.sh detects the right value for your token")
    System.halt(1)

  _ ->
    :ok
end

unless meter_account in accounts do
  IO.puts("note; #{meter_account} has no policy, its events will still meter but never trip")
  {:ok, _} = Killowatt.Accounts.start_account(meter_account, %{
    daily_limit: 1_000_000_000,
    hourly_limit: 1_000_000_000,
    burst_window_ms: 600_000,
    burst_limit: 1_000_000_000,
    exempt: [],
    action: "alert_only"
  })
end

IO.puts("killowatt; watching #{Enum.join(accounts, ", ")}")
IO.puts("metering #{meter_account} through the live cloudflare poller")
IO.puts("enforcement mode; #{enforce_mode}")
IO.puts("")

case Killowatt.Metering.Poller.start_link(
       name: :live_metering,
       account: meter_account,
       client: Killowatt.Metering.CloudflareClient,
       interval_ms: 60_000,
       clock_step_ms: 3_600_000
     ) do
  {:ok, _} ->
    :ok

  {:error, reason} ->
    IO.puts("the poller did not start; #{inspect(reason)}")
    IO.puts("set CLOUDFLARE_API_TOKEN and CLOUDFLARE_ACCOUNT_TAG and try again")
    System.halt(1)
end

Stream.iterate(0, &(&1 + 1))
|> Enum.each(fn n ->
  Process.sleep(60_000)
  rep = Killowatt.Metering.Poller.report(:live_metering)

  states =
    Enum.map(accounts, fn account ->
      s = Killowatt.AccountWatcher.state(account)
      "#{account}=#{if s.tripped, do: "TRIPPED", else: "ok"}"
    end)

  IO.puts("t+#{n}m; polls=#{rep.polls} events=#{rep.events} #{Enum.join(states, " ")}")
end)
