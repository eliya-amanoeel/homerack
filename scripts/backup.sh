#!/usr/bin/env bash
# Pull the non-reproducible data off kish. Run from your laptop, not the Pi.
#
#   ./scripts/backup.sh [destination-dir]
#
# Captures what git cannot: WireGuard's keys, Pi-hole's config, Uptime Kuma's
# database, Beszel's hub data, and the unifi controller's autobackups. Compose
# files live in git; this is the other half.
#
# Designed to need NO sudo, so it stays a single command you can run any time.
# Nothing is scheduled — see ADR 0006. Container data is read through the containers
# themselves, using a PINNED alpine:3.20 rather than :latest so a surprise base
# image cannot break the backup path. The one exception is unifi, which is a native install owned by
# unifi:unifi — grant read access once with:
#
#     sudo usermod -aG unifi pi        # then log out and back in
#
# Without that, the unifi step falls back to `sudo -n`, which never prompts: it
# works only while a sudo session is still open on the Pi, and fails otherwise.
set -uo pipefail

HOST="${HOMELAB_PI_HOST:-pi@kish.lan}"
DEST="${1:-$HOME/homelab-backups}"
OUT="$DEST/$(date +%Y-%m-%d)"
fail=0

RETAIN="${HOMELAB_BACKUP_RETAIN:-3}"   # number of backups kept, not days

mkdir -p "$OUT"
chmod 700 "$DEST" "$OUT"   # these archives contain private keys and a token
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Backing up $HOST -> $OUT"

grab() {  # grab <label> <remote-command> <outfile>
  printf '  %-22s' "$1"
  if ssh "$HOST" "$2" > "$OUT/$3" 2>/dev/null && [ -s "$OUT/$3" ]; then
    echo "ok  ($(du -h "$OUT/$3" | cut -f1))"
  else
    echo "FAILED"; rm -f "$OUT/$3"; fail=1
  fi
}

# WireGuard first: these keys ARE remote access to the lab. If only one step
# ever succeeds, make it this one.
grab "wireguard-keys" \
  "docker run --rm -v wireguard_etc_wireguard:/d:ro alpine:3.20 tar -cz -C /d ." \
  "wireguard.tar.gz"

# Caddy — caddy_data holds the internal CA's ROOT SIGNING KEY. Lose it and Caddy
# generates a new authority, meaning every device has to trust a new root again.
grab "caddy-ca" \
  "docker run --rm -v caddy_caddy_data:/d:ro alpine:3.20 tar -cz -C /d ." \
  "caddy.tar.gz"

# Pi-hole — read through the container, so no sudo is needed whoever owns the
# bind mount under /opt/homelab/network-core/.
grab "pihole" \
  "docker exec pihole tar -cz -C /etc/pihole ." \
  "pihole.tar.gz"

# Portainer — its BoltDB holds users, environments, stack definitions, and the
# git source config INCLUDING the GitHub token. Losing it means reconfiguring
# every stack by hand. Taken live, so a mid-write snapshot could be torn; good
# enough for config that changes rarely, and better than the nothing it was.
grab "portainer" \
  "docker run --rm -v portainer_data:/d:ro alpine:3.20 tar -cz -C /d ." \
  "portainer.tar.gz"

# Uptime Kuma — named volume, read via a throwaway container.
grab "uptime-kuma" \
  "docker run --rm -v network-core_uptime-kuma-data:/d:ro alpine:3.20 tar -cz -C /d ." \
  "uptime-kuma.tar.gz"

# Beszel — alert rules, systems and the hub's SSH key. Without the key every
# agent has to be re-keyed. Metric history comes along; it is SQLite, so the
# same live-copy caveat as Portainer applies.
grab "beszel" \
  "docker run --rm -v beszel_beszel_data:/d:ro alpine:3.20 tar -cz -C /d ." \
  "beszel.tar.gz"

# unifi — native install. Works without sudo once pi is in the unifi group;
# otherwise falls back to `sudo -n`, which fails rather than prompt.
grab "unifi-autobackup" \
  "tar -cz -C /var/lib/unifi backup 2>/dev/null || sudo -n tar -cz -C /var/lib/unifi backup" \
  "unifi-autobackup.tar.gz"

# Plaintext inventory of what was running, for diffing later.
grab "container-manifest" \
  "docker ps -a --format '{{.Names}}\t{{.Image}}\t{{.Status}}'" \
  "containers.txt"

# Retention: keep the newest RETAIN backups however old they are, because runs
# are occasional (a count fits that; an age limit would leave only one). Only
# ever removes things matching the YYYY-MM-DD layout this script creates, so a
# stray file in $DEST is never touched. Skipped entirely when any step failed:
# otherwise a broken run could delete the last complete backup.
if [ "$fail" -eq 0 ]; then
  dirs=()
  for d in "$DEST"/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]; do
    [ -d "$d" ] && dirs+=("$d")   # the glob sorts by name, so oldest first
  done
  pruned=$(( ${#dirs[@]} - RETAIN ))
  if [ "$pruned" -gt 0 ]; then
    for d in "${dirs[@]:0:$pruned}"; do rm -rf "$d"; done
    echo "  pruned $pruned backup(s); the newest $RETAIN are kept"
  fi
else
  echo "  kept all older backups: this run was incomplete"
fi

echo
if [ "$fail" -eq 0 ]; then echo "All good:"; else echo "SOME STEPS FAILED — see above:"; fi
ls -lh "$OUT"

# Deliberately local-only: what these archives protect is about an hour of
# rebuilding, since everything else is in git. See
# docs/decisions/0006-backups-are-deliberately-modest.md — including the
# conditions under which that decision should be revisited.
exit "$fail"
