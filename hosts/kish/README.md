# kish — Raspberry Pi 4 Model B Rev 1.5

The workhorse of the rack. Runs DNS, the WireGuard way in, Caddy for the `.lan`
admin UIs, monitoring, Portainer and the unifi controller.

- **Hostname:** `kish` since 2026-09-24 (was `EnkiduPi`) · reachable as
  `kish.lan` (Pi-hole) or `192.168.68.71` — use the IP when DNS itself is down.
  Kish was the first city of kingship in the Sumerian King List and Uruk's
  rival; the Pi sits outside cluster `uruk`. It was the cluster's deciding
  vote (QDevice) until enlil joined on 2026-10-12 (ADR 0014).
- **cloud-init is disabled** (`/etc/cloud/cloud-init.disabled`, 2026-09-24).
  Its first-boot setup was long done, and with `preserve_hostname: false` and
  `manage_etc_hosts: true` it would reset the hostname and `/etc/hosts` from
  its cached `user-data` at every boot. `/boot/firmware/user-data` also says
  `hostname: kish`. The rename was proven by a reboot.
- **OS:** Debian 13 (trixie), Raspberry Pi kernel (`rpt-rpi-v8`), **aarch64**
- **RAM:** 3.7 GB · **Swap:** 2 GB zram
- **Storage:** 119 GB **SD card** (`/dev/mmcblk0`) — see [HL-03](../../docs/backlog.md)
- **IP:** 192.168.68.71/22 via DHCP, **reserved**
- **Timezone:** Europe/Stockholm
- **Docker:** 29.7.2 · Compose v5.5.0

## What actually runs here

Three different deployment methods, which is worth knowing before you go looking
for a compose file that doesn't exist:

| What | How it's deployed | Where |
|---|---|---|
| Pi-hole + Uptime Kuma | Stack `network-core`, **deployed from this repo** | [stacks/network-core/](stacks/network-core/) |
| WireGuard (wg-easy) | Stack `wireguard`, **deployed from this repo** | [stacks/wireguard/](stacks/wireguard/) |
| Beszel hub | Stack `beszel`, **deployed from this repo** | [stacks/beszel/](stacks/beszel/) |
| Portainer | Local compose file on the Pi — see below | [portainer/](portainer/) |
| Caddy (`.lan` UIs) | Local compose file on the Pi, `~/stacks/caddy/` ([ADR 0012](../../docs/decisions/0012-caddy-on-kish-stays-outside-portainer.md)) | [stacks/caddy/](stacks/caddy/) |
| unifi Network Application | **Native apt package**, not Docker | [unifi/](unifi/) |

To change a git-managed stack: edit its compose file here, push, then
**Pull and redeploy** in Portainer. Polling is off, so pushing alone deploys
nothing.

**Portainer manages itself the old way, on purpose.** A stack cannot reliably
redeploy the container performing the deployment, so its compose file lives at
`~/stacks/portainer/` on the Pi and is applied with `docker compose up -d`.
Portainer therefore lists it as **Limited** — expected, not a fault. Keep it in
sync with [portainer/docker-compose.yml](portainer/docker-compose.yml) here.

## Ports

| Port | Service |
|---|---|
| 22 | SSH |
| 53 | Pi-hole DNS (tcp + udp) |
| 80, 443 (+ 443/udp for HTTP/3) | Caddy — the `.lan` admin UIs over HTTPS ([stacks/caddy/](stacks/caddy/)); host networking |
| 5353/udp | `avahi-daemon` (mDNS), Debian's default — the lab does not use `.local` names |
| 3001 | Uptime Kuma — `127.0.0.1` only, reach it at `https://kuma.lan` |
| 8081 | Pi-hole admin UI (container :80) — `127.0.0.1` only, `https://pihole.lan` |
| 9000 | Portainer UI — `127.0.0.1` only, `https://portainer.lan` |
| 8090 | Beszel hub — `127.0.0.1` only, `https://beszel.lan` |
| 51820/udp | WireGuard — **the only port forwarded from the internet to the Pi** |
| 51821 | wg-easy admin UI — `127.0.0.1` only, `https://wg.lan` |
| 6789, 8080, 8443, 8843, 8880, 28082; 3478, 10001, 5514 udp | unifi (native) — see [unifi/](unifi/) |
| 27117 | unifi's MongoDB — bound to 127.0.0.1 only |

The `127.0.0.1` binds are HL-33: only Caddy, on the same host, can reach those
UIs. From elsewhere, use the `.lan` name, or `ssh -L` when Caddy is down.

## Baseline hardening

Applied 2026-09-05 by [harden-kish.sh](../../scripts/harden-kish.sh),
which is idempotent and safe to re-run.

| What | Config | Note |
|---|---|---|
| `unattended-upgrades` | `/etc/apt/apt.conf.d/52homelab-unattended` | **never auto-reboots** — this box is the LAN's only resolver and the VPN endpoint |
| `fail2ban` | `/etc/fail2ban/jail.local` | **nftables** backend; LAN and VPN exempt |
| `log2ram` | `/etc/log2ram.conf`, `SIZE=192M` | `/var/log` in RAM; recent logs lost on unclean power loss |

`fail2ban` must use `banaction = nftables-multiport`. This kernel ships **no**
legacy iptables modules, so the default iptables banaction fails silently — it
looks configured while banning nobody. Verify it genuinely works:

```bash
sudo fail2ban-client set sshd banip 203.0.113.99
sudo nft list ruleset | grep 203.0.113.99      # must return a rule
sudo fail2ban-client set sshd unbanip 203.0.113.99
```

## Image cleanup

`alpine:3.20` looks unused between runs and is not: `backup.sh` reads container
data through it — see [scripts/README.md](../../scripts/README.md). Prune with
care: remove specific tags, never *Prune all*.

## Access

```bash
ssh pi@kish.lan     # key-only, passwords are refused
```

`sudo` requires a password. Note `timestamp_type=global` is set
(`/etc/sudoers.d/010_global-tty`), so once you authenticate `sudo` in any
session, *every* `pi` session on the box can use it until the timestamp expires.
Convenient, and worth knowing before you assume a script failed for lack of
privileges.

Portainer's stack files live inside its `portainer_data` volume, root-owned and
unreadable as `pi`; read them through a container (see
[network-core](stacks/network-core/README.md)). An empty `/data/compose/` on the
host was a leftover of the old relative binds and was removed on 2026-09-28.

### SSH hardening — and why the file is numbered 01

Config: `/etc/ssh/sshd_config.d/01-homelab.conf`

```
PasswordAuthentication no
PermitRootLogin no
KbdInteractiveAuthentication no
```

**sshd uses first-match-wins**, and `/etc/ssh/sshd_config.d/50-cloud-init.conf`
sets `PasswordAuthentication yes`. A drop-in numbered above 50 is read *after*
it and silently loses — the setting appears correct in the file while the running
config still allows passwords. Check what is actually in effect with:

```bash
sudo sshd -T | grep -i passwordauthentication
```

That file is also mode 600, so grepping it as `pi` fails with a permission error
that is easy to mistake for "not set".
