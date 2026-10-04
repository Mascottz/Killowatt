# dev.to draft; paste into a new post, add the screenshot where marked

title; i built a circuit breaker for runaway cloud spend
tags; devops, cloud, rust, elixir

---

a misconfigured loop once burned $34k in 8 days. not a typo, and not a big company; the invoice was the first anyone heard of it. i kept coming back to that story, because the uncomfortable part is not the loop. loops happen. the uncomfortable part is that every tool in the stack saw it coming, and every tool waited for the invoice to do something about it.

budget alerts fire after the money is gone. dashboards show you the fire while it is still burning. i wanted the part that actually stops it.

so i built killowatt. it is a circuit breaker for cloud spend; it watches usage in real time, checks it against spend policies, and trips before the bill gets away.

## the shape of it

usage events flow in, one shape for any provider; an account, a service, a cost in integer cents, a timestamp. the core keeps a rolling ledger per account and checks three windows, in order; a burst window of ten minutes, the hour, and the day. whichever breaks first is the one that gets reported, and the moment one does, the breaker trips.

trip means enforcement. today that is two live adapters; one suspends the cloudflare worker behind the tripped service, one scales the aws auto scaling group behind it to zero. every order carries its own undo, and dry run is the default until you say otherwise. reversible first, lethal later.

## watch before you arm

the posture i am proudest of is watch mode. armed, the breaker stops the loop the moment a window breaks. watching, it sees everything and touches nothing; the account keeps spending and the watcher just counts what it would have saved.

you run the same bill through both and the report writes itself;

```
armed   spent $40.20, then stopped it; prevented $209.38
watch   touched nothing, saw everything; would have saved $209.94
```

watch mode is how you earn the right to arm the breaker, and it is the report you show before anyone hands you the kill switch.

<!-- paste a screenshot of the dashboard trip here -->

## why the strange stack

the pieces are deliberately polyglot, each language sitting where it is best;

- the breaker core is rust; no gc pauses at the moment you decide to cut a resource
- the watchers are elixir; one tiny supervised process per account, and one account going sideways never touches the rest
- the policies are cue; spend rules as data, validated before they get near production
- the anomaly scorer is julia; median and mad against each service's own history, and it catches a runaway on the exact first bucket
- the dashboard is zero-dependency node; because it should be

the polyglot part earns its keep for one reason; the core and the watcher share one policy registry, exported from cue, so the two sides cannot drift apart. one source of truth matters more than one language.

## what actually works today

the offline story runs from a fresh clone with nothing installed but the bootstrap script; the incident replayed armed and watching, the beam demo, the dashboard with a trip you can watch happen.

the live path is real for cloudflare; the poller meters durable objects invocations straight from graphql, verified against a live account before i shipped it. the aws metering client is built and its signer is verified against aws's own test vectors; it wakes up the day a key shows up. the sample bill carries two planted incidents, a fast loop and a slow leak, and the scorer lights up both on their exact first bucket.

## what i would tell anyone building this

- money is integer cents everywhere; floats do not touch money
- watch mode is not a demo feature, it is the trust ramp; nobody arms what they cannot first watch
- dry run plus an audit log is the same ramp for enforcement; nobody enforces what they cannot first audit
- the $34k class of incident is not caught by better alerts, it is caught by a part of the system that is allowed to say no

it is young, the issues labeled good first issue are genuinely small, and the readme starts offline on purpose. if your cloud bill has ever surprised you, come break it.

https://github.com/Mascottz/Killowatt
