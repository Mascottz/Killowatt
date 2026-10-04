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

exempt services get recorded but never count against limits; backups should not take the blame for someone's loop.

the policy action sets the posture; hard_stop and throttle trip the breaker, and alert_only is watch mode. in watch mode nothing is blocked, the breach is noted once, and every non-exempt charge after the first breach accumulates as would-have-saved. that number is the report you show before anyone hands you the kill switch.

## the watcher, elixir

one genserver per account under a dynamic supervisor. the beam gives me per account isolation for free; account 4,312 crashing does not wake account 4,313. the watcher owns side effects; provider actions, alert dispatch, webhooks. it never does math that the core should own.

## policies, cue

policies are data, validated at build time. `cue vet` before deploy, `cue export` to json for the core. if a policy does not pass vet it never ships. the schema is in `policies/schema.cue`, accounts live next to it.

## contracts, protobuf

`proto/killowatt.proto` is the wire contract between core, watcher, and anything else that shows up later. if a field is not in the proto it does not exist.

## what is a demo vs what is real

honest status;

- real; the ledger, the policy evaluation, the trip logic, the cue schema, the contracts
- demo; the usage source is simulated; the enforcement action is a log line, not a cloud call
- next; aws cost and usage into the core, then real suspend actions via the rust sdk
