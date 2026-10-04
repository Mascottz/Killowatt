# Security

Killowatt holds the kill switch, so the credentials around it deserve care.

## Handling credentials

- Everything reads from environment variables; nothing is written to disk by killowatt itself, and `.env` is git-ignored
- Scope tokens to the smallest set of permissions that works; the readme lists the minimum per provider
- Dry-run is the default enforcement mode; the live adapters only act when `KILOWATT_ENFORCE_MODE` is set explicitly
- The audit log (`--audit <path>`) records every order as json; keep it somewhere that answers questions later

## Least privilege per provider

- **Cloudflare**; account-scoped token with Workers Scripts: Edit and Analytics: Read, pinned to one account
- **Aws**; a key with only `autoscaling:UpdateAutoScalingGroup` on the specific group arns it should touch

## If something goes wrong

Revoke or roll the credential at the provider first; every enforcement path is reversible, and the undo rides with every order's notice. then open an issue with what happened, without pasting secrets into it.
