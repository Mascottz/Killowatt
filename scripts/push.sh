#!/usr/bin/env bash
# push to github from a fresh workspace. the workspace forgets git config,
# so this re-adds the remote and pushes; it never stores the token.
#
# give it the token one of two ways;
#   export KILOWATT_GH_TOKEN=github_pat_...   then run this
#   or save it in ~/.config/killowatt-token (one line, chmod 600)
set -e

cd "$(dirname "$0")/.."

REMOTE_URL="https://github.com/Mascottz/Killowatt.git"
TOKEN="${KILOWATT_GH_TOKEN:-}"
if [ -z "$TOKEN" ] && [ -f "$HOME/.config/killowatt-token" ]; then
  TOKEN="$(head -1 "$HOME/.config/killowatt-token" | tr -d '[:space:]')"
fi

if [ -z "$TOKEN" ]; then
  echo "no token found; export KILOWATT_GH_TOKEN or write ~/.config/killowatt-token"
  exit 1
fi

git remote get-url origin >/dev/null 2>&1 || git remote add origin "$REMOTE_URL"
git fetch origin
git branch --set-upstream-to=origin/main main 2>/dev/null || true

# the token rides in this one command only; it never lands in git config
git push "https://x-access-token:${TOKEN}@github.com/Mascottz/Killowatt.git" main:main

echo "pushed; github.com/Mascottz/Killowatt is up to date"
