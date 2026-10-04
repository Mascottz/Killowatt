# metering

how real bills get into killowatt, and what is real today vs what needs credentials.

## the shape

everything that enters the core is a usage event; an account, a service, a cost in integer cents, a timestamp in milliseconds. one json object per line, any order, any account mix. the loader sorts by time and sets other accounts aside, because a breaker decides per account.

```json
{"account":"acme-prod","service":"api-gateway","cents":120,"ts_ms":1790812800000}
```

that shape is the contract. any provider, any export, any granularity; if you can get it into that shape, killowatt can replay it.

## what works today

```bash
cargo run --release -- ingest metering/sample-bill.jsonl
```

`metering/sample-bill.jsonl` is two and a half hours of five-minute buckets across three accounts; acme-prod with a durable objects retry loop starting at minute 95, infra-core with a slow queue-worker leak that only the hourly window catches, and staging noise that gets set aside because it has no policy. armed, acme-prod trips on the burst window at t+100 after $53.26 spent and prevents $226.36, while infra-core throttles at t+85 on the hourly limit after $126.96 and prevents $148.69; in watch mode the same exports would have saved $250.47 and $161.30. slower leaks trip on the hour, fast loops trip on the burst; whichever window breaks first is the one that gets reported, per account.

## getting your real bill into the shape

aws; cost explorer or a cost and usage report, grouped by service and hour, dollars converted to cents;

```bash
# from a CUR-style csv with columns lineItem/UsageStartDate, lineItem/ProductCode, lineItem/UnblendedCost
python3 - <<'EOF'
import csv, json
from datetime import datetime
for row in csv.DictReader(open("cur-export.csv")):
    ts = int(datetime.fromisoformat(row["lineItem/UsageStartDate"]).timestamp() * 1000)
    print(json.dumps({
        "account": "acme-prod",
        "service": row["lineItem/ProductCode"],
        "cents": int(round(float(row["lineItem/UnblendedCost"]) * 100)),
        "ts_ms": ts,
    }, separators=(",", ":")))
EOF
```

cloudflare; the graphql analytics api gives usage counts for workers and durable objects, and the $34k incidents live in those counts. the watcher's live client meters `durableObjectsInvocationsAdaptiveGroups` straight from graphql, one event per script name, operations in, cents out, same contract.

## the live cloudflare path

the poller is live and verified against a real account. set these in the environment:

```bash
export CLOUDFLARE_API_TOKEN="..."     # workers scripts edit + analytics read
export CLOUDFLARE_ACCOUNT_TAG="..."   # the account's tag; usually the account id
```

then verify everything read-only, and run the probe;

```bash
scripts/check-cloudflare.sh           # token, accounts, workers list, the metering query
cd watcher && mix run ../scripts/probe-live.exs   # the real poller, a few closed hours
```

the check script detects the account the token can actually see and tells you if `CLOUDFLARE_ACCOUNT_ID` points somewhere else. the dataset and field names were verified against the live schema on 2026-10-04; if cloudflare drifts the schema again, `scripts/probe-cf-schema.sh` dumps the current shape. pricing is a placeholder constant in the client, cents per million invocations; set it to your plan's published number before you trust the dollars.

## the aws live path

the watcher ships a cost explorer client too; `Killowatt.Metering.AwsClient` calls GetCostAndUsage with hourly granularity grouped by service, signed by the same sigv4 the enforcement adapter uses. it needs `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`, the identity needs `ce:GetCostAndUsage`, and `AWS_REGION` only matters for signing, since cost explorer is global. point the poller at it the same way as cloudflare; the cursor model is identical, one closed hour per poll. hourly granularity is served for the last fourteen days; polls outside that window come back empty rather than erroring.

## anomaly scoring

`scorer/score.jl` reads any stream of these events and writes them back with a score per account and service; the current event against the median and mad of its own recent window. it is the layer that catches a slow drift the thresholds are too coarse to see. advisory today; it raises its hand beside the breaker, it does not trip it.

## what still needs credentials

proof, not code. the aws live path and the cloudflare enforcement adapter both wait on credentials used against a real account with real traffic; the cloudflare metering path already has that proof.

## granularity notes

- the burst window is 600s by default, so bucket resolution matters; five minute buckets still catch a loop, hourly exports still trip, but on the hourly and daily windows
- one event per service per bucket is the sweet spot; more granularity is fine, less loses the loop signal
- clocks are provider clocks; the replay does not care about wall time, only ordering and spacing
