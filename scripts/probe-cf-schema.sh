#!/usr/bin/env bash
# introspect the cloudflare graphql schema; run this if the metering
# client ever reports an unknown field. needs CLOUDFLARE_API_TOKEN.
set -euo pipefail

: "${CLOUDFLARE_API_TOKEN:?set CLOUDFLARE_API_TOKEN first}"

gq() {
  curl -fsS https://api.cloudflare.com/client/v4/graphql \
    -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
    -H "Content-Type: application/json" \
    --data "{\"query\": $(python3 -c "import json,sys; print(json.dumps(sys.argv[1]))" "$1")}"
}

echo "== durable objects datasets =="
gq '{ __schema { types { name } } }' | python3 -c "
import json, sys
d = json.load(sys.stdin)
for t in d['data']['__schema']['types']:
    if 'DurableObject' in t['name'] and t['name'].endswith('AdaptiveGroups'):
        print(' ', t['name'])
"

echo
echo "== durable objects fields on account =="
gq '{ __type(name: "account") { fields { name } } }' | python3 -c "
import json, sys
d = json.load(sys.stdin)
for f in d['data']['__type']['fields']:
    if 'urable' in f['name'] or 'orker' in f['name'].lower():
        print(' ', f['name'])
"

echo
echo "== invocations group shape =="
gq '{ __type(name: "AccountDurableObjectsInvocationsAdaptiveGroupsSum") { fields { name } } }' \
  | python3 -c "
import json, sys
d = json.load(sys.stdin)
t = d['data']['__type']
print(' ', 'sum fields:', [f['name'] for f in t['fields']] if t else '(type gone; schema drifted)')
"
