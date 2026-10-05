# Killowatt

The hard stop for runaway cloud spend.

[![ci](https://github.com/Mascottz/Killowatt/actions/workflows/ci.yml/badge.svg)](https://github.com/Mascottz/Killowatt/actions/workflows/ci.yml)

A misconfigured loop once burned $34k in 8 days and nobody noticed until the invoice landed. alerts fire after the money is already gone. killowatt is the part that actually stops it; it watches usage in real time, checks the spend policies, and trips the breaker before the bill gets away.

Not another dashboard. not another budget alert. a circuit breaker.

## See it work first

Everything below runs offline, no accounts, no tokens, nothing to bill.

```bash
# once per machine with no toolchain; rust, elixir, and cue
bash scripts/bootstrap.sh

# the incident, replayed armed and watching; a trip to read
cd core && cargo run --release

# the same trip through the beam, one process per account
cd watcher && mix run -e "Killowatt.Demo.run()"

# the dashboard, a live simulation with a posture switch
cd web && node server.js   # then open http://localhost:8080
```

The two postures are the whole philosophy. armed stops the loop the moment a window breaks. watch sees everything and touches nothing, and counts what it would have saved. the right to arm the breaker starts in watch mode.

## Replay a real bill, any provider

One json event per line, money in integer cents, as many accounts mixed in as the export carries. every account with a policy gets its own breaker, armed and watching; accounts without one get set aside and counted.

```bash
cd core
cargo run --release -- ingest ../metering/sample-bill.jsonl
```

Add `--verbose` for the full transcript per account, `--audit <path>` to append every enforcement order as one json line. `docs/METERING.md` has the event shape and conversion recipes for aws and cloudflare exports.

## Plug in a real cloud

Copy `.env.example` to `.env`, fill in what is available, and source it. every variable is optional; each one only wakes up one more piece, and nothing acts until the enforcement mode is set.

**Cloudflare**, live metering plus the suspend adapter:

```bash
# token needs account-scoped Workers Scripts: Edit and Analytics: Read
scripts/check-cloudflare.sh            # verify everything, read-only
cd watcher && mix run ../scripts/watch-live.exs    # the real poller, real bills
```

The check script detects the account the token can actually see, so a pasted id that points somewhere else gets caught. the poller meters durable objects invocations per script name, and the moment an account trips, the adapter suspends the worker behind it; enabling it again is the undo.

**Aws**, the scale-to-zero adapter:

```bash
# least privilege is autoscaling:UpdateAutoScalingGroup on the mapped group arns
cd watcher && mix run ../scripts/check-aws.exs     # signs an sts call with our own sigv4
```

On a trip the adapter scales the auto scaling group behind the service to zero; restoring its previous min and desired is the undo. `KILOWATT_ASG_MAP` maps tripped services to group names.

**Alerts**, same calm one-liner everywhere:

Set `KILOWATT_SLACK_WEBHOOK` or `KILOWATT_DISCORD_WEBHOOK` and notices go there; with neither set, the log is the sink. delivery is wrapped, so a dead webhook can never take the watcher down.

**Enforcement is dry-run until switched.** the default mode reports what would happen and touches nothing; `--audit` keeps the record. `KILOWATT_ENFORCE_MODE=cloudflare` or `aws` turns the real adapters on. reversible first, lethal later; kill is a policy word that has no code path yet, on purpose.

## Anomaly scoring

Thresholds catch the obvious; the scorer catches the shape. it is a small julia service, stdlib only, that reads the same event stream and scores every event against its own recent history with a robust z-score; median and mad, no float-poisoned averages.

```bash
julia scorer/score.jl metering/sample-bill.jsonl
```

Each event comes back with its score, its baseline in cents, and a flag. on the sample bill it lights up the durable objects loop and the queue-worker leak on the exact first bucket of each, scores of 217 and 326 against a flag threshold of 3.5. window, threshold, and burn-in are arguments; the scoring stays advisory for now, feeding the same alerts the thresholds raise.

## Policies are data

Spend rules live in cue, validated before they get near production.

```bash
cue vet ./policies/...
cue export ./policies -e acme -o policies/acme.json    # the built-in sim
cue export ./policies -o policies/accounts.json        # the registry
```

The registry is the one source of truth both sides read; the rust core at ingest and the watcher at startup, through `Killowatt.PolicyRegistry`. adding an account is one cue file and one re-export; ci fails if the exports drift from the source.

## How it works

Usage events flow into the core, the core keeps a rolling ledger per account, evaluates the policy, and when a window blows its limit it trips. trip means enforcement; suspend the service, scale to zero, or kill it. everything after the trip is counted as prevented spend.

```
usage events → core (rust) → verdict: allow | throttle | hard stop
                   ↑                        ↓
           policies (cue)           watcher (elixir) → alerts, webhooks
```

## The pieces, and why each language

| piece | language | why that one |
| --- | --- | --- |
| `core/` | rust | the breaker itself; no gc pauses at the moment a resource gets cut |
| `watcher/` | elixir | one tiny supervised process per account; one account going sideways never touches the rest |
| `policies/` | cue | spend rules as data, validated before they get near production |
| `proto/` | protobuf | the contract between the pieces |
| `scorer/` | julia | anomaly scoring; the numeric heavy lifting lives in the language built for it |
| `web/` | node, zero deps | the dashboard and a live trip demo |

## What a trip looks like

```
t+07:00   state   burst $23.38 of $40.00; hour $23.38 of $60.00
t+07:58   TRIP    durable-objects blew the burst window; $40.20 of $40.00 allowed
t+07:58   stop    suspended durable-objects on acme-prod; action hard_stop
t+20:00   summary spent before trip $40.20; prevented after $209.38 and counting
```

And the same incident in watch mode;

```
t+07:58   WATCH   durable-objects blew the burst window; $40.20 of $40.00 allowed
t+07:58   note    nothing touched; killowatt would have stopped this
t+20:00   summary spent, untouched $333.72; would have saved $209.94
```

## What this does not do

Killowatt measures spend and opens a breaker on it, per account and per policy. It does not bound the blast radius of a credential; stopping the meter is not the same as narrowing the reach.

Three things worth stating rather than leaving to inference:

- Spend is the only signal. A leaked key that reaches everything still reaches everything until the breaker trips and its action fires.
- Scope stays with the platform. IAM, network boundaries and credential reach are the cloud's job, and the least privilege notes in "Plug in a real cloud" are where killowatt asks for its own narrow token.
- Per-service limits narrow what a policy watches, not what a credential may touch. The two are easy to confuse, and the confusion flatters the tool.

Stated because a spend cap that reads like reach control is a promise killowatt cannot keep, and being trusted for one small thing beats being believed for two.

## Where this goes next

- Scoring advice joining the trip decision; today it raises its hand beside the thresholds, tomorrow it gets a vote
- The aws poller wants live proof the way the cloudflare one got it; the code and its signer are ready, an access key is the gate
- See `CONTRIBUTING.md` for where new adapters and policies slot in

## House rules

- Money is integer cents everywhere; floats do not touch money
- Policies are validated in cue before deploy, never in production
- Dry run first, watch mode first, audit log always
- Copy and docs: no em dashes; use ; or , or an arrow where a break is needed
