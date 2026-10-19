# Runbook: take a backup

**When:** before any upgrade or risky change, and occasionally otherwise.
**Time:** about a minute.
**Prerequisite:** none — no sudo, no accounts, no schedule.

Backups are deliberately manual and local. Why, and what they do and do not
protect, is in [ADR 0006](../decisions/0006-backups-are-deliberately-modest.md).
The short version: a total loss of the Pi costs about an hour against
[the rebuild runbook](rebuild-kish.md), because everything else lives in git.

## Take one

From the repo on your Mac:

```bash
cd ~/homelab
./scripts/backup.sh
```

That is the whole procedure. Expect:

```
Backing up pi@kish.lan -> /Users/eliya/homelab-backups/2026-09-28
  wireguard-keys        ok  (8.0K)
  caddy-ca              ok  (8.0K)
  pihole                ok  ( 61M)
  portainer             ok  (256K)
  uptime-kuma           ok  (7.1M)
  beszel                ok  (1.1M)
  unifi-autobackup      ok  ( 96K)
  container-manifest    ok  (4.0K)

All good:
```

**All eight must say `ok`.** Any `FAILED` line means that piece was not captured —
the script exits non-zero and deletes the empty file rather than leaving a
convincing-looking husk.

Running it twice in one day overwrites that day's directory. The newest 3
backups are kept, however old; older ones are removed, but only after a
complete run: if any step failed, every older backup is kept.

## When it is worth running

- **Before upgrading anything** — an image pull, `apt upgrade`, a Pi-hole or
  unifi update
- **Before editing a stack** in Portainer or pushing a compose change
- **After changing something you would hate to redo** — new WireGuard clients,
  unifi network settings, Pi-hole local DNS records
- Otherwise, occasionally. Monthly is plenty for what this protects.

## Verify one (worth doing once, not every time)

Non-empty is not the same as restorable. To actually check:

```bash
cd /tmp && rm -rf bkcheck && mkdir bkcheck && cd bkcheck

# Pi-hole's database should pass an integrity check and hold a few hundred
# thousand domains; the count drifts with the blocklists
tar -xzf ~/homelab-backups/<date>/pihole.tar.gz ./gravity.db
sqlite3 gravity.db "PRAGMA integrity_check;"          # expect: ok
sqlite3 gravity.db "SELECT COUNT(*) FROM gravity;"    # 268252 on 2026-10-13

# WireGuard should contain the server config and the client database
tar -tzf ~/homelab-backups/<date>/wireguard.tar.gz    # expect: wg0.conf, wg-easy.db

# unifi should contain a real .unf autobackup, not an empty directory
tar -tzf ~/homelab-backups/<date>/unifi-autobackup.tar.gz | grep '\.unf'
```

## ⚠️ These files contain secrets

`~/homelab-backups/` holds WireGuard's server and client private keys,
Caddy's internal CA root key, Portainer's TLS keys and its GitHub token, Beszel's
hub SSH key, and Pi-hole's admin password hash.
The directory is `chmod 700`. Do not sync it to cloud storage unencrypted, and
do not hand the archives to anyone.

## What is NOT in here

- **Website content** — in its own git repos
- **The OS itself** — rebuilt from [rebuild-kish.md](rebuild-kish.md)
- **Proxmox guests** — backed up by Proxmox's own daily job, see [hosts/anu/](../../hosts/anu/README.md)
