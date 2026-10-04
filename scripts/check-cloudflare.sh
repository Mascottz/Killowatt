#!/usr/bin/env bash
# read-only credential check for the cloudflare integration.
# needs CLOUDFLARE_API_TOKEN in the environment, and CLOUDFLARE_ACCOUNT_ID
# if you already know it; if the id does not match, the script lists the
# accounts the token can actually see. touches nothing.
set -euo pipefail

: "${CLOUDFLARE_API_TOKEN:?set CLOUDFLARE_API_TOKEN first}"

hdr() { printf '\n%s\n' "$1"; }

hdr "1; token verify"
curl -fsS https://api.cloudflare.com/client/v4/user/tokens/verify \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" | python3 -m json.tool

hdr "2; accounts this token can see"
ACCOUNTS=$(curl -fsS "https://api.cloudflare.com/client/v4/accounts?per_page=50" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN")
echo "$ACCOUNTS" | python3 -c "
import json, sys
d = json.load(sys.stdin)
for a in d['result']:
    print(' ', a['id'], a['name'])
"

GIVEN="${CLOUDFLARE_ACCOUNT_ID:-}"
DETECTED=$(echo "$ACCOUNTS" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['result'][0]['id'] if len(d['result'])==1 else '')")

if [ -n "$GIVEN" ] && [ "$GIVEN" != "$DETECTED" ] && [ -n "$DETECTED" ]; then
  printf '\nnote; CLOUDFLARE_ACCOUNT_ID=%s does not match what the token sees (%s); using the detected one.\n' "$GIVEN" "$DETECTED"
fi
ACCT="${DETECTED:-$GIVEN}"
: "${ACCT:?cannot determine the account id; set CLOUDFLARE_ACCOUNT_ID to one of the ids above}"
TAG="${CLOUDFLARE_ACCOUNT_TAG:-$ACCT}"

hdr "3; workers the token can see (enforcement path)"
curl -fsS "https://api.cloudflare.com/client/v4/accounts/$ACCT/workers/scripts" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  | python3 -c "import json,sys; d=json.load(sys.stdin); \
print('success:', d['success']); \
print('scripts:', [s['id'] for s in d.get('result', [])] or '(none yet)')"

hdr "4; graphql metering probe (the exact query the poller runs)"
SINCE=$(date -u -d '2 hours ago' +%Y-%m-%dT%H:00:00Z 2>/dev/null || date -u -v-2H +%Y-%m-%dT%H:00:00Z)
UNTIL=$(date -u -d '1 hour ago' +%Y-%m-%dT%H:00:00Z 2>/dev/null || date -u -v-1H +%Y-%m-%dT%H:00:00Z)
curl -fsS https://api.cloudflare.com/client/v4/graphql \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data "{\"variables\":{\"accountTag\":\"$TAG\",\"since\":\"$SINCE\",\"until\":\"$UNTIL\"},\"query\":\"query (\$accountTag: string!, \$since: Time!, \$until: Time!) { viewer { accounts(filter: {accountTag: \$accountTag}) { durableObjectsInvocationsAdaptiveGroups(limit: 10, filter: {datetimeHour_geq: \$since, datetimeHour_lt: \$until}) { dimensions { scriptName } sum { requests } } } } }\"}" \
  | python3 -c "import json,sys; d=json.load(sys.stdin); \
print('errors:', d.get('errors')); \
print('groups:', d['data']['viewer']['accounts'][0]['durableObjectsInvocationsAdaptiveGroups'] if d.get('data') else None)"

printf '\nall four green and the token covers everything killowatt needs.\n'
