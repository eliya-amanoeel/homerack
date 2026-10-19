# 0002 — Port allocation on enkidupi

**Date:** 2026-09-04
**Status:** accepted (documenting what already existed). The ports have since
changed — Caddy on 80/443, the admin UIs on `127.0.0.1` (HL-11, HL-33); today's
list is in [hosts/kish](../../hosts/kish/README.md#ports).

## Context

`enkidupi` runs several services that want overlapping ports. Pi-hole's admin UI
wants :80, and the unifi Network Application claims :8080 (device inform), :8443
(UI), :8843/:8880 (guest portal) and :6789.

## Decision

Recorded from the running system rather than chosen fresh:

| Port | Service | Note |
|---|---|---|
| 53 | Pi-hole DNS | `systemd-resolved` is disabled so this is free |
| 3001 | Uptime Kuma | image default |
| 8081 | Pi-hole admin | mapped from container :80 to avoid the conflict |
| 9000 | Portainer | :9443 (HTTPS) and :8000 (edge) are unpublished |
| 6789, 8080, 8443, 8843, 8880, 28082 | unifi | native install, unchanged defaults |
| 27117 | unifi MongoDB | bound to 127.0.0.1 only |
| 51820/udp | WireGuard | added later — the only port forwarded from the internet |
| 51821 | wg-easy admin UI | LAN only, never forwarded |

The one deliberate move is Pi-hole's UI to **:8081**. unifi's defaults were left
alone because changing them risks the switch losing its inform URL.

*Updated 2026-09-04:* WireGuard was added after this ADR and its ports are
included above. See [ADR 0004](0004-remote-access-via-wireguard.md).

## Consequences

- Services are reached by `host:port`, which is fine for a handful and gets
  unwieldy beyond that. HL-11 (reverse proxy) makes this moot by giving each a
  hostname on :443.
- Nothing is listening on :80, so an ACME HTTP-01 challenge has a free port when
  HL-11 happens.
- Port 8080 must stay reachable from `switch-01` or it shows as disconnected.
