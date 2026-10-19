# Stack: network-core

Pi-hole + Uptime Kuma, deployed as a Portainer-managed compose stack.

## This file is the deployed one

Portainer deploys this stack from this git repository (HL-29), so changing the
stack means editing this file and pushing. It was previously a reconstruction
from `docker inspect`; the real file has since been read out of `portainer_data`
and reconciled — the only substantive differences were an obsolete
`version: "3.8"` line and the tag pin.

### Where Portainer keeps things — two paths with the same name

Confusing enough to be worth writing down. `/data/compose/1/` exists in **two**
places:

- **Inside the Portainer container** (the `portainer_data` volume) — where the
  compose file itself lives. Read it with:
  ```bash
  docker run --rm -v portainer_data:/d:ro alpine:3.20 cat /d/compose/1/docker-compose.yml
  ```
- **On the host** — once auto-created by Docker for the old *relative* bind
  mounts; it never held the compose file. Pi-hole's data has since moved to
  `/opt/homelab/network-core/` with absolute binds, and the empty host folder
  was removed on 2026-09-28.

## Volumes and data

| Container | Data lives at | Type |
|---|---|---|
| pihole | `/opt/homelab/network-core/etc-pihole` | bind, absolute (owned by `pi`, uid 1000 — the container's `pihole` user) |
| pihole | `/opt/homelab/network-core/etc-dnsmasq.d` | bind, absolute (root-owned, empty) |
| uptime-kuma | volume `network-core_uptime-kuma-data` | named volume |

Both need `sudo` or `docker` to read — see [backup.sh](../../../../scripts/backup.sh).

## Pi-hole

- **Versions:** Core v6.4.3 · Web v6.6 · FTL v6.7
- **Upstreams:** 8.8.8.8, 8.8.4.4, 1.1.1.1, 1.0.0.1
- **Admin UI:** https://pihole.lan — port 8081 is `127.0.0.1` only (HL-33)
- **Local DNS records:** the `.lan` names and the sites' split-horizon records,
  listed in [network.md](../../../../docs/network.md). In v6 they live in
  `dns.hosts` in `/etc/pihole/pihole.toml`, not `custom.list` — that file is
  generated and should not be edited.
- Config is **not** set via environment variables; it lives in the bind-mounted
  `pihole.toml`. Only `TZ` is passed in.

## Uptime Kuma

- **Image:** `louislam/uptime-kuma:1` · **UI:** https://kuma.lan — port 3001 is
  `127.0.0.1` only (HL-33)
- Monitors are recorded in [monitors.md](monitors.md) — its DB is not in git.
