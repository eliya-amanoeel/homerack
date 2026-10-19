#!/usr/bin/env bash
# Refresh the emergency DNS restore copy on the Pi (HL-45).
#
# ~/stacks/network-core-fallback/ holds a plain copy of the network-core compose
# file. It exists because the normal path — Portainer cloning this repo — needs
# DNS, which is exactly what you would be restoring. A local copy has no such
# dependency.
#
# Being a copy, it drifts. Run this after any change to the network-core stack.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

HOST="${HOMELAB_PI_HOST:-pi@kish.lan}"
SRC="hosts/kish/stacks/network-core/docker-compose.yml"
DST="~/stacks/network-core-fallback/docker-compose.yml"

ssh "$HOST" 'mkdir -p ~/stacks/network-core-fallback' || exit 1
scp -q "$SRC" "$HOST:$DST" || { echo "copy failed"; exit 1; }

# Prove the copy matches, rather than assuming scp did the right thing.
local_sum=$(shasum -a 256 "$SRC" | cut -d' ' -f1)
remote_sum=$(ssh "$HOST" "sha256sum $DST" | cut -d' ' -f1)

if [ "$local_sum" = "$remote_sum" ]; then
  echo "fallback in sync  ($(echo "$local_sum" | cut -c1-12)…)"
  ssh "$HOST" "cd ~/stacks/network-core-fallback && docker compose -p network-core config --quiet" \
    && echo "compose file valid on the Pi"
else
  echo "MISMATCH after copy — local $local_sum vs remote $remote_sum"; exit 1
fi
