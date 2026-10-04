# security

killowatt holds the kill switch, so the credentials around it deserve care.

## handling credentials

- everything reads from environment variables; nothing is written to disk by killowatt itself, and `.env` is git-ignored
- scope tokens to the smallest set of permissions that works; the readme lists the minimum per provider
- dry-run is the default enforcement mode; the live adapters only act when you set `KILOWATT_ENFORCE_MODE` explicitly
- the audit log (`--audit <path>`) records every order as json; keep it somewhere you can answer questions from

## least privilege per provider

- **cloudflare**; account-scoped token with Workers Scripts: Edit and Analytics: Read, pinned to one account
- **aws**; a key with only `autoscaling:UpdateAutoScalingGroup` on the specific group arns it should touch

## if something goes wrong

revoke or roll the credential at the provider first; every enforcement path is reversible, and the undo rides with every order's notice. then open an issue with what you saw, without pasting secrets into it.
