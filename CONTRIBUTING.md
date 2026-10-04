# Contributing

The short version; keep the money in integer cents, keep the copy calm, and make the tests pass before pushing. ci runs the same checks locally.

## Run the checks

```bash
cd core && cargo test                       # the breaker, 15 tests
cd watcher && mix test                      # the beam side, 35 tests
cue vet ./policies/...                      # the policies
```

## Add an account

One cue file next to `policies/acme.cue`, then re-export;

```bash
cue export ./policies -e acme -o policies/acme.json
cue export ./policies -o policies/accounts.json
```

Ci fails if the exports drift from the source, so keep both in the same commit. the core and the watcher both pick the account up from the registry; nothing else to wire.

## Add an enforcement adapter

The shape is small; implement the side effect, carry the undo in the notice, and never let a failure crash the watcher. `lib/killowatt/enforcement/cloudflare.ex` and `aws.ex` are the two references. then add the mode to `Killowatt.Enforcement.apply_order/2` and pin the behaviour with a test that never touches a real api.

## Add a metering producer

Anything that can turn provider data into `%{service: String.t(), cents: non_neg_integer()}` implements `Killowatt.Metering.Client`. the cloudflare client is the reference; the parse step is pure and pinned by tests, and a new producer should be too.

## Style

- Lowercase, first person, casual; the docs read like a person wrote them
- No em dashes anywhere; use ; or , or an arrow where a break is needed
- Money is integer cents; if a float touches money, the change is wrong
