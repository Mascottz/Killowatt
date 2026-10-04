# killowatt

the hard stop for runaway cloud spend.

[![ci](https://github.com/Mascottz/Killowatt/actions/workflows/ci.yml/badge.svg)](https://github.com/Mascottz/Killowatt/actions/workflows/ci.yml)

a misconfigured loop once burned $34k in 8 days and nobody noticed until the invoice landed. alerts fire after the money is already gone. killowatt is the part that actually stops it; it watches usage in real time, checks your spend policies, and trips the breaker before the bill gets away.

not another dashboard. not another budget alert. a circuit breaker.

## enforcement

a trip becomes an order, and every order carries its own undo. dry-run is the default; it reports what would happen and touches nothing. `--audit` appends every order as one json line, the record you show when someone asks what the breaker did at three in the morning.

```bash
cargo run --release -- ingest ../metering/sample-bill.jsonl --audit /tmp/orders.jsonl
```

the first live adapter suspends the cloudflare worker behind the service that tripped, via the watcher, and enabling it again restores traffic. the second scales the aws auto scaling group behind it to zero, signed with a sigv4 implementation verified against the aws docs' own test vectors. reversible first, lethal later; kill is a policy word that has no code path yet, on purpose.

## alerts go where your humans are

the watcher's notices are the same calm one-liner everywhere; the log, a slack incoming webhook, or a discord webhook. set `KILOWATT_SLACK_WEBHOOK` or `KILOWATT_DISCORD_WEBHOOK` and the sink is picked up; with neither set, the log is the sink. delivery is wrapped, so a dead webhook can never take the watcher down with it.

## two postures

armed, and watch. armed stops the loop the moment a window breaks. watch sees everything and touches nothing; it just counts what it would have saved. watch mode is how you earn the right to arm the breaker, and the report you show before anyone hands you the kill switch.

## how it works

usage events flow into the core, the core keeps a rolling ledger per account, evaluates your policy, and when a window blows its limit it trips. trip means enforcement; suspend the service, scale to zero, or kill it. everything after the trip is counted as prevented spend.

```
usage events → core (rust) → verdict: allow | throttle | hard stop
                   ↑                        ↓
           policies (cue)           watcher (elixir) → alerts, webhooks
```

## the pieces, and why each language

| piece | language | why that one |
| --- | --- | --- |
| `core/` | rust | the breaker itself; no gc pauses at the moment you decide to cut a resource, and it is where cloud sdks live later |
| `watcher/` | elixir | one tiny supervised process per account; one account going sideways never touches the rest |
| `policies/` | cue | spend rules as data, validated before they get near production |
| `proto/` | protobuf | the contract between the pieces |
| `web/` | node, zero deps | the dashboard and a live trip demo |

## quickstart

fresh workspace with no toolchain? run `bash scripts/bootstrap.sh` once to put rust, elixir, and cue back. they live in the cache so the repo stays the only thing that persists.

the core demo replays a runaway durable objects loop against a real policy and shows the trip.

```bash
cd core
cargo run --release
```

replay a real billing export through the breaker; any provider, one json event per line, money in cents, as many accounts mixed in as the export carries. every account with a policy gets its own breaker, armed and watching; accounts without one get set aside and counted. add `--verbose` for the full transcript per account, `--audit <path>` to log every order. `docs/METERING.md` has the shape and recipes for aws and cloudflare exports.

```bash
cd core
cargo run --release -- ingest ../metering/sample-bill.jsonl
```

the watcher demo does the same trip through the beam, one process per account.

```bash
cd watcher
mix run -e "Killowatt.Demo.run()"
```

the watcher reads the same registry the core does; `Killowatt.PolicyRegistry.start_from_registry()` stands up one watcher per exported policy, so adding an account is one cue file and one re-export.

policies are cue files; validate and export them like this.

```bash
cue vet ./policies/...
cue export ./policies -e acme -o policies/acme.json
cue export ./policies -o policies/accounts.json
```

the first export feeds the built-in sim; the second is the registry the core reads at ingest, one policy per account.

the dashboard runs a live simulation with a trip you can watch happen, and the posture switch flips it between armed and watch mode.

```bash
cd web
node server.js
# then open http://localhost:8080
```

## what a trip looks like

```
t+07:00   state   burst $23.38 of $40.00; hour $23.38 of $60.00
t+07:58   TRIP    durable-objects blew the burst window; $40.20 of $40.00 allowed
t+07:58   stop    suspended durable-objects on acme-prod; action hard_stop
t+20:00   summary spent before trip $40.20; prevented after $209.38 and counting
```

and the same incident in watch mode;

```
t+07:58   WATCH   durable-objects blew the burst window; $40.20 of $40.00 allowed
t+07:58   note    nothing touched; killowatt would have stopped this
t+20:00   summary spent, untouched $333.72; would have saved $209.94
```

## where this goes next

- the live metering poller is scaffolded in the watcher with a fake producer and a cloudflare client; it wakes up the day a real token shows up
- anomaly scoring on top of the plain thresholds; julia service, later
- the rest is credentials; both live adapters and the poller are waiting on tokens, not code

## house rules

- money is integer cents everywhere; floats do not touch money
- policies are validated in cue before deploy, never in production
- copy and docs: no em dashes; use ; or , or an arrow where you need a break
