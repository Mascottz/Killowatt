# one-shot live probe; meter the real account through the real pipeline.
# needs CLOUDFLARE_API_TOKEN and CLOUDFLARE_ACCOUNT_TAG in the environment.
{:ok, policies} = Killowatt.PolicyRegistry.load()
{:ok, _} = Killowatt.Accounts.start_account("acme-prod", policies["acme-prod"])

{:ok, _} =
  Killowatt.Metering.Poller.start_link(
    name: :live_probe,
    account: "acme-prod",
    client: Killowatt.Metering.CloudflareClient,
    interval_ms: 400,
    clock_step_ms: 3_600_000
  )

Process.sleep(5_000)
rep = Killowatt.Metering.Poller.report(:live_probe)
s = Killowatt.AccountWatcher.state("acme-prod")

IO.puts("")
IO.puts("report: #{inspect(rep)}")
IO.puts("watcher; tripped=#{s.tripped} watching=#{s.watching} ledger entries=#{length(s.ledger)}")
