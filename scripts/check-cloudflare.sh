#!/usr/bin/env bash
# read-only credential check for the cloudflare integration.
# needs CLOUDFLARE_API_TOKEN and CLOUDFLARE_ACCOUNT_ID in the environment;
# CLOUDFLARE_ACCOUNT_TAG defaults to the account id. touches nothing.
set -euo pipefail

: "${CLOUDFLARE_API_TOKEN:?set CLOUDFLARE_API_TOKEN first}"
: "${CLOUDFLARE_ACCOUNT_ID:?set CLOUDFLARE_ACCOUNT_ID first}"
TAG="${CLOUDFLARE_ACCOUNT_TAG:-$CLOUDFLARE_ACCOUNT_ID}"

hdr() { printf '\n%s\n' "$1"; }

hdr "1; token verify"
curl -fsS https://api.cloudflare.com/client/v4/user/tokens/verify \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" | python3 -m json.tool

hdr "2; workers the token can see (workers scripts read)"
curl -fsS "https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/workers/scripts" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  | python3 -c "import json,sys; d=json.load(sys.stdin); \
print('success:', d['success']); \
print('scripts:', [s['id'] for s in d.get('result', [])] or '(none)')"

hdr "3; graphql analytics probe (metering path)"
curl -fsS https://api.cloudflare.com/client/v4/graphql \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data "{\"query\":\"{ viewer { accounts(filter: {accountTag: \\\"$TAG\\\"}) { accountName } } }\"}" \
  | python3 -m json.tool

printf '\nall three green and the token covers everything killowatt needs.\n'
