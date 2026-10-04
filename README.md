# killowatt

the hard stop for runaway cloud spend.

a misconfigured loop once burned $34k in 8 days and nobody noticed until the invoice landed. alerts fire after the money is already gone. killowatt is the part that actually stops it; it watches usage in real time, checks your spend policies, and trips the breaker before the bill gets away.

not another dashboard. not another budget alert. a circuit breaker.

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

the watcher demo does the same trip through the beam, one process per account.

```bash
cd watcher
mix run -e "Killowatt.Demo.run()"
```

policies are cue files; validate and export them like this.

```bash
cue vet ./policies/...
cue export ./policies -e acme -o policies/acme.json
```

the dashboard runs a live simulation with a trip you can watch happen.

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

## where this goes next

- real metering from aws, gcp, and cloudflare into the core
- enforcement actions per provider, via the rust sdks
- webhooks and slack from the watcher
- anomaly scoring on top of the plain thresholds; julia service, later

## house rules

- money is integer cents everywhere; floats do not touch money
- policies are validated in cue before deploy, never in production
- copy and docs: no em dashes; use ; or , or an arrow where you need a break
