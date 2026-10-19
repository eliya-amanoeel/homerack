# enlil — HP ProDesk 600 G2 **MINI**

**Proxmox VE 9.2**, installed 2026-10-12 and joined to cluster `uruk` the same
day as its third node (HL-104). No guests yet.

A ProDesk **600** G2, where anu and inanna are 400 G2s: the same Skylake
platform, SODIMMs, NVMe slot and 2.5" bay, but a different BIOS family (N22).
Set up to match [anu](../anu/README.md); where this file is silent, anu's
applies.

## Access

- **Web UI:** **https://uruk.lan** shows all three nodes; Caddy tries anu,
  then inanna, then this node. Direct fallback: https://192.168.68.12:8006
  (self-signed).
- **Login:** `root`, realm **Linux PAM**, **TOTP 2FA** — inherited from the
  cluster on joining, so anu's password and authenticator entry apply here
- **SSH:** **key-only**, `ssh root@enlil.lan`, the `uruk` key from the password manager. It
  came with the cluster-wide `authorized_keys` on joining.
  `/etc/ssh/sshd_config.d/01-hardening.conf` is identical to anu's; confirmed
  with `sshd -T` on 2026-10-12
- **Firewall:** inherited from the Datacenter level on joining — same policy and
  `management` IPSet as anu. Confirmed `enabled/running` 2026-10-12
- **Network:** static `192.168.68.12/22`, gateway `192.168.68.1`, DNS
  `192.168.68.71` then `1.1.1.1` (HL-76), outside the Deco's DHCP pool, and
  reserved there too (2026-10-12). On switch port 4
- **Names:** `enlil.lan` → `.12` in Pi-hole
- **Monitored** in Uptime Kuma as `enlil direct`, cloned from `inanna direct`
- **Metrics** in Beszel (HL-98): native `beszel-agent` 0.20.0, same setup as
  anu; the firewall rule for 45876 is the Datacenter one. Its alerts were set
  on the system itself, to the values in
  [the Beszel README](../kish/stacks/beszel/README.md#alerts)

## Hardware

| | |
|---|---|
| **CPU** | Intel i5-6500T — 4C/**4T**, 35 W, LGA1151 Skylake. The only node without Hyper-Threading; an i7-6700T, as in the other two, is the platform's ceiling |
| **RAM** | 16 GB — 2 × SK hynix `HMA41GS6AFR8N-TF`, 8 GB 2Rx8 PC4-2133 SODIMM, the same part as anu and inanna |
| **Boot disk** | **Micron 2210 512 GB NVMe** (`MTFDHBA512QFD`) |
| **Second disk** | SanDisk X300s 128 GB 2.5" SATA, SED Opal 2.0 (self-encrypting; not locked, it read normally) — held an old Windows install, wiped 2026-10-12. SMART passed: attribute 173 at 94 (about 6% worn), 14,341 power-on hours. Attribute 190 (temperature) is flagged `In_the_past`: it has run hot at some point; 33 °C on 2026-10-12 |
| **NIC** | **Intel I219-LM** (onboard), `xx:xx:xx:xx:xx:xx`, `nic0`, bridged as `vmbr0` — Intel, where anu and inanna have Realtek |
| **Wi-Fi** | none — the M.2 RTL8822CE card was taken out on arrival. A Mini PCIe Atheros AR5B125 that came with the machine fits nothing here |

Thermal paste replaced on arrival, 2026-10-12.

**BIOS** (F10), HP **N22**: updated on 2026-10-12 from 02.58 to **02.60**
(2023-02-14, SoftPaq `sp144263`), the last release found for this model. HP's
N22 notes say it cannot be flashed back. Set the same day to match anu and
inanna (HL-75): VTx and VTd **on**, Legacy Support **off** with Secure Boot
**on** (`mokutil --sb-state`: enabled), Network (PXE) Boot **off**, CD-ROM and
USB Storage Boot **on**, **After Power Loss → Power On**. **Fast Boot off**:
it can skip USB initialisation, which would take F10 and F9 with it. No
boot-mode confirmation code appeared after the Secure Boot change. Secure
Boot, VTx and VTd re-checked from Linux 2026-10-13 (HL-102).

**CPU temperature:** `coretemp` loads at boot, as on all three nodes since
2026-10-14 — see [anu's Hardware](../anu/README.md#hardware).

## Storage

Same layout as anu: ext4/LVM, not ZFS (HL-84).

| Storage | Where | Type | Content |
|---|---|---|---|
| `local` | NVMe, `root` LV (96 GB) | Directory | ISO images, container templates, import |
| `local-lvm` | NVMe, `data` thin pool (~348 GB) | LVM-thin | VM and container disks |
| `backup` | SATA SSD, ext4, `/mnt/pve/backup` (~117 GB) | Directory | **Backups only** |

`backup` is the cluster-wide entry, `nodes anu,inanna,enlil` since 2026-10-12.
This disk was formatted before the join with **Disks → Directory**, with
**Add Storage unticked**: the cluster entry already existed, and joining
replaces a node's own storage list anyway. Proxmox wrote the mount unit,
`/etc/systemd/system/mnt-pve-backup.mount`
(`What=/dev/disk/by-uuid/453eccfb-3cb5-41ab-8816-88b4ef896356`). As on anu, **do not
recreate it with Disks → Directory** — that formats the disk.

The backup job covers all guests on all nodes, so anything placed here is
backed up to this disk from its first night.

## Cluster

Joined `uruk` on 2026-10-12, from an SSH session in tmux (the UI join fails
with 2FA, see [inanna's README](../inanna/README.md#cluster)):

```bash
pvecm add 192.168.68.10 --link0 192.168.68.12
```

It asked for the cluster's root password, the fingerprint and a TOTP code.
The QDevice had to be removed first, and was then removed for good: three nodes,
one vote each, quorum two
([ADR 0014](../../docs/decisions/0014-three-nodes-no-qdevice.md)).

## Updates

No-subscription repository; `pve-enterprise` and `ceph` disabled. Installed
from a 9.2.2 ISO and fully upgraded 2026-10-12 to pve-manager **9.2.21**,
kernel `7.0.14-23-pve`. anu and inanna were brought to the same version the
same evening (HL-105).
`tmux` is installed.

## Guests

None yet. `edge` stayed here briefly on 2026-10-12 while inanna rebooted
(HL-105).
