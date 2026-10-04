# contributing

the short version; keep the money in integer cents, keep the copy calm, and make the tests pass before you push. ci runs the same checks you can run locally.

## run the checks

```bash
cd core && cargo test                       # the breaker, 15 tests
cd watcher && mix test                      # the beam side, 35 tests
cue vet ./policies/...                      # the policies
```

## add an account

one cue file next to `policies/acme.cue`, then re-export;

```bash
cue export ./policies -e acme -o policies/acme.json
cue export ./policies -o policies/accounts.json
```

ci fails if the exports drift from the source, so keep both in the same commit. the core and the watcher both pick the account up from the registry; nothing else to wire.

## add an enforcement adapter

the shape is small; implement the side effect, carry the undo in the notice, and never let a failure crash the watcher. `lib/killowatt/enforcement/cloudflare.ex` and `aws.ex` are the two references. then add the mode to `Killowatt.Enforcement.apply_order/2` and pin the behaviour with a test that never touches a real api.

## add a metering producer

anything that can turn provider data into `%{service: String.t(), cents: non_neg_integer()}` implements `Killowatt.Metering.Client`. the cloudflare client is the reference; the parse step is pure and pinned by tests, and yours should be too.

## style

- lowercase, first person, casual; the docs read like a person wrote them
- no em dashes anywhere; use ; or , or an arrow where you need a break
- money is integer cents; if a float touches money, the change is wrong
