# architecture

the shape of the thing, so future me remembers why it looks like this.

## the flow

1. metering pushes usage events; one event is a service, an account, a cost in cents, a timestamp
2. the rust core keeps a rolling ledger per account and evaluates the policy against three windows; burst, hour, day
3. every event gets a verdict; allow, throttle, or hard stop
4. on a trip the core emits a hard stop command, and the watcher turns that into provider actions and notifications
5. the ledger records what would have burned after the trip; that number is the whole pitch

```
metering ──▶ core (rust)
              │  ledger per account
              │  policy evaluation
              ▼
           verdicts ──▶ watcher (elixir) ──▶ provider actions
              │               │
              ▼               └──▶ alerts, webhooks
           web dashboard ◀── sse stream
```

## the core, rust

the core is deliberately dumb and fast. rolling windows, integer cents, no floats, no cloud sdk calls. it only decides. cloud api access lives in the enforcement path so the decision engine stays small enough to trust.

three checks per event, in order;

1. burst window; the loop catcher; a retry storm shows up here first
2. hourly limit; the slow leak catcher
3. daily limit; the last line

exempt services get recorded but never count against limits; backups should not take the blame for another service's loop.

the policy action sets the posture; hard_stop and throttle trip the breaker, and alert_only is watch mode. in watch mode nothing is blocked, the breach is noted once, and every non-exempt charge after the first breach accumulates as would-have-saved. that number is the report that earns the kill switch later.

## the watcher, elixir

one genserver per account under a dynamic supervisor. the beam gives me per account isolation for free; account 4,312 crashing does not wake account 4,313. the watcher evaluates the same three windows the core does, burst, hour, day, in the same order; the watcher owns side effects, enforcement dispatch, alert delivery to slack or discord, webhooks. it never does math that the core should own. notices travel through the alerts genserver and out a sink; the sink is picked from the environment and delivery is wrapped, because a dead webhook must never take the watcher down. the watcher reads the same exported registry the core does, `policies/accounts.json`, through `Killowatt.PolicyRegistry`; one cue source, one watcher per account, and no way for the two sides to drift apart.

## policies, cue

policies are data, validated at build time. `cue vet` before deploy, `cue export` to json for the core. if a policy does not pass vet it never ships. the schema is in `policies/schema.cue`, accounts live next to it. `cue export ./policies` also produces `policies/accounts.json`, the registry the core loads at ingest; one policy per account, one breaker per account, and any account in the bill without a policy gets its events set aside and counted rather than silently ignored.

## enforcement

a trip becomes an order. the core produces orders (suspend, throttle; kill exists as a word and nothing more, on purpose), and the watcher executes them through a mode; dry run by default, cloudflare when the creds show up, test sink in tests. every order carries its undo. dry run and the audit log are the trust ramp for enforcement the same way watch mode is the trust ramp for the breaker; nobody arms what they cannot first watch, and nobody enforces what they cannot first audit.

## contracts, protobuf

`proto/killowatt.proto` is the wire contract between core, watcher, and anything else that shows up later. if a field is not in the proto it does not exist.

## metering

the core consumes one event shape; account, service, cents, timestamp. producers today;

- the built-in sim, for the demo
- `ingest`, which replays a billing export in that shape; real bills, same treatment, see docs/METERING.md
- the cloudflare live client, verified against a real account; durable objects invocations per script, graphql in, cents out
- the aws live client, ready for a key; cost explorer GetCostAndUsage in, cents out, signed by the same sigv4 the enforcement adapter uses

the poller lives in the watcher where side effects live and speaks the client contract; a fake producer keeps the offline path honest. beside the thresholds sits the julia scorer, `scorer/score.jl`; it reads the same stream and scores each event against its own recent history, median and mad, advisory today.

## what is a demo vs what is real

honest status;

- real; the ledger, the policy evaluation, the trip logic, watch mode, the ingest path, the cue schema, the contracts, the cloudflare live path, both enforcement adapters, the scorer
- gated on credentials; the aws live path, and the cloudflare adapter acting on a real account with real workers deployed
- demo; the built-in usage source is simulated, and the sample bill is generated, both on purpose
