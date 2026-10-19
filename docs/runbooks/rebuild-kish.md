# Runbook: rebuild kish from scratch

**When:** SD card failure (the likely one), or a botched upgrade.
**Time:** ~1–2 hours plus downloads.
**Status:** ⚠️ never executed — see HL-07. Revised on paper 2026-09-25 against
the repo; steps marked **Test point** are the ones most likely to be wrong.

Every command block says where it runs: **Mac** (in this repo) or **Pi**.

## Before you start

1. **The newest `scripts/backup.sh` output**, in
   `~/homelab-backups/<date>/` on the Mac. Seven archives matter:

   | Archive | Without it |
   |---|---|
   | `wireguard.tar.gz` | every VPN client must be re-issued |
   | `caddy.tar.gz` | a new internal CA — every device re-trusts a new root |
   | `portainer.tar.gz` | admin account, stack definitions and the GitHub token re-entered by hand |
   | `pihole.tar.gz` | blocklists, `.lan` records and admin password re-entered |
   | `uptime-kuma.tar.gz` | monitors re-created from [monitors.md](../../hosts/kish/stacks/network-core/monitors.md), history gone |
   | `unifi-autobackup.tar.gz` | a fresh controller; `USW-Lite-8-PoE` shows unmanaged |
   | `beszel.tar.gz` | a new hub key: kish's compose file and the three node agents re-keyed; alert rules and history gone |

2. **DNS for the Mac.** The Pi *is* the LAN's resolver, so for the whole
   rebuild the Mac has none. Set its DNS to `1.1.1.1` — see
   [dns-outage.md](dns-outage.md). Do the same on the gateway's DHCP if the
   household needs internet meanwhile.

## 1. Flash the OS

Raspberry Pi Imager → **Raspberry Pi OS Lite (64-bit)**. In the imager settings:
hostname `kish`, enable SSH with your public key, time zone `Europe/Stockholm`.
Set a real password — not the default (HL-28).

## 2. First boot

By IP: nothing serves `kish.lan` yet. The DHCP reservation hands the Pi `.71`
by MAC address, so a new card in the same Pi gets the same address. Only new
hardware needs the reservation on the gateway (192.168.68.1) updated — see
[network.md](../network.md).

The Pi's host key is new, so the Mac will refuse to connect until the old one
is forgotten.

**Mac:**
```bash
ssh-keygen -R 192.168.68.71 && ssh-keygen -R kish.lan
ssh pi@192.168.68.71
```

Give the Pi its own DNS order first: itself, then `1.1.1.1` (HL-32). Pi-hole is
not running yet, so until step 7 the fallback does all the work; afterwards it
keeps `apt` and image pulls working whenever Pi-hole is down.

**Pi:**
```bash
nmcli -t -f NAME,DEVICE con show --active      # the eth0 connection's name
sudo nmcli con mod "Wired connection 1" ipv4.dns "192.168.68.71 1.1.1.1" ipv4.ignore-auto-dns yes
sudo nmcli dev reapply eth0
cat /etc/resolv.conf                           # nameserver 192.168.68.71, then 1.1.1.1
sudo apt update && sudo apt full-upgrade -y
sudo touch /etc/cloud/cloud-init.disabled   # first-boot setup is done
```

Disabling cloud-init stops it resetting the hostname and `/etc/hosts` from
`user-data` at every boot (see [hosts/kish](../../hosts/kish/README.md)).

**Test point:** the connection name. `Wired connection 1` is what the current
install uses; use whatever the first command prints.

## 2a. Lock down SSH

Confirm key login works first — the imager put your key there — or you will
lock yourself out.

**Pi:**
```bash
printf 'PasswordAuthentication no\nPermitRootLogin no\nKbdInteractiveAuthentication no\n' \
  | sudo tee /etc/ssh/sshd_config.d/01-homelab.conf
sudo sshd -t && sudo systemctl restart ssh
sudo sshd -T | grep -i passwordauthentication      # must say: no
```

**Numbered 01, not 99.** `50-cloud-init.conf` sets `PasswordAuthentication yes`
and sshd takes the first match, so a higher number loses silently. Verify with
`sshd -T` rather than trusting the file.

## 2b. Baseline hardening

unattended-upgrades, fail2ban (nftables backend) and log2ram. The script is
idempotent.

**Mac:**
```bash
ssh -t pi@192.168.68.71 'sudo bash -s' < scripts/harden-kish.sh
```

Then prove fail2ban actually bans — the check is in
[hosts/kish](../../hosts/kish/README.md#baseline-hardening).

## 3. Free port 53

Raspberry Pi OS may run `systemd-resolved`, which holds :53 and makes Pi-hole
fail to bind.

**Pi:**
```bash
systemctl is-active systemd-resolved      # want: inactive
sudo systemctl disable --now systemd-resolved   # only if it is active
```

## 4. Docker, and the backups onto the Pi

**Pi:**
```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker pi
mkdir -p ~/stacks/portainer ~/stacks/caddy ~/stacks/network-core-fallback
exit        # log back in so the docker group applies
```

**Mac** — the compose files, and the archives (they hold private keys; step 11
deletes them):
```bash
B=~/homelab-backups/<date>
scp hosts/kish/portainer/docker-compose.yml pi@192.168.68.71:stacks/portainer/
scp hosts/kish/stacks/caddy/{docker-compose.yml,Caddyfile} pi@192.168.68.71:stacks/caddy/
scp hosts/kish/stacks/network-core/docker-compose.yml pi@192.168.68.71:stacks/network-core-fallback/
scp $B/{wireguard,caddy,portainer,pihole,uptime-kuma,beszel}.tar.gz pi@192.168.68.71:
```

`~/stacks/network-core-fallback/` is the copy [dns-outage.md](dns-outage.md)
relies on; it lived on the old card.

**Restoring into a volume** is the same everywhere below: wipe what a fresh
container created, unpack the archive, start again.

**Pi:**
```bash
restore() {  # restore <volume> <archive>
  docker run --rm -v "$1":/d -v "$HOME":/b alpine:3.20 \
    sh -c "find /d -mindepth 1 -delete && tar -xzf /b/$2 -C /d"
}
```

The function lasts only for that SSH session; define it again after
reconnecting.

## 5. Portainer — standalone, restored before first start

`portainer_data` is declared external, so it is created by hand — which means
it can be filled before Portainer ever runs, and Portainer starts with its admin
account, its stack definitions and the GitHub token.

**Pi:**
```bash
docker volume create portainer_data
restore portainer_data portainer.tar.gz
cd ~/stacks/portainer && docker compose up -d
curl -o /dev/null -w '%{http_code}\n' http://localhost:9000/api/users/admin/check
# 204 = restored.  404 = fresh install; the restore did not land.
```

Portainer listens on `127.0.0.1` only (HL-33), and `portainer.lan` needs both
Caddy and Pi-hole. Until step 7, reach it through a tunnel:

**Mac:**
```bash
ssh -N -L 9000:127.0.0.1:9000 pi@192.168.68.71     # then http://localhost:9000
```

## 6. Caddy — a local compose project, not Portainer

Deployed from `~/stacks/caddy/` on purpose ([ADR 0012](../decisions/0012-caddy-on-kish-stays-outside-portainer.md)). The project name must stay
`caddy`: it sets the volume prefix, and anything else makes a fresh, empty
`caddy_data` — a new CA.

**Pi:**
```bash
cd ~/stacks/caddy && docker compose up -d
docker compose stop
restore caddy_caddy_data caddy.tar.gz
docker compose start
```

The first start generates a throwaway CA; the restore replaces it with the
original root, which every device already trusts.

## 7. network-core — Pi-hole + Uptime Kuma

Pi-hole's data goes in place **before** the stack starts. The binds are
absolute (`/opt/homelab/network-core/`), so Pi-hole comes up with its config
instead of an empty one.

**Pi:**
```bash
sudo mkdir -p /opt/homelab/network-core/etc-pihole /opt/homelab/network-core/etc-dnsmasq.d
sudo tar -xzf ~/pihole.tar.gz -C /opt/homelab/network-core/etc-pihole
```

Then in Portainer: **Stacks → network-core → Pull and redeploy**.

**Test point:** whether a restored stack definition deploys onto a Docker host
that has never run it. If it fails, delete the stack in Portainer and add it
again: **Add stack → Repository**, name `network-core`, repository
`https://github.com/eliya-amanoeel/homelab`, compose path
`hosts/kish/stacks/network-core/docker-compose.yml`. The name matters — it
sets the Kuma volume's prefix.

Restore Kuma into the volume the stack just created:

**Pi:**
```bash
docker stop uptime-kuma
restore network-core_uptime-kuma-data uptime-kuma.tar.gz
docker start uptime-kuma
```

Pi-hole's admin password is in the restored `pihole.toml`. Only if the restore
is missing: `docker exec -it pihole pihole setpassword`.

Pi-hole answers now, and step 2's order already puts it first — nothing to
undo.

## 8. WireGuard — the other git stack

In Portainer: **Stacks → wireguard → Pull and redeploy** (same fallback as
step 7, name `wireguard`, path `hosts/kish/stacks/wireguard/docker-compose.yml`).
Then the keys:

**Pi:**
```bash
docker stop wg-easy
restore wireguard_etc_wireguard wireguard.tar.gz
docker start wg-easy
docker inspect -f '{{.State.Health.Status}}' wg-easy    # healthy, after ~30 s
```

The port forward (UDP 51820 → `.71`) is on the gateway and survives.

## 8b. Beszel — the third git stack

In Portainer: add git stack `beszel`, path
`hosts/kish/stacks/beszel/docker-compose.yml`. Then the data, which holds the
hub's key — the one the agents in the compose file and on anu, inanna and enlil trust:

**Pi:**
```bash
docker stop beszel beszel-agent
restore beszel_beszel_data beszel.tar.gz
docker start beszel beszel-agent
docker inspect -f '{{.State.Health.Status}}' beszel    # healthy
```

The node agents and the firewall rule live on anu, inanna and enlil and survive.

## 9. unifi — native, not Docker

**Pi:**
```bash
# Ubiquiti's apt repo + its MongoDB dependency; follow current unifi docs, the
# repo URLs and the required Mongo version change between releases.
sudo systemctl enable --now unifi
sudo usermod -aG unifi pi       # so backup.sh can read the autobackups
```

The controller must be the **same or a newer** version than the backup (it was
10.6 — see [hosts/kish/unifi](../../hosts/kish/unifi/README.md)).

Unpack the autobackups on the Mac (`tar -xzf unifi-autobackup.tar.gz`) and take
the newest `autobackup/*.unf`. Browse to https://192.168.68.71:8443 and
**restore from it** during the setup wizard. Restoring is what re-adopts
`USW-Lite-8-PoE` — a fresh controller will show it as unmanaged.

## 10. QDevice — none since 2026-10-12

Nothing to do. The cluster has three nodes and no QDevice
([ADR 0014](../decisions/0014-three-nodes-no-qdevice.md)), so the Pi no longer
runs `corosync-qnetd`. Should the cluster drop back to two nodes, ADR 0014 says
where the old setup steps are.

## 11. Verify, then clean up

The admin UIs are bound to localhost, so they are checked through Caddy — which
also proves the CA came back.

**Mac:**
```bash
dig @192.168.68.71 example.com +short          # resolves
dig @192.168.68.71 doubleclick.net +short      # 0.0.0.0 → blocking works
dig @192.168.68.71 portainer.lan +short        # 192.168.68.71 → .lan records restored
```

- `https://pihole.lan`, `portainer.lan`, `kuma.lan`, `wg.lan`, `unifi.lan`,
  `beszel.lan`, `goaccess.lan` and `uruk.lan` open on the Mac **without a certificate warning**. A warning means
  Caddy's CA was not restored.
- Kuma's monitors go green; `USW-Lite-8-PoE` appears in unifi; kish, anu,
  inanna and enlil are up in Beszel.
- A WireGuard handshake from the phone **on cellular** shows in wg-easy.
- `./scripts/backup.sh` on the Mac finishes with **All good** — that proves
  every volume name and the unifi permission at once.

Then delete the archives from the Pi — they hold the VPN and CA private keys.

**Pi:**
```bash
rm ~/{wireguard,caddy,portainer,pihole,uptime-kuma,beszel}.tar.gz
```

## 12. Point DNS back

Undo whatever *Before you start* changed: the Mac's DNS, and the gateway's DHCP
if it was touched.

## Not restored by this runbook

- `/etc/sudoers.d/010_global-tty` (`timestamp_type=global`) — a convenience;
  see [hosts/kish](../../hosts/kish/README.md#access).
