# 0004 — Remote access via WireGuard, not per-service port forwards

**Date:** 2026-09-04
**Status:** accepted

## Context

The lab needed to be reachable from outside the house. The alternative shape —
forwarding a port per service (Portainer, Pi-hole, unifi, later IIS) — would put
four admin interfaces on the public internet, two of which (Portainer, which
mounts the Docker socket; unifi) are effectively root on their hosts.

An initial traceroute suggested CGNAT, since hop 2 sits in `100.73.0.0` — RFC
6598 space. That was a misread: Bahnhof uses that range for internal transit
links while still assigning a routable public address (203.0.113.10, confirmed
by `myip.opendns.com` and reverse DNS). Recorded here because the same trap will
come up again.

## Decision

One forwarded port: **UDP 51820** to `enkidupi`, running `wg-easy` (WireGuard
with a config-issuing UI) as its own compose stack, separate from `network-core`
so that touching DNS or monitoring cannot take down the way in.

Clients get `10.8.0.0/24`, chosen not to overlap the LAN's `192.168.68.0/22`.
DNS points at Pi-hole, so remote clients get ad blocking too.

Default is a split tunnel — only lab traffic crosses the VPN. Full tunnel is a
per-client choice for untrusted WiFi.

## Consequences

- WireGuard itself adds one UDP port that does not respond to unauthenticated
  packets at all.
- **It is not the only exposure.** TCP 80 and 443 are already forwarded and were
  found open from outside, serving the existing websites. WireGuard sits
  alongside them; it neither protects nor disturbs them. Documenting that
  exposure is HL-39.
- WireGuard grants access to the **whole LAN**, not only the lab. Narrower
  `WG_ALLOWED_IPS` is available if that ever matters.
- Remote DNS depends on Pi-hole. If it is down, connected clients resolve
  nothing — the same single point of failure as HL-01, now extended off-site.
- `WG_HOST` is baked into every issued client config, so a change of public IP
  invalidates all of them. Acceptable while the address is static; a DDNS name is
  the fix if it turns out not to be.
- The Pi is now the front door as well as the DNS server and the monitor. Its SD
  card (HL-03) got more important, not less.
