# Beszel

Host metrics with history and alerts: CPU, memory, disk, temperature,
S.M.A.R.T. Uptime Kuma says whether a service answers; Beszel says whether a
host is filling up or running hot (HL-98).

- **Image:** `henrygd/beszel:0.20` (minor-pinned; agents on the same minor)
- **UI:** https://beszel.lan — port 8090 is `127.0.0.1` only (HL-33)
- **Data:** Docker volume `beszel_beszel_data` — users, systems, alert rules,
  history, and the hub's SSH key. `backup.sh` reads it.
- **Agents:** kish (container in this stack, unix socket), anu, inanna and
  enlil (native systemd service, the hub connects in on TCP 45876)

**Limit:** the hub runs on kish, so it cannot alert about kish being down.
Kuma has the same blind spot.

## Setup

1. **Pi-hole record:** `beszel.lan → 192.168.68.71` (see
   [network.md](../../../../docs/network.md), Local DNS records).
2. **Caddy:** deploy the Caddyfile with the `beszel.lan` block — a local copy
   on the Pi, see [caddy/README.md](../caddy/README.md).
3. **Deploy the stack:** Portainer git stack named `beszel`, compose path
   `hosts/kish/stacks/beszel/docker-compose.yml`. The name matters: it sets
   the volume prefix `backup.sh` reads.
4. **First run:** open https://beszel.lan, create the admin account, put it in
   the password manager.
5. **Notifications:** Settings → Notifications, the same ntfy topic as Kuma
   (`ntfy://ntfy.sh/<topic>`), then Test.
6. **kish's agent:** Add System → Docker, name `kish`, Host/IP
   `/beszel_socket/beszel.sock`. The agent's `KEY` in the compose file is the
   public key that dialog shows; a new hub means a new key.
7. **The nodes** (anu, inanna, enlil): native agent, installed as root on each node. The
   script creates an unprivileged `beszel` user and a sandboxed systemd
   service; with these flags it asks nothing.

   ```bash
   # on each node
   curl -sL https://get.beszel.dev -o /tmp/install-agent.sh
   chmod +x /tmp/install-agent.sh
   /tmp/install-agent.sh -v 0.20.0 -p 45876 --auto-update false \
     -k "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILO87SCRiN704wT8nSoQo4UmfbaUeYi7R3oVdPKsp5oX"
   ```

   The Datacenter firewall rule `IN ACCEPT -source 192.168.68.71 -p tcp -dport
   45876` covers every node. Then Add System → Binary, Host/IP `.10`, `.11` or
   `.12`, port 45876, and set the alerts below on the new system.

## Alerts

Set on the **All Systems** tab of the bell icon, 2026-09-27, so they live in
`beszel_data`, not git. A system added later may need them applied again.

| Alert | Setting |
|---|---|
| Status | down for 5 min |
| Disk usage | 85% |
| Temperature | 75 °C for 10 min — a Pi 4 throttles near 80 °C |
| Memory usage | 90% for 10 min |
| CPU, I/O wait, steal | off — too spiky to be worth a notification |

## Upgrading

Hub, kish's agent and the node agents move together, one minor at a time: bump
both image tags here and Pull and redeploy, then rerun the install script on
each node with the new `-v`.
