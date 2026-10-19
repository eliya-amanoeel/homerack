# Hardware inventory

Verified 2026-09-04 where marked ✅, and ✅ items re-checked against the hosts
2026-09-28 and 2026-10-13. The rack and switch were checked by hand on
2026-10-13; the nodes' console-only BIOS settings are still open (HL-102).

## kish — Raspberry Pi 4 Model B Rev 1.5

- **Role:** DNS (Pi-hole), WireGuard, Caddy for the `.lan` UIs, monitoring (Uptime
  Kuma, Beszel hub), unifi controller, Portainer. Was also the cluster's
  QDevice until 2026-10-12 ([ADR 0014](decisions/0014-three-nodes-no-qdevice.md))
- **RAM:** 3.7 GB usable (4 GB model) ✅
- **Swap:** 2 GB zram ✅
- **Storage:** 119 GB **SanDisk High Endurance SD card** — `/dev/mmcblk0`, root
  on p2 (ext4), under 10% used ✅
  A high-endurance card is rated for sustained writes and is the right choice
  here. It lowers the wear-out risk rather than removing it — SD is still less
  reliable than an SSD, and this Pi carries DNS and WireGuard. Accepted risk
  (HL-03), covered by backups and the rebuild runbook.
- **OS:** Raspberry Pi OS (Debian 13 trixie), Raspberry Pi kernel, aarch64 ✅
- **Power:** healthy — `vcgencmd get_throttled` = `0x0`, no undervoltage ✅
- **Power source:** USB-C brick — its switch port has PoE off (2026-09-18)
- **Config:** [hosts/kish/](../hosts/kish/)

## inanna — HP ProDesk 400 G2 **MINI** (formerly `prodesk`, then `pve2`)

- **Role:** Proxmox VE 9.2, second node of cluster `uruk` — installed 2026-09-18 as `pve2`, reinstalled as `inanna` 2026-09-24; runs edge, site-b and postgres (HL-77)
- **Hostname:** `inanna` · **IP:** 192.168.68.11 (static)
- **CPU:** Intel i7-6700T — 4C/8T, 2.8 GHz, 35 W, LGA1151 Skylake ✅
- **RAM:** 16 GB — **2 × SK hynix `HMA41GS6AFR8N-TF`**, 8 GB 2Rx8 PC4-2133
  **SODIMM**, slots DIMM1 + DIMM3 ✅
  **Both slots are full**, so this box can only be upgraded by replacing sticks.
  Not maxed: the platform takes 2 × 16 GB for 32 GB.
- **Disks:** SK hynix PC711 512 GB NVMe (boot, guests) + Samsung PM871 128 GB
  2.5" SATA (backups) ✅. The SATA disk was the Windows disk and is **46% worn**
  (wear levelling 054, SMART passed, 2026-09-28 and 2026-10-17; 75,918 power-on hours, which `smartctl` flags as at threshold — age, not wear) — anu's is at 18%. The WD My Passport 931 GB USB that hung off it under
  Windows is unplugged
- **NIC:** `xx:xx:xx:xx:xx:xx` (Realtek GbE) — **1 Gbps** confirmed 2026-09-07
  after re-patching ✅
- **Windows Server 2022 Standard** (retail licence, key in the password manager) ran here
  from 2025-07-16 until the wipe on 2026-09-18
- **Config:** [hosts/inanna/](../hosts/inanna/)

## anu — HP ProDesk 400 G2 **MINI**

Formerly `prodesk-spare`, then `pve1` from the Proxmox install on 2026-09-16,
and `anu` since its reinstall on 2026-09-24.
**Same platform as `inanna`** — confirmed 2026-09-07 from the SODIMM slots on
the board. RAM and CPU are interchangeable between the two machines.

- **Role:** Proxmox VE 9.2, first node of cluster `uruk` — runs amaeli and site-a (HL-77) ✅
- **Hostname:** `anu` · **IP:** 192.168.68.10 (static, outside the DHCP pool) ✅
- **CPU:** Intel **i7-6700T** — 4C/8T, 2.8 GHz, 35 W, LGA1151 Skylake —
  fitted 2026-09-24, replacing the original i5-6500T (HL-08) ✅
- **RAM:** 16 GB — **2 × SK hynix `HMA41GS6AFR8N-TF`**, 8 GB 2Rx8
  PC4-2133P-SE0-11 **SODIMM** — second stick fitted 2026-09-24 ✅
- **Disk:** **SK hynix PC711 512 GB NVMe** (`HFS512GDE9X081N`) — boot disk,
  fitted 2026-09-16; the M.2 slot links at **PCIe Gen2 x4** ✅
  + **Samsung PM871 256 GB 2.5" SATA** (`MZ7LN256HMJP`) — backup storage,
  18% wearout ✅
  A second PC711 was bought at the same time; it is inanna's boot disk.
- **NIC:** Realtek RTL8168h, `xx:xx:xx:xx:xx:xx` ✅
- **Config:** [hosts/anu/](../hosts/anu/)

## enlil — HP ProDesk 600 G2 **MINI**

Set up 2026-10-12 as the cluster's third node (HL-104).
The **600** G2 is the business sibling of the 400 G2: same Skylake platform,
RAM and slots, different BIOS family (N22).

- **Role:** Proxmox VE 9.2, third node of cluster `uruk` since 2026-10-12; no guests yet ✅
- **Hostname:** `enlil` · **IP:** 192.168.68.12 (static, outside the DHCP pool) ✅
- **CPU:** Intel **i5-6500T** — 4C/4T, 2.5 GHz, 35 W, LGA1151 Skylake ✅
  The i7-6700T in anu and inanna is this platform's ceiling: 6th gen only.
- **RAM:** 16 GB — **2 × SK hynix `HMA41GS6AFR8N-TF`**, 8 GB 2Rx8 PC4-2133
  **SODIMM**, the same part as the other nodes ✅
- **Disks:** **Micron 2210 512 GB NVMe** (`MTFDHBA512QFD`, boot, guests) + **SanDisk X300s 128 GB**
  2.5" SATA, SED Opal 2.0 (backups) — about **6% worn**, SMART passed,
  14,341 hours (2026-10-12); it held an old Windows install ✅
- **NIC:** **Intel I219-LM**, `xx:xx:xx:xx:xx:xx` — Intel, where anu and inanna have Realtek ✅
- **Wi-Fi:** removed on arrival — an M.2 RTL8822CE. A Mini PCIe Atheros
  AR5B125 that came with it fits nothing here
- **BIOS:** N22 **02.60**, updated from 02.58 on 2026-10-12 ✅
- **Config:** [hosts/enlil/](../hosts/enlil/)

## USW-Lite-8-PoE — unifi Switch Lite 8 PoE

- **Ports:** 8× GbE, 4× PoE+ (52 W budget)
- **Managed by:** native unifi Network Application 10.6.101 on `kish`
- **PoE budget in use:** 0 W — PoE is off on ports 1–4 (2026-09-18)
- **Port map:** [network.md](network.md)

## nergal — Synology DS420+

Fully set up and managed outside this repo. Recorded here only so the network
map is complete.

- **Name:** `nergal` — was `EnkiduCloud` until 2026-09-25. Pi-hole name `nergal.lan` (since 2026-09-30), used by the Drive and Photos clients. QuickConnect (`<quickconnect-id>`) is **off** and DDNS `nergal.synology.me` deleted since 2026-09-30 ([ADR 0013](decisions/0013-nas-reached-only-from-home-or-wireguard.md)).
- **IP:** 192.168.68.56 · **MAC:** `xx:xx:xx:xx:xx:xx`
- **Ports:** DSM 5000/5001 (and 80/443, which only redirect to DSM), Synology Drive sync **6690**. SMB and FTP **off** since 2026-10-02: nothing used them; ticking SMB back on in File Services restores it.
- **DSM firewall** (Control Panel → Security → Firewall, profile `default`), since 2026-10-02: the first two rules **deny** `192.168.68.20`–`.49` (the Proxmox guests) and `192.168.68.66` (the Hue bridge), so a compromised website or IoT device cannot reach the NAS; everything else is allowed. A blocklist, not an allowlist: home devices get addresses from the DHCP pool (`.50`+) and WireGuard arrives from `kish`, so address changes never lock anyone out. Tested: `edge` blocked, the Mac and `kish` allowed. A lab server that ever needs the NAS needs an exception above the deny rules.
- **Snapshots** (Snapshot Replication, Btrfs), since 2026-10-02: `homes`, `docker` and one personal share daily, keeping 7 daily, 4 weekly, 3 monthly. The rollback against ransomware or deletes on the NAS itself; not a backup, since it lives on the same disks.
- **Certificate:** DSM's self-signed `synology` is the default for every service since 2026-10-04 (valid until 2027-09-29); clients accept its warning once. The old `enkiducloud.synology.me` cert was deleted. The QuickConnect certificate stays: DSM 7 won't delete a QuickConnect certificate, it's unused and expires 2026-12-24.
- None is published to the internet: reached from home or over WireGuard only — see [network.md](network.md)

## hue-bridge — Philips Hue Bridge

- **Role:** Zigbee lighting
- **IP:** 192.168.68.66 · **MAC:** `xx:xx:xx:xx:xx:xx` ✅
- Serves nginx on 80/443 — that is the bridge's own web/API surface, not a
  separate machine
- **Model:** Hue Bridge **v2** (`BSB002`), API 1.78.0 — Ethernet is 10/100, so
  its switch port always shows FE ✅ (read from `/api/0/config`, 2026-09-18)
- **API access:** the bridge issues a key **per application**, generated by
  pressing the physical link button — it is not a password and cannot be looked
  up. Any integration (Home Assistant included) gets its own.

## Rack

- 10" 3D-printed rack, **8U** · **Free space:** 2U.
  Counted by the owner 2026-10-14; the 11U recorded from 2026-09-18 was wrong.
- **Contents, 1U each:** `anu`, `inanna`, `enlil`, `kish`, `USW-Lite-8-PoE`, a patch
  panel, and 2U free. The Hue bridge is in the rack without its own U; the PDU
  hangs on the back. `nergal` and the Deco are outside the rack.
- **UPS:** none, by choice (HL-15 dropped 2026-09-18). Unclean power loss is
  the other main way SD cards die — accepted, covered by backups.
