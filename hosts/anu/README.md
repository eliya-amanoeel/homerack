# anu — HP ProDesk 400 G2 **MINI**

**Proxmox VE 9.2**, reinstalled 2026-09-24 as `anu`. First of three hypervisors
(HL-08, [ADR 0007](../../docs/decisions/0007-leave-windows-for-proxmox.md)).

Formerly `prodesk-spare`, then **`pve1`** from its first install on 2026-09-16
until 2026-09-24. A Proxmox node name is baked into `/etc/pve/nodes/` and its
certificates, so renaming means removing the node from the cluster and
reinstalling — done on 2026-09-24, see
[Reinstalling a node](#reinstalling-a-node). `anu` and `inanna` are the gods of
Uruk's two temple districts, matching the cluster name; pve2 was reinstalled
as **[`inanna`](../inanna/README.md)** the same evening (HL-87). `prodesk` had
become pve2 on 2026-09-18; the two form cluster **`uruk`**, created on this
machine as pve1. **[`enlil`](../enlil/README.md)** joined as the third node on
2026-10-12 (HL-104).

## Access

- **Web UI:** **https://uruk.lan** — through Caddy on the Pi, trusted certificate.
  Caddy prefers this node (by IP) and fails over to inanna, then enlil, while
  it is down.
  Direct fallback if the Pi is down: https://192.168.68.10:8006 (self-signed).
- **Login:** `root`, realm **Linux PAM**, **TOTP 2FA** (issuer `uruk`) plus
  **recovery keys**, both re-created 2026-09-25; the recovery keys are stored
  offline, deliberately not in the password manager. 2FA is cluster-wide
  (`/etc/pve/priv/tfa.cfg`), so a fresh install gets it back on joining.
  **Add a new TOTP before deleting the old one**, and test it in a private
  window — Proxmox allows several per user. Locked out of the UI anyway? SSH
  with the key still works.
- **UI frozen right after the 2FA code** (fine after a refresh, fine in a
  private window): the password manager's autofill. `uruk.lan` is in the extension's
  **Settings → Autofill → Blocked domains** since 2026-09-27; add the direct
  `:8006` addresses too if logging in there from a normal window.
- **SSH:** **key-only**, `ssh root@anu.lan`. The key is `uruk` in
  the password manager (named `PVE` until 2026-09-24), served by its SSH agent, and is the
  same for every node. It sits in the cluster-wide
  `/etc/pve/priv/authorized_keys` with the comment `uruk`, so a node that joins
  can use it immediately. Copies made earlier — templates and guests — still
  carry the comment `PVE`; only the label differs.
  Passwords are off via `/etc/ssh/sshd_config.d/01-hardening.conf`
  (`PasswordAuthentication no`, `KbdInteractiveAuthentication no`,
  `PermitRootLogin prohibit-password`). Root SSH must stay allowed — cluster
  nodes use it. Confirm with `sshd -T`, never by reading the file.
- **Firewall:** on at Datacenter level since 2026-09-16 — input policy **DROP**,
  output ACCEPT. IPSet `management` = `192.168.68.0/22`; Proxmox automatically
  allows the UI (8006), SSH (22) and SPICE (3128) from it. One rule of ours:
  TCP 45876 from `192.168.68.71` only, the Beszel hub (HL-98). Everything
  else is blocked, e.g. `rpcbind` on 111. There are no VLANs ([ADR 0015](../../docs/decisions/0015-no-vlans-while-the-deco-routes.md)); leaving the Hue bridge out of `management` is part of HL-108.
  **Locked out?** Log in at the physical console and run `pve-firewall stop`.
- **Network:** static `192.168.68.10/22`, gateway `192.168.68.1`, DNS
  `192.168.68.71` then `1.1.1.1` (HL-76; the installer sets only the first, add
  the second in **anu → System → DNS** before any guest starts here). **Outside the Deco's DHCP pool** (`192.168.68.50`–`192.168.71.250`), so DHCP can
  never hand it out. Also reserved in the Deco as a belt-and-braces measure.
- **Names:** `anu.lan` → `.10` (the machine, for SSH); `uruk.lan` → `.71`
  (Caddy, for the UI), which shows all three nodes.
- **Monitored** in Uptime Kuma: `anu direct` and `uruk.lan (Caddy)`, both with
  Ignore TLS on — Kuma's container does not trust Caddy's CA.
  Since 2026-09-24 `uruk.lan` (then `pve.lan`) fails over to inanna, and
  since 2026-10-12 then to enlil, so its monitor tracks the cluster UI, not
  this node — `anu direct` is the one for anu itself.
- **Metrics** in Beszel (HL-98): native `beszel-agent` 0.20.0 as a systemd
  service, auto-update off, listening on 45876. A Datacenter firewall rule
  lets only the hub (`192.168.68.71`) reach that port.
- **Moving the IP** means changing both `/etc/network/interfaces` (vmbr0) and
  `/etc/hosts`, then `ifreload -a`. Proxmox needs its own name to resolve to its
  own address. **Then regenerate the certificate** with
  `pvecm updatecerts --force && systemctl restart pveproxy`: it names the IP, and
  the move to `.10` left it naming `.58` until 2026-09-18, which broke pve2's
  cluster join.

## Hardware

Same platform as `prodesk` — SODIMM memory on a socketed LGA1151 board, so RAM
and CPU are interchangeable between them.

| | |
|---|---|
| **CPU** | Intel **i7-6700T** — 4C/8T, 35 W, 6th-gen Skylake — fitted 2026-09-24, replacing an i5-6500T (4C/4T) |
| **RAM** | **16 GB** — 2 × SK hynix `HMA41GS6AFR8N-TF`, 2Rx8 PC4-2133P-SE0-11 SODIMM — second stick fitted 2026-09-24 |
| **Boot disk** | **SK hynix PC711 512 GB NVMe** (`HFS512GDE9X081N`), `nvme0n1` — fitted 2026-09-16 |
| **Second disk** | **Samsung PM871 256 GB 2.5" SATA** (`MZ7LN256HMJP`), `sda` — 18% wearout, SMART passed |
| **NIC** | Realtek RTL8168h, `xx:xx:xx:xx:xx:xx`, interface `nic0` (pinned) |

Now identical to inanna in CPU and RAM. Confirmed after the swap: `nproc` 8, 15 GB
usable, CPU package **32 °C at idle** with the new paste.

**BIOS** set 2026-09-24 during the swap to match pve2, now inanna (HL-75): VTx and VTd on,
Legacy Support off with Secure Boot on, PXE boot off, **After Power Loss →
Power On**. Secure Boot, VTx and VTd re-checked from Linux 2026-10-13 (HL-102).

Two SK hynix PC711s were bought; the second is inanna's boot disk.

**The M.2 slot links at PCIe Gen2 x4** (5 GT/s, ~2 GB/s), not the Gen3 the
drive supports — the kernel logs `limited by 5.0 GT/s PCIe x4 link`. A platform
limit, not a fault, and still far faster than SATA.

**If the CPU or RAM is ever changed again** (lessons from the 2026-09-24 swap):

- **Thermal paste is required.** A tray CPU ships bare, and removing the
  existing HP cooler destroys the thermal interface already on it. Clean both
  surfaces with isopropyl first.
- **Keep to the `T` variant.** This chassis is cooled and powered for 35 W. A
  65 W i7-6700 fits the same socket and then throttles. Confirm afterwards in
  anu → Summary: 8 CPUs.
- **Do not buy faster RAM.** Skylake caps at DDR4-2133.

**CPU temperature:** `coretemp` loads at boot from
`/etc/modules-load.d/coretemp.conf`, added 2026-10-14 on all three nodes.
Proxmox did not load it, so until then the only temperatures were the NVMe and
the chipset (`pch_skylake`), and Beszel's Temp value was one of those. Beszel
picked up the CPU sensors without an agent restart. Its card still shows the
hottest sensor, which is usually the NVMe, not the CPU.

## Storage

The installer used **ext4/LVM, not ZFS** — both installs. On a single disk ZFS
spends RAM on checksums it cannot self-heal from, and LVM-thin already gives
snapshots. ZFS was reconsidered at the 2026-09-24 reinstall, because it is what
replication and automatic failover need, and turned down: a restore from backup
is acceptable downtime for these sites (HL-84).

| Storage | Where | Type | Content |
|---|---|---|---|
| `local` | NVMe, `root` LV (~96 GB), `/var/lib/vz` | Directory | ISO images, container templates, import (`iso,vztmpl,import`) — **not backups** |
| `local-lvm` | NVMe, `data` thin pool (~348 GB) | LVM-thin | VM and container disks |
| `backup` | SATA SSD, ext4, `/mnt/pve/backup` (~234 GB) | Directory | **Backups only** — one entry for all three nodes (`nodes anu,inanna,enlil`), each mounting its own disk |

Installer defaults otherwise: 8 GB swap, 16 GB left free in the `pve` volume
group for LVM snapshots.

**The `backup` disk survived the reinstall with its backups.** Only the NVMe was
the install target. The mount is `/etc/systemd/system/mnt-pve-backup.mount`
(`What=/dev/disk/by-uuid/852ab56f-ce4f-4a99-892e-786a2217510f`, ext4, enabled),
written by hand as a copy of pve2's (now inanna) with this disk's UUID. **Do not recreate it
with Disks → Directory** — that formats the disk.

**Backup job** (Datacenter → Backup), since 2026-09-17: **all guests on all
nodes** (Node: `-- All --`), daily **02:30**, snapshot mode, ZSTD, retention 7 daily / 4 weekly / 3 monthly, note
`{{guestname}}`. Templates are included. First restore tested the same day —
procedure in [add-a-site.md](../../docs/runbooks/add-a-site.md#8-backups).

**Until 2026-09-24 the job was tied to `node pve1`** and scheduled `2,22:30`
(twice a day, contrary to these docs). pve2 never backed anything up — harmless
while it had no guests at night — and after pve1 was removed the job would have
run nowhere, silently. Found by searching `/etc/pve` for old node names, and
fixed: no `node` line, `schedule 02:30`. **After any node rename, check
`grep -rl <oldname> /etc/pve`.**

**Backups are restricted to `backup`** so a job cannot land on the same disk as
the guests it protects. It still dies with the machine; a second copy on the NAS was
considered and declined (HL-74).

**`local-lvm` is thin-provisioned** — guests can be promised more than the pool
holds, and a full pool freezes every guest on it. Watch its usage.

## Guests

`amaeli` and `site-a` (HL-77). The rest, and both templates, live on
[inanna](../inanna/README.md).

Set up with [the add-a-site runbook](../../docs/runbooks/add-a-site.md).

| ID | Name | Type | IP | Runs | Since |
|---|---|---|---|---|---|
| `102` | `site-a` | LXC (from `9000`) | `192.168.68.22` | Caddy on :80 serving `/var/www/site-a`; `site-a-form` (.NET 10, `127.0.0.1:5080`) replacing `send.ashx`; runner `site-a-lxc` | 2026-09-17 |
| `101` | `amaeli` | LXC (from `9000`) | `192.168.68.21` | Caddy 2.11 on :80 serving `/var/www/amaeli`; runner `amaeli-lxc` | 2026-09-17 |

**SSH is key-only on both**, confirmed from the Mac on 2026-09-29: with keys
switched off, `amaeli` and `site-a` (`root`) each answered `Permission denied
(publickey)`, offering no password.

**`102 site-a`:** start at boot; 1 core, 512 MB. Same base as amaeli, plus the
ASP.NET Core 10 runtime from Microsoft's repository (auto-updated via
`52unattended-upgrades-microsoft`) and the `site-a-form` systemd service, run as
user `site-a-form`. The SMTP password is only in `/etc/site-a-form/env`
(`root:site-a-form`, 640). `runner` may run exactly
`sudo systemctl restart site-a-form`. Setup and config files live in the site-a
repo's `deploy/`; deploys come from its **Build & Deploy (Proxmox)** workflow.
Errors: `journalctl -u site-a-form`. **Public since 2026-09-17** via `edge`.

**`101 amaeli`:** start at boot; 1 core, 512 MB. Caddy from its official repo,
auto-updated via `51unattended-upgrades-caddy`. Runner runs as user `runner`,
which owns `/var/www/amaeli` and nothing else. Deploys from the amaeli repo's
`Build & Deploy` workflow (build on `ubuntu-latest`, `rsync` here). Its Caddyfile
is in the amaeli repo's `deploy/`. **Public since 2026-09-17** via `edge`.

## Updates

On the **no-subscription** repository; the enterprise `pve` and `ceph`
repositories are disabled (**anu → Updates → Repositories**). Reinstalled from
a 9.2.2 ISO and fully upgraded 2026-09-24; upgraded 2026-10-12 to pve-manager
9.2.21, kernel `7.0.14-23-pve` — the same as inanna and enlil (HL-105). The
guests stayed on the node for the reboot: containers cannot move while running,
so migrating them would mean two short outages instead of one.

**Run long jobs in `tmux`** (`tmux new -s upgrade`, back with
`tmux attach -t upgrade`). Leaving the web Shell ends its session and whatever
runs in it; an `apt full-upgrade` was lost that way on 2026-09-24.

For production: wait about a week after a release before upgrading, back up
guests first, and migrate guests off a node to another before updating it — done that way
through the UI on 2026-09-24, see [inanna's Guests](../inanna/README.md#guests).

## Known quirks

- **Network drops on 2026-09-16 were an IP conflict**, not the NIC. The node (then pve1) was
  first given `.58`, inside the DHCP pool, and a Deco client with MAC
  `xx:xx:xx:xx:xx:xx` already held it — the Pi and the Mac each saw a different
  machine at `.58`. Fixed by moving to `.10` (HL-70). The Realtek's
  `can't disable ASPM` log line is still worth remembering if drops ever recur.
- **Harmless boot noise:** `ACPI Error ... WMIV` (HP firmware bug) and
  `Error Communicating to TPM chip` (TPM disabled in BIOS).

## Reinstalling a node

Done 2026-09-24 to rename pve1 to anu, when the cluster had two nodes and a
QDevice. Rewritten 2026-10-12 for three nodes and no QDevice
([ADR 0014](../../docs/decisions/0014-three-nodes-no-qdevice.md)). The node's
guests go to another node first. Guest backups on its own `backup` disk survive
if only the NVMe is the install target.

1. **Shut the node down.** The other two keep 2 of 3 votes and stay quorate.
2. On a node that stays: `pvecm delnode <name>`.
   `Could not kill node (error = CS_ERR_NOT_EXIST)` is harmless — the node is
   already off; check that `corosync.conf` no longer lists it. The cluster is
   now two nodes with no QDevice, so until the node rejoins, losing one more
   leaves the last without quorum.
3. Clean up: check `/etc/pve/nodes/<name>/qemu-server/` and `lxc/` are empty,
   then `rm -r /etc/pve/nodes/<name>`; remove its `root@<name>` line from
   `/etc/pve/priv/authorized_keys` (filter to a file outside `/etc/pve`, then
   `cat` it back — not `sed -i` on the cluster filesystem).
4. Install: NVMe only, ext4, `<name>.lan`, the node's own address (`.10`,
   `.11` or `.12`) `/22`, gateway `.1`, DNS `.71`. Then the DNS fallback,
   repositories, `apt full-upgrade` to match the other nodes, the `backup`
   mount above, and add the node to the `backup` storage's node list.
5. **Join from the shell, not the UI:** root has 2FA, and the UI join fails with
   `TFA-enabled login currently works only with a TTY`. On the new node, in
   tmux: `pvecm add <a node that stays> --link0 <its own IP>`, e.g.
   `pvecm add 192.168.68.11 --link0 192.168.68.10` — it asks for the
   password, the fingerprint and the TOTP code.
6. SSH hardening: confirm key login works first, then `01-hardening.conf` as
   above. On the Mac, `ssh-keygen -R` the old IP and name.
7. Beszel agent: the install command in
   [stacks/beszel](../kish/stacks/beszel/README.md), same version and key.
   The firewall rule is cluster-wide and comes back on joining. Then the CPU
   temperature sensor, which Proxmox does not load by itself:
   `echo coretemp > /etc/modules-load.d/coretemp.conf && modprobe coretemp`.
8. Pi-hole `.lan` record, Kuma monitor name, this repo — and
   `grep -rl <oldname> /etc/pve` on a node: the backup job named `pve1` and
   would have stopped running. `/etc/pve/priv/tfa.cfg` keeps the old name only
   as the authenticator entry's label, which is harmless.
