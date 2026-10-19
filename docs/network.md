# Network map

First verified 2026-09-04 by [discover-kish.sh](../scripts/discover-kish.sh);
re-checked against the live hosts 2026-09-28 and 2026-10-17. Not checkable from a host, and
checked by hand on 2026-10-13 (HL-102): the Deco's DHCP range and reservations,
the switch port map, and what the internet actually reaches.

## Addressing

Subnet is **192.168.68.0/22** (192.168.68.1 – 192.168.71.254), which is unusually
large for a home LAN and is the signature of a mesh system (eero and similar
default to it).

| Host | IP | MAC | Assignment | Notes |
|---|---|---|---|---|
| gateway | 192.168.68.1 | `xx:xx:xx:xx:xx:xx` | — | **TP-Link Deco** mesh — hence the /22 |
| `kish` | 192.168.68.71 | `xx:xx:xx:xx:xx:xx` (eth0) | DHCP **reserved** | ✅ reservation confirmed by owner |
| `USW-Lite-8-PoE` | 192.168.68.68 | `xx:xx:xx:xx:xx:xx` | DHCP **reserved** | ✅ unifi Lite 8 PoE |
| `anu` | 192.168.68.10 | `xx:xx:xx:xx:xx:xx` | **static, outside the DHCP pool** + reserved | ✅ Proxmox VE 9.2, reinstalled 2026-09-24 — was `pve1` — https://uruk.lan |
| `inanna` | 192.168.68.11 | `xx:xx:xx:xx:xx:xx` | **static, outside the DHCP pool** + reserved | ✅ Proxmox VE 9.2, reinstalled 2026-09-24 — was `pve2` from 2026-09-18, before that `prodesk` (`.57`, Windows) |
| `enlil` | 192.168.68.12 | `xx:xx:xx:xx:xx:xx` | **static, outside the DHCP pool** + reserved | ✅ Proxmox VE 9.2, installed 2026-10-12 (HL-104) |
| `nergal` | 192.168.68.56 | `xx:xx:xx:xx:xx:xx` | DHCP **reserved** | Synology DS420+ — DSM 5000/5001 (5000 redirects to HTTPS since 2026-10-01), Drive 6690; SMB and FTP off, own firewall blocks the Proxmox guests and the Hue bridge (since 2026-10-02, see [inventory](inventory.md#nergal--synology-ds420)) — was `EnkiduCloud` until 2026-09-25 |
| `hue-bridge` | 192.168.68.66 | `xx:xx:xx:xx:xx:xx` | DHCP **reserved** | ✅ serves nginx on 80/443 |
| Deco satellite | 192.168.71.249 | `xx:xx:xx:xx:xx:xx` | DHCP, not reserved | seen 2026-10-19, at the top of the pool |
| Deco satellite | 192.168.71.250 | `xx:xx:xx:xx:xx:xx` | DHCP, not reserved | as above |

**The Deco's DHCP pool is `192.168.68.50` – `192.168.71.250`** (the app's
**DHCP Server** setting, as Start and End IP; checked 2026-10-13). Addresses
below `.50` are never handed out, so **static IPs go below `.50`**:

| Range | For | Assigned |
|---|---|---|
| `.10`–`.19` | Proxmox hosts | `anu` `.10` ✅, `inanna` `.11` ✅, `enlil` `.12` ✅ |
| `.20`–`.49` | Proxmox guests ([ADR 0008](decisions/0008-site-hosting-pattern-on-proxmox.md)) | `edge` `.20` ✅, `amaeli` `.21` ✅, `site-a` `.22` ✅, `site-b` `.23` ✅, `postgres` `.24` ✅ — amaeli and site-a on `anu`, the rest on `inanna` (HL-77) |

A static IP inside the pool collides with whatever the Deco has already leased — `pve1` (now `anu`) was first put on `.58` and silently shared it
with another client (HL-70). The older hosts inside the pool are safe only
because they are DHCP reservations.

A reserved address still appears as `proto dhcp` on the client (or `Dhcp:
Enabled` on Windows), so a host's own config cannot tell you whether a
reservation exists — only the router can. Every host in the table above is now
reserved except the Deco satellites, and so is `edge` on `.20` (all eight confirmed in the Deco app
2026-10-13).

`kish` also has `wlan0` (`xx:xx:xx:xx:xx:xx`), currently **DOWN**.

## Services & ports

| Service | Host | Port | URL |
|---|---|---|---|
| SSH | `kish` | 22 | `ssh pi@kish.lan` |
| Pi-hole DNS | `kish` | 53 tcp+udp | — |
| Caddy (LAN) | `kish` | 80/443 (+443 udp) | the `.lan` admin UIs, with its own CA ([stacks/caddy](../hosts/kish/stacks/caddy/README.md)) |
| WireGuard | `kish` | 51820 udp | the only port forwarded to the Pi |
| wg-easy admin | `kish` | 51821 | **https://wg.lan only** — bound to 127.0.0.1 |
| Pi-hole admin | `kish` | 8081 | **https://pihole.lan only** — bound to 127.0.0.1 |
| Uptime Kuma | `kish` | 3001 | **https://kuma.lan only** — bound to 127.0.0.1 |
| Portainer | `kish` | 9000 | **https://portainer.lan only** — bound to 127.0.0.1 |
| Beszel hub | `kish` | 8090 | **https://beszel.lan only** — bound to 127.0.0.1 (HL-98) |
| Beszel agent | `anu`, `inanna`, `enlil` | 45876 | the hub on `kish` connects in over SSH (HL-98) |
| unifi UI | `kish` | 8443 | https://unifi.lan (or https://192.168.68.71:8443) |
| unifi inform | `kish` | 8080 | — (the switch talks to this) |
| unifi guest portal | `kish` | 8843 / 8880 | — |
| unifi speedtest | `kish` | 6789 | — |
| unifi MongoDB | `kish` | 27117 | 127.0.0.1 only |
| Proxmox web UI | `anu`, `inanna`, `enlil` | 8006 | **https://uruk.lan** via Caddy (shows all three nodes; prefers anu at `.10`, fails over to inanna, then enlil, by health check); direct https://192.168.68.10:8006, https://192.168.68.11:8006 and https://192.168.68.12:8006 stay open as fallbacks |
| Caddy (edge) | `edge` `.20` | 80/443 | public entry point for all sites; config in [hosts/edge/Caddyfile](../hosts/edge/Caddyfile) |
| GoAccess reports (edge) | `edge` `.20` | 8081 | **https://goaccess.lan only** — guest firewall and Caddy allow `kish` alone (HL-99) |
| Caddy (amaeli) | `amaeli` `.21` | 80 | serves amaeli.se to edge (reachable from the LAN too: no guest firewall, HL-86) |
| Caddy (site-a) | `site-a` `.22` | 80 | serves site-a.example to edge; `/send.ashx` → `site-a-form` on 127.0.0.1:5080 |
| Caddy (site-b) | `site-b` `.23` | 80 | serves app.site-b.example to edge → Kestrel on 127.0.0.1:5081 |
| PostgreSQL | `postgres` `.24` | 5432 | `site-b` database; only `192.168.68.23` may connect |

The `kish` ports were verified with `ss` on 2026-09-28; the full list, unifi's UDP ports included, is in [hosts/kish](../hosts/kish/README.md#ports).

## DNS

- **Resolver for the LAN:** `kish` (Pi-hole v6.4.3 / FTL v6.7)
- **Upstreams:** 8.8.8.8, 8.8.4.4, 1.1.1.1, 1.0.0.1 ✅ verified 2026-09-28
- **The Pi resolves through itself, then `1.1.1.1`** (HL-32) — set in
  NetworkManager (`ipv4.dns`, `ipv4.ignore-auto-dns yes`), so `apt` and image
  pulls keep working while Pi-hole is down. Why that is right for the Pi and
  wrong for clients is below.
- `systemd-resolved` is **inactive**, so port 53 is free for Pi-hole. Don't
  re-enable it.
- **Servers fall back to `1.1.1.1`** (HL-76, 2026-09-18): anu, inanna, enlil and
  every guest use `192.168.68.71` first, then `1.1.1.1`. Set once per node in
  **Node → System → DNS**; containers copy it at start and `edge` through
  cloud-init, so neither sets its own. Home devices deliberately have no
  fallback ([ADR 0005](decisions/0005-single-filtering-resolver.md)); servers
  need no ad-blocking, and without it a Pi outage broke SiteA's form and
  SiteB's mail.
- **Local DNS records:** in Pi-hole v6 these live in the `dns.hosts` array in
  `/etc/pihole/pihole.toml`. `custom.list` is **generated** from them — reading
  it and finding nothing does not mean none are configured.

  | Name | IP | Purpose |
  |---|---|---|
  | `app.site-b.example` | 192.168.68.20 | split-horizon: LAN clients go straight to `edge` (since 2026-09-17) |
  | `site-a.example` | 192.168.68.20 | as above |
  | `amaeli.se` | 192.168.68.20 | as above |
  | `kish.lan` | 192.168.68.71 | the Pi — was `enkidupi.lan` until 2026-09-24 |
  | `uruk.lan` | 192.168.68.71 | Proxmox UI (cluster `uruk`), via Caddy — was `pve.lan` until 2026-09-24 |
  | `pihole.lan` | 192.168.68.71 | Pi-hole admin, via Caddy |
  | `portainer.lan` | 192.168.68.71 | Portainer, via Caddy |
  | `kuma.lan` | 192.168.68.71 | Uptime Kuma, via Caddy |
  | `wg.lan` | 192.168.68.71 | wg-easy admin, via Caddy |
  | `unifi.lan` | 192.168.68.71 | unifi controller, via Caddy |
  | `beszel.lan` | 192.168.68.71 | Beszel hub, via Caddy (HL-98) |
  | `goaccess.lan` | 192.168.68.71 | website statistics, via Caddy → `edge` :8081 (HL-99) |
  | `nergal.lan` | 192.168.68.56 | the NAS — Drive and Photos use this name, at home or over WireGuard (since 2026-09-30) |
  | `edge.lan` | 192.168.68.20 | the edge VM — SSH as `debian` (HL-100) |
  | `anu.lan` | 192.168.68.10 | the Proxmox machine itself — SSH (was `pve1.lan` until 2026-09-24) |
  | `inanna.lan` | 192.168.68.11 | the second Proxmox machine — SSH (was `pve2.lan` until 2026-09-24) |
  | `enlil.lan` | 192.168.68.12 | the third Proxmox machine — SSH (since 2026-10-12) |
  | `hue.lan` | 192.168.68.66 | |
  | `gateway.lan` | 192.168.68.1 | |

  Read or write them with:
  ```bash
  docker exec pihole pihole-FTL --config dns.hosts
  docker exec pihole pihole-FTL --config dns.hosts '[ "ip name", ... ]'   # replaces the whole array
  docker exec pihole pihole reloaddns                                     # REQUIRED, see below
  ```

  **Writing the config is not enough.** `pihole-FTL --config` updates
  `pihole.toml` and reads back correctly while FTL carries on serving the old
  records — so a verification that only reads the config will pass while DNS is
  still wrong. Always `pihole reloaddns` and then confirm with `dig`.

  **`.lan`, not `.local`.** `.local` is reserved by RFC 6762 for mDNS; iOS,
  macOS and Android route `.local` lookups to multicast rather than to the
  configured DNS server, so a `.local` record here would be ignored by the very
  devices that need it — and multicast does not cross a VPN tunnel, which is why
  `kish.local` is unreachable over WireGuard while the IP works.

  `.local` on the LAN is answered by **avahi-daemon** on the Pi, not by Pi-hole.
  `.lan` was chosen to match `dns.domain.name = lan`, which Pi-hole was already
  configured with.
- **The Deco hands out one DNS server: the Pi. Secondary is deliberately empty**
  — and should stay that way. See below.
- **No secondary resolver, on purpose.** `1.1.1.1` was tried as a DHCP secondary
  and removed: clients do not honour resolver order, so queries landing on it
  silently skipped both ad-blocking and `.lan` resolution. See
  [ADR 0005](decisions/0005-single-filtering-resolver.md).
  **Consequence:** if `kish` is down, the LAN has no DNS. Set a device's DNS
  to `1.1.1.1` by hand to get online — see the
  [DNS outage runbook](runbooks/dns-outage.md). A second Pi-hole (HL-49) was
  dropped on 2026-09-25: this is accepted, and an outage is noticed by hand.

- **The Pi overrides this for itself (HL-32), and that is not a contradiction.**
  The Deco's setting governs *clients*; the Pi's own resolver list is configured
  locally with `ipv4.ignore-auto-dns yes`, so it takes effect on the Pi alone.
  The difference is the resolver software: **Linux tries nameservers strictly in
  order** and only falls through when the first does not answer, so Pi-hole stays
  authoritative. **Phones and laptops treat them as a pool** and pick whichever
  replies — which is what broke filtering when a secondary was handed out to
  clients. Same change, right on one, wrong on the other.

## Public DNS

Verified 2026-09-05 against `1.1.1.1`, last on 2026-10-17:

| Domain | Resolves to | Correct? |
|---|---|---|
| `app.site-b.example` | 203.0.113.10 | ✅ |
| `site-a.example` | 203.0.113.10 | ✅ |
| `www.site-a.example` | CNAME → `site-a.example` | ✅ since 2026-09-28 (was One.com's default `46.30.211.38`, HL-101); `edge` redirects it to `site-a.example` |
| `amaeli.se` | 203.0.113.10 | ✅ |
| `www.amaeli.se` | CNAME → `amaeli.se` | ✅ `edge` redirects it to `amaeli.se` (since 2026-09-28; was served as a second name) |

## Internet exposure

Verified from outside against 203.0.113.10 on 2026-09-04; 80, 443 and 6690
re-tested with `nc` on 2026-09-29, and 6690 closed on 2026-09-30. Full re-check
2026-10-13 from a phone hotspot (HL-102): 80 and 443 open, every closed port
below timed out, and WireGuard reached kish by IP and by `kish.lan`.

| Port | Reaches | Note |
|---|---|---|
| 80 | `edge` (`.20`) | HTTP → HTTPS redirect + Let's Encrypt HTTP-01 — must stay open |
| 443 | `edge` (`.20`) | the websites: amaeli (LXC 101), SiteA (LXC 102), SiteB (LXC 103 + 104) |
| 51820/udp | `kish` | WireGuard |
| ~~5000~~ | — | Synology DSM forward **removed** 2026-09-06 — see HL-62 |
| ~~6690~~ | — | Synology Drive forward **removed** 2026-09-30; from outside it now times out ([ADR 0013](decisions/0013-nas-reached-only-from-home-or-wireguard.md)) |

Closed and should stay closed: 3389 (RDP), 445 (SMB), 5985/5986 (WinRM), 5000
and 5001 (DSM admin), 6690 (Drive).

**UPnP is off** in the Deco (More → Advanced → NAT Forwarding → UPnP), since
2026-09-29, so no device can open a port on its own. The three forwards above
are manual entries under Port Forwarding and do not depend on it. **SIP ALG
is off** too (2026-09-29): no SIP phone in the house.

### The NAS is reached from home or over WireGuard only

Since 2026-09-30 ([ADR 0013](decisions/0013-nas-reached-only-from-home-or-wireguard.md)):
the Drive clients use `nergal.lan`, the 6690 forward is gone, QuickConnect is
off and the DDNS name `nergal.synology.me` is deleted. Away from home, Drive
syncs only with WireGuard on.

## Switch port map

From unifi → Devices → `USW-Lite-8-PoE` → Ports, read 2026-09-18; ports 4 and 6
re-read 2026-09-24 ✅; all eight re-read 2026-10-13 ✅ (HL-102), and again from the controller's
database 2026-10-17 ✅. Ports 1–4 are the PoE+ ports; PoE is **off** on all four
and nothing draws power from the switch.

| Port | PoE | Device | Link |
|---|---|---|---|
| 1 | off | `nergal` | GbE |
| 2 | off | `kish` | GbE |
| 3 | off | `inanna` | GbE |
| 4 | off | `enlil` | GbE — since 2026-10-12 ✅. PoE turned back off 2026-09-24 when the Comet KVM was returned (HL-78) |
| 5 | — | `anu` | GbE |
| 6 | — | `hue-bridge` | FE — the bridge's port is 10/100, so yellow is expected; moved here from port 4 on 2026-09-22 ✅ |
| 7 | — | *free* | |
| 8 | — | **uplink** → gateway (Deco, `xx:xx:xx:xx:xx:xx`) | GbE |

**Cable work, 2026-09-06.** Several hand-crimped patches were only linking at
100 Mbps (shown as **FE** in the unifi Ports view, versus **GbE**). The switch
uplink was among them, capping the entire 250/250 connection at ~91 Mbps for
every device.

After re-patching, throughput measured **27.3 MB/s ≈ 219 Mbps** — essentially the
full service. The Hue bridge stays at 100 Mbps because its own port is 10/100 —
confirmed with a fresh cable 2026-09-18 (HL-60).

Every cable in the rack is hand-crimped.

**Measuring real throughput** (from the Pi, so the path is Pi → switch → router
→ internet):

```bash
ssh pi@kish.lan 'curl -sL -o /dev/null --max-time 45 \
  -w "%{speed_download} B/s\n" http://ipv4.download.thinkbroadband.com/100MB.zip'
```

~11 MB/s means a 100 Mbps link somewhere in that path; ~30 MB/s is the full
250 Mbps service.

## VLANs

None, by decision ([ADR 0015](decisions/0015-no-vlans-while-the-deco-routes.md)):
the Deco stays the router and cannot route or filter between VLANs, so VLANs on
the switch would only cut devices off. IoT is isolated on the flat network
instead — Deco Device Isolation for Wi-Fi, host rules for the Hue bridge
(HL-108).
