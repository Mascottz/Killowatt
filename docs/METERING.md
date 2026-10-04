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

`metering/sample-bill.jsonl` is two and a half hours of five-minute buckets for acme-prod with a durable objects retry loop starting at minute 95, plus some staging noise to prove the filtering. armed, the breaker trips on the burst window at t+100 after $52.61 spent and prevents $226.43; in watch mode the same export would have saved $249.89. slower leaks trip on the hour, fast loops trip on the burst; whichever window breaks first is the one that gets reported.

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

cloudflare; the graphql analytics api gives usage counts for workers and durable objects, and the $34k incidents live in those counts. multiply operations by the published per-operation price, bucket per minute, and emit the same shape. usage in, dollars out, same contract.

## what needs credentials

the live path. a poller that hits provider apis on a schedule and emits these events continuously, instead of replaying an export. the design is already set; the poller is just another producer of the same event shape, and it belongs in the watcher where side effects live. the gate is a token in an environment variable, and it is the next thing to build the moment one shows up.

## granularity notes

- the burst window is 600s by default, so bucket resolution matters; five minute buckets still catch a loop, hourly exports still trip, but on the hourly and daily windows
- one event per service per bucket is the sweet spot; more granularity is fine, less loses the loop signal
- clocks are provider clocks; the replay does not care about wall time, only ordering and spacing
