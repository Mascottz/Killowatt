# show hn; paste this when ready

post between tuesday and thursday, roughly 14:00 to 17:00 lagos time; that
is us east coast morning. title first, then the body.

## title

Show HN: Killowatt, a circuit breaker for runaway cloud spend

## body

a misconfigured loop once burned $34k in 8 days, and nobody noticed until the invoice landed. alerts fire after the money is already gone; killowatt is the part that actually stops it.

it watches usage in real time, checks spend policies written as data, and trips a breaker; suspending the service behind the runaway, with the undo riding along in every order. watch mode sees everything, touches nothing, and counts what it would have saved; the right to arm it starts there.

rust core, one elixir process per account, cue policies, a julia anomaly scorer, zero dependencies anywhere it matters. no account needed to see the trip demo; the readme starts offline on purpose.

https://github.com/Mascottz/Killowatt

## after posting

- stay in the thread for the first two hours; answer everything
- if a comment asks for the longer story, the canonical write-up is live; https://dev.to/mascottz/i-built-a-circuit-breaker-for-runaway-cloud-spend-ka6
- if a question lands about provider x, the answer is the adapter shape in contributing.md, and an issue is already open for it
- do not edit the title after posting unless it is broken
