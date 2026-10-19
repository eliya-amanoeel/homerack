# inanna — HP ProDesk 400 G2 **MINI**

**Proxmox VE 9.2**, reinstalled 2026-09-24 as `inanna`. Second of three
hypervisors (HL-08,
[ADR 0007](../../docs/decisions/0007-leave-windows-for-proxmox.md)), and the
machine that was `prodesk` — Windows Server 2022 and IIS until the sites moved
off it — then **`pve2`** from 2026-09-18 until 2026-09-24.

Built to match [anu](../anu/README.md) exactly: same platform, same disk
layout, same storage names. Where this file is silent, anu's applies. Both were
reinstalled on 2026-09-24 to take their Uruk names (HL-84, HL-87), with the
steps in [anu's README](../anu/README.md#reinstalling-a-node).

## Access

- **Web UI:** **https://uruk.lan** shows all three nodes. Direct fallback:
  https://192.168.68.11:8006 (self-signed).
- **Login:** `root`, realm **Linux PAM**, **TOTP 2FA** — inherited from the
  cluster on joining, so anu's password and authenticator entry apply here
- **SSH:** **key-only**, `ssh root@inanna.lan`, the `uruk` key from the password manager.
  `/etc/ssh/sshd_config.d/01-hardening.conf` is identical to anu's; confirmed
  with `sshd -T` on 2026-09-24, and the server offers only `publickey`
- **Firewall:** inherited from the Datacenter level on joining — same policy and
  `management` IPSet as anu. Confirmed `enabled/running`
- **Network:** static `192.168.68.11/22`, gateway `192.168.68.1`, DNS
  `192.168.68.71` then `1.1.1.1` (HL-76), outside the Deco's DHCP pool, and
  reserved there too. NIC pinned at install
- **Names:** `inanna.lan` → `.11` in Pi-hole (was `pve2.lan`, before that
  `prodesk.lan`)
- **Monitored** in Uptime Kuma as `inanna direct`
- **Metrics** in Beszel (HL-98): native `beszel-agent` 0.20.0, same setup as
  anu; the firewall rule for 45876 is the Datacenter one

## Hardware

| | |
|---|---|
| **CPU** | Intel i7-6700T — 4C/8T, 35 W |
| **RAM** | 16 GB — 2 × SK hynix `HMA41GS6AFR8N-TF` SODIMM |
| **Boot disk** | **SK hynix PC711 512 GB NVMe** (`HFS512GDE9X081N`) — the second of the pair, fitted 2026-09-18 |
| **Second disk** | Samsung PM871 128 GB 2.5" SATA (`MZ7LN128HCHP`) — was the Windows disk, wiped 2026-09-18; 46% worn, SMART passed (2026-09-28, again 2026-10-17). Attribute 9 (power-on hours) sits at its threshold, 75,918 h, so `smartctl` flags it `FAILING_NOW`: it counts age, not wear, and does not fail the health check |
| **NIC** | Realtek GbE, `xx:xx:xx:xx:xx:xx` |

**BIOS** (F10), set 2026-09-18 and **re-checked 2026-09-23** after a power cut
left both nodes off (HL-75): VTx and VTd **on**, Legacy Support **off** with
Secure Boot **on** (one combined option on HP firmware; Proxmox boots via
`shimx64.efi`), Network (PXE) Boot **off**, CD-ROM and USB Storage Boot **on**,
**After Power Loss → Power On** confirmed on screen. anu matches since
2026-09-24. Secure Boot, VTx and VTd re-checked from Linux 2026-10-13 (HL-102).

**Keyboard:** the Xtrfy K5 is ignored by the HP firmware and resets on every
key press. **FN + DEL** switches it to 6-key rollover, which works; press it
again afterwards to return to N-key. On its 65% layout F10 is FN + 0 and F9 is
FN + 9.

**CPU temperature:** `coretemp` loads at boot, as on all three nodes since
2026-10-14 — see [anu's Hardware](../anu/README.md#hardware).

## Storage

Same layout as anu: ext4/LVM, not ZFS, decided for both nodes on 2026-09-18
and confirmed at anu's reinstall on 2026-09-24 (HL-84). Replication (ZFS-only)
would turn a dead node into minutes of downtime rather than a restore, which the
sites here do not need.

| Storage | Where | Type | Content |
|---|---|---|---|
| `local` | NVMe, `root` LV (96 GB) | Directory | ISO images, container templates, import (`iso,vztmpl,import`) |
| `local-lvm` | NVMe, `data` thin pool (~348 GB) | LVM-thin | VM and container disks |
| `backup` | SATA SSD, ext4, `/mnt/pve/backup` (~117 GB) | Directory | **Backups only** |

`backup` is one cluster-wide storage entry with `nodes anu,inanna,enlil`; each node
mounts its own SATA disk there. Mounted by
`/etc/systemd/system/mnt-pve-backup.mount`
(`What=/dev/disk/by-uuid/1b376711-0811-4afc-892d-35fb951e2f06`), which survived
as a file only in the old install: rewritten by hand at the reinstall, as on anu.
The disk was **empty** at the reinstall — it had never held a backup, see
[the backup job](../anu/README.md#storage).

## Cluster

Cluster **`uruk`**, created on pve1 and joined by this machine as pve2 on
2026-09-18. On 2026-09-24 pve1 left and rejoined as `anu`, then pve2 left and
rejoined as `inanna`
([steps](../anu/README.md#reinstalling-a-node)). Until 2026-10-12, two
nodes plus a **QDevice on `kish`** — three votes, quorum two
([ADR 0009](../../docs/decisions/0009-cluster-quorum-via-qdevice-on-enkidupi.md)).
Since then, three nodes with **[`enlil`](../enlil/README.md)** and no QDevice —
still three votes, quorum two
([ADR 0014](../../docs/decisions/0014-three-nodes-no-qdevice.md)).

**Joining took two detours**, both worth knowing for any future node:

1. **The web UI join fails when root has TOTP** — `TFA-enabled login currently
   works only with a TTY`. Join from an SSH session instead, which prompts for
   the TOTP code: `pvecm add 192.168.68.10 --link0 192.168.68.11`. The same
   again for both joins on 2026-09-24.
2. **`hostname verification failed`** came from pve1's certificate still naming
   `.58`, its address before HL-70. Fixed on that node with
   `pvecm updatecerts --force && systemctl restart pveproxy`. Changing a node's
   IP needs that step too.

**Before the QDevice, a node that was down left the other without quorum**:
guests kept running, but configuration changes were blocked until the node
returned. Seen during this machine's first reboot as pve2, and the reason for
ADR 0009.

## Updates

No-subscription repository; `pve-enterprise` and `ceph` disabled. Reinstalled
from a 9.2.2 ISO and fully upgraded 2026-09-24; upgraded 2026-10-12 to
pve-manager 9.2.21, kernel `7.0.14-23-pve`, the same as anu and enlil (HL-105).
Keep the nodes on the same version.
`tmux` is installed, for long jobs in the web Shell.

## Templates

Every guest is cloned from a template, never built by hand
([ADR 0008](../../docs/decisions/0008-site-hosting-pattern-on-proxmox.md)).
Templates use IDs `9000+`; real guests start at `100`.

### `9000` — `tpl-debian13` (LXC), built 2026-09-17

Debian 13 standard, **unprivileged**, 1 core, 512 MB RAM + 512 MB swap, 8 GB on
`local-lvm`, DHCP on `vmbr0`.

- Fully upgraded; `unattended-upgrades` enabled (`20auto-upgrades` both `"1"`)
- `curl`, `ca-certificates`, `rsync`, `nano`, `htop`, `apt-listchanges`
- Timezone `Europe/Stockholm`
- Root login by the `uruk` key from the password manager (then `PVE`) only — same `01-hardening.conf` as the
  host
- **SSH runs as `ssh.service`, with `ssh.socket` disabled.** The Debian 13 image
  enables both. They share port 22, so `systemctl reload ssh` makes `sshd`
  re-bind, fail with `fatal: Cannot bind any address`, and die — logins keep
  working through the socket, which hides the problem. Fixed in the template;
  check with `systemctl is-enabled ssh.socket ssh.service` → `disabled`,
  `enabled`.
- Cleaned before conversion: apt cache, `/etc/machine-id` emptied (each clone
  generates its own on first boot), shell history, `known_hosts`

**Not reset in the template: SSH host keys.** Every clone starts with the same
host fingerprint and must regenerate its keys first:

```bash
rm -f /etc/ssh/ssh_host_* && dpkg-reconfigure openssh-server && systemctl restart ssh
```

### `9001` — `tpl-debian13-vm` (VM), built 2026-09-17

From Debian's official **cloud image** (`debian-13-genericcloud-amd64.qcow2`,
SHA512-verified), not an installer. 1 core, 1 GB RAM, 10 GB `local-lvm` disk
(`discard=on,ssd=1`), `virtio` NIC with `firewall=1`, `virtio-scsi-single`,
serial console, **QEMU guest agent enabled** (needed for consistent snapshot
backups, ADR 0008). Created on the pve1 (now anu) shell:

```bash
qm create 9001 --name tpl-debian13-vm --ostype l26 --memory 1024 --cores 1 \
  --net0 virtio,bridge=vmbr0,firewall=1 --scsihw virtio-scsi-single \
  --agent enabled=1 --serial0 socket --vga serial0
qm set 9001 --scsi0 local-lvm:0,import-from=/root/debian-13-genericcloud-amd64.qcow2,discard=on,ssd=1
qm disk resize 9001 scsi0 10G
qm set 9001 --ide2 local-lvm:cloudinit --boot order=scsi0
```

- **cloud-init** sets identity per clone: user `debian`, the `uruk` key from the password manager (then `PVE`),
  IP config. **Regenerate Image** after changing Cloud-Init settings.
- **Log in as `debian`, then `sudo -i`.** Root SSH is off entirely
  (`PermitRootLogin no`) — Debian's convention for cloud images, and different
  from the LXC containers, which use `root` with a key.
- `qemu-guest-agent`, `unattended-upgrades` (enabled), `apt-listchanges`, `curl`,
  `rsync`, `nano`, `htop`; timezone `Europe/Stockholm`.
- The cloud image has **no `ssh.socket` clash** — only `ssh.service` is enabled.
- Cleaned with `cloud-init clean --logs --machine-id`, plus apt cache and
  `authorized_keys`. **Clones therefore get new SSH host keys and machine-id
  automatically** — no manual regeneration, unlike LXC clones.

A clone's IP is set under **Cloud-Init → IP Config** (static `<IP>/22`, gateway
`192.168.68.1`), then **Regenerate Image**, before first start.

**Updating a template:** templates cannot be started. Clone it, change the
clone, clean it the same way, and convert the clone into the new template.

## Guests

Since 2026-09-24: `edge`, `site-b` and `postgres` — the app and its database
on one node, with the entry point beside its heaviest site (HL-77) — and both
templates. They spent the evening of 2026-09-24 on anu while this node was
reinstalled. Earlier that day all five
came here first to empty pve1 for its CPU and RAM swap (HL-08): the LXCs in
restart mode, a minute or two down each (postgres before site-b, so the app
reconnected on arrival); `edge` **online**, with Conntrack state kept, and no
site went down. Templates migrate offline; both live here. On 2026-10-12 `edge`
went to enlil and back, online, so that this node's reboot for HL-105 took
only app.site-b.example briefly down, not every site.

Set up with [the add-a-site runbook](../../docs/runbooks/add-a-site.md).

**Start order** (since 2026-09-28): `postgres` first (order 1, then a 14 s delay),
`site-b` second (order 2), so the app never starts before its database;
shutdown runs in reverse. `edge` has no order, so it starts after both.

**SSH is key-only on all three**, confirmed from the Mac on 2026-09-29: with
keys switched off, `edge` (`debian`), `site-b` and `postgres` (`root`) each
answered `Permission denied (publickey)`, offering no password.

| ID | Name | Type | IP | Runs | Since |
|---|---|---|---|---|---|
| `100` | `edge` | VM (from `9001`) | `192.168.68.20` | Caddy 2.11: public 80/443 entry point, Let's Encrypt; [Caddyfile](../edge/Caddyfile) | 2026-09-17 |
| `103` | `site-b` | LXC (from `9000`) | `192.168.68.23` | Caddy on :80 → Kestrel on `127.0.0.1:5081`; .NET 10 + Chromium (PDF); runner `site-b-lxc` | 2026-09-17 |
| `104` | `postgres` | LXC (from `9000`) | `192.168.68.24` | PostgreSQL 18.6 (PGDG), database `site-b`; nightly `pg_dump` 01:30 | 2026-09-17 |

**`100 edge`:** start at boot; 1 core, 1 GB. Login `debian` + `sudo`. Caddy
from its official repo, auto-updated via `51unattended-upgrades-caddy`.
**Guest firewall on**, input DROP: HTTP and HTTPS from anywhere, SSH from
`192.168.68.0/22` only, TCP 8081 from `kish` only (GoAccess reports, HL-99 —
see [goaccess](../edge/goaccess/README.md)). Deploy config from the repo:
`scp hosts/edge/Caddyfile debian@192.168.68.20:/tmp/ && ssh debian@192.168.68.20 'sudo -u caddy caddy validate --config /tmp/Caddyfile --adapter caddyfile && sudo install -m 644 /tmp/Caddyfile /etc/caddy/Caddyfile && sudo systemctl reload caddy'`.
Validate **as `caddy`**: as root it creates the access logs root-owned and the
reload then fails.

**`103 site-b`:** start at boot; 1 core, **2 GB** (Chromium), 12 GB disk.
ASP.NET Core 10 runtime (packages.microsoft.com) and Debian's `chromium` for PDF
export — the app never downloads a browser. Service `site-b` runs as user
`site-b`; all secrets in `/etc/site-b/env` (`root:site-b`, 640).
`runner` may run only `sudo systemctl restart site-b` and
`sudo /usr/local/sbin/site-b-migrate`, which runs the EF migration bundle as
the service user — so the runner never reads the secrets. Config files and setup
steps live in the site-b repo's `deploy/`; deploys come from its
**Build & Deploy (Proxmox)** workflow. Logs: `journalctl -u site-b`.
**PDF export works here, while it failed on IIS.** `avahi-daemon` came in
with `chromium` (same `apt install`, pulled in indirectly, 2026-09-17) and
listened on 5353/udp to the LAN;
purged 2026-10-13 (with `avahi-utils`, then `autoremove`), PDF export
re-tested fine. Only the client libraries Chromium's printing links against
remain. **Public since 2026-09-17**
via `edge`.

**`104 postgres`:** start at boot; 1 core, 512 MB (about 70 MB in use).
**PostgreSQL 18.6** from the PGDG repository — Debian 13 ships 17, and prodesk
ran 18.4, so a dump from there needed 18+. Auto-updated within 18 via
`53unattended-upgrades-pgdg`; only `postgresql-18` is installed, not the
`postgresql` meta package, so a new major version never arrives by itself. Listens on **all addresses** (`conf.d/10-listen.conf`:
`listen_addresses = '*'`); `pg_hba` allows just `hymnapp` → `site-b` from
`192.168.68.23/32` (scram). **Do not name `.24` there:** until 2026-09-18 it
did, and on every container start PostgreSQL could come up before the address
existed, log `could not bind`, and carry on listening on localhost only —
active, but unreachable for SiteB, so logins failed. Nightly
`pg_dump` at 01:30 into `/var/backups/site-b` (systemd timer from the
site-b repo), deleted after 14 days (`find -mtime +14`, so 15–16 on
disk), before the 02:30 Proxmox job. Local tools use the
socket with peer auth, so no password is stored anywhere.
