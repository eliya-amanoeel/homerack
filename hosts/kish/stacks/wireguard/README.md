# WireGuard (wg-easy)

Remote access to the lab. It is the **only** service on the Pi reachable from
the internet, and the admin UIs stay behind it — that is the point of the design:
one forwarded UDP port instead of one per service. (The websites on `edge` are
public too; the NAS's Drive port was until 2026-09-30, and is now reached over
this tunnel — see
[network.md](../../../../docs/network.md#internet-exposure).)

- **Image:** `ghcr.io/wg-easy/wg-easy:15` (pinned)
- **Admin UI:** https://wg.lan — port 51821 is `127.0.0.1` only (HL-33); **never forward it**
- **Listens:** UDP 51820, forwarded from the router
- **Client subnet:** 10.8.0.0/24 · **Public address:** 203.0.113.10
- **Config storage:** Docker volume `wireguard_etc_wireguard`

## Setup

v15 takes no configuration from the environment: there is no `.env`. The admin
account, DNS and allowed IPs are set in the web UI on first run (see the
comment at the top of [docker-compose.yml](docker-compose.yml)).

1. **Deploy the stack** — a Portainer git stack named `wireguard`, compose path
   `hosts/kish/stacks/wireguard/docker-compose.yml`. The name matters: it sets
   the volume's prefix (`wireguard_etc_wireguard`), which `backup.sh` reads.
2. **First run:** open https://wg.lan and create the admin account. Put it in
   the password manager.
3. **Forward the port** on the router (192.168.68.1):
   `UDP 51820 → 192.168.68.71:51820`. Only UDP, only 51820.
4. **Add a client** in the UI, scan the QR with the WireGuard app.

A rebuild restores the volume instead — see
[rebuild-kish.md](../../../../docs/runbooks/rebuild-kish.md), step 8.

## Verifying it actually works

Test from **cellular data with WiFi off** — not from the LAN. Many routers do not
hairpin, so connecting to your own public IP from inside can fail even when the
setup is correct, and can equally appear to succeed for the wrong reason.

```
handshake shows a recent timestamp in the wg-easy UI = working
```

## Names over the VPN

Use the IP or a `.lan` name served by Pi-hole (see
[network.md](../../../../docs/network.md)); the latter needs the client's DNS
set to `192.168.68.71`. mDNS `.local` names are multicast and never cross the
tunnel — and the lab does not use them anyway.

## Split tunnel vs full tunnel

Set allowed IPs to `192.168.68.0/22, 10.8.0.0/24` so only lab traffic crosses the
VPN and normal browsing uses the local connection. This is faster on
mobile and does not route your personal traffic through your flat.

Set it to `0.0.0.0/0` for a full tunnel — everything through home, which is what
you want on untrusted WiFi, and which makes Pi-hole block ads everywhere. You can
also issue both and pick per client.

DNS points at Pi-hole (`192.168.68.71`), so **if Pi-hole is down, connected
clients get no DNS.** Related: HL-32.

## Security notes

- Port 51821 (the UI) must never be forwarded. WireGuard's own port is safe to
  expose — it does not answer unauthenticated packets at all, which is why a port
  scan of 51820 looks closed.
- Each client gets its own key. Revoke a lost phone in the UI; no need to reissue
  the others.
- Every private key lives in the `wireguard_etc_wireguard` Docker volume. It is
  not in git; `scripts/backup.sh` collects it as `wireguard.tar.gz` (HL-38).
- WireGuard gives access to the **whole LAN**, not just the lab. That is what
  the allowed IPs setting in the web UI grants. Narrow it if you only ever need
  the Pi.

## If the public IP ever changes

Bahnhof has assigned a static address, so this should not happen — but if it
does, every existing client config breaks, since the host set in the web UI is
baked into each one at creation. A DDNS hostname there avoids that; worth doing
only if the address turns out not to be stable.
