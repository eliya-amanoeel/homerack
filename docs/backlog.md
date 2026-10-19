# Backlog

**This file is the single tracker for the lab.** Everything open lives here —
including the `TODO` markers scattered through other files, which are indexed
under [Documentation gaps](#documentation-gaps) rather than tracked separately.

Each item has a stable ID (`HL-NN`) so it can be referenced in commits and
conversation. When you finish one, tick the box and move it to [Done](#done)
as one line with a date.

**Status key:** `[ ]` open · `[~]` in progress · `[x]` done · `[-]` dropped

Ids are never reused. `scripts/check-docs.sh` fails if one goes missing from the
sequence, because an item can otherwise vanish silently into a bad edit — which
has happened. Ids retired without ever being worked are declared here:

<!-- retired: HL-49 HL-57 HL-58 HL-59 HL-63 HL-64 HL-65 HL-73 HL-74 HL-80 HL-36 HL-13 -->
- **HL-13** — Ansible for kish; dropped 2026-09-26 at the owner's request.
  One Pi does not justify keeping a playbook in sync; the HL-07 restore
  runbook and kish's READMEs are the rebuild path.
- **HL-36** — a consistent SQLite snapshot of Kuma's DB in `backup.sh`;
  dropped 2026-09-26 at the owner's request. monitors.md is the record to
  rebuild Kuma from if a backup copy is ever torn.
- **HL-80** — self-hosting the password manager; dropped
  2026-09-26 at the owner's request. The vault must stay reachable when the
  lab is down, since it holds the credentials to fix it.
- **HL-73** — SPF and DMARC for `site-b.example` (and SPF for `site-a.example`);
  dropped 2026-09-26 at the owner's request.
- **HL-49** — a second, filtering resolver; dropped 2026-09-25 at the owner's
  request. A kish outage is noticed by hand; see network.md.
- **HL-74** — the NAS as a second Proxmox backup target; dropped 2026-09-25
  at the owner's request.
- **HL-64** — restoring remote DS Finder access; dropped 2026-09-07 at the
  owner's request.
- **HL-63, HL-65** — raised about the Synology on 2026-09-06 and retired the
  same day: the NAS is set up and managed outside this repo, and only its
  existence and ports need recording.
- **HL-57, HL-58, HL-59** — raised from `prodesk` discovery on 2026-09-05
  (two unpublished sites, PostgreSQL backups, manual Windows patching) and
  retired the same day once confirmed all three were deliberate.

---

## Tier 0 — Discovery

Nothing open — the lab is fully documented as of 2026-09-18.

---

## Tier 1 — Active risk

Nothing open — the first scheduled backup after the renames ran clean on
2026-09-25 (HL-90).

---

## Tier 2 — Blocking other work

- [~] **HL-07 · Test the rebuild runbook.**
  A recovery procedure that has never been executed is a guess. Follow
  [rebuild-kish.md](runbooks/rebuild-kish.md) literally on real hardware and fix
  every step that turns out to be wrong.
  **2026-09-25: revised on paper first.** It predated Caddy, WireGuard, the
  Portainer git stacks, the absolute Pi-hole binds and HL-33's localhost-only
  UIs; all of those are now in it, and the places a paper review cannot settle
  are marked **Test point**. **Still owed: the live run.** There is no spare SD
  card (still none on 2026-09-28), and a spare is what makes the test safe — the current card stays
  untouched as a minutes-long rollback. Get one (16 GB+) before attempting it.

---

## Tier 3 — Improvements

- [ ] **HL-81 · Where the public sites should actually live.** Raised
  2026-09-22, **parked deliberately** — recorded now so the options do not have
  to be re-researched later. Nothing is wrong today; this is about the gap
  between a good architecture and a residential location.

  [ADR 0008](decisions/0008-site-hosting-pattern-on-proxmox.md) is sound and
  matches how real hosting is built: one internet-facing proxy, each site
  isolated, a separate database guest, builds on clean runners. Proxmox itself
  is enterprise virtualization, not a compromise. **The risk is the building,
  not the software** — residential ISPs block inbound 80 and refuse static IPs,
  there is one uplink and one power feed with no SLA, the home IP is published
  in DNS as a DDoS target, and `edge` is a single point of failure the ADR
  already names.

  | Option | Cost | Good for |
  |---|---|---|
  | **Static host** (Cloudflare Pages, Netlify) | free | pre-built static sites — global CDN, TLS, deploy from git, nothing to patch |
  | **VPS** (Hetzner ~€4/mo, DigitalOcean) | low | anything with a runtime or database; real datacenter uptime |
  | **Home + Cloudflare Tunnel** | free | keeps hosting at home; outbound-only, so no port forwarding, no static IP, home IP never exposed, TLS terminated at their edge |
  | **Home + port forward** | free | what the lab does now |

  **The shape that fits this lab:** amaeli and the other static builds go to a
  static host — free, faster than the uplink, and unaffected by a power cut.
  SiteB needs a runtime, so it is a VPS or it stays home behind a
  Cloudflare Tunnel rather than a port forward. Proxmox then does what it is
  best at: internal services and staging.

  **The question that decides it:** whether these sites are the owner's own or
  other people's. Client or employer sites make this a liability question —
  uptime promised that cannot be controlled. Own projects make home hosting
  entirely reasonable. Cloudflare made Tunnel free with unlimited bandwidth in
  July 2026 (15 July; confirmed 2026-09-28 by secondary sources, e.g.
  [bex.co](https://bex.co/blog/2026/07/28/cloudflare-tunnel-free-zero-open-ports-ingress)),
  which is what changed the calculus; note their terms still bar
  media streaming (Plex/Jellyfin) through a tunnel, so it is not a
  general-purpose pipe (still so on 2026-09-28 per community sources, e.g.
  [this Cloudflare Community thread](https://community.cloudflare.com/t/confusion-about-tos-in-relation-to-using-cloudflared-tunnel-for-media-streaming/839900);
  rarely enforced, but in the terms).

- [ ] **HL-78 · An IP KVM for BIOS access and reinstalls.** Raised 2026-09-18.
  Today a reinstall means pulling the node out of the rack and bringing a
  monitor and keyboard. **A GL.iNet Comet PoE (GL-RM1PE) was bought and
  returned on 2026-09-24 — it could not do the one job it was bought for on
  these machines.** Everything below is what that cost to learn; read it before
  buying another.

  **What failed.** The ProDesk 400 G2's firmware never initialises the Comet's
  emulated keyboard during POST. Video was perfect and the keyboard worked
  normally once Linux booted, but nothing reached GRUB or the BIOS. Tried
  without success: unmounting virtual media, three different device identities
  (Logitech, Corsair), `GRUB_TIMEOUT=10`, disabling the PXE option ROM,
  enabling USB Legacy Support, and `efibootmgr --bootnext`, which this firmware
  simply ignores for its synthesised USB entries. Even the **emulated CD-ROM
  would not boot** with `USB:` first in the UEFI boot order and CD-ROM Boot
  enabled.

  **The mechanism, and it generalises.** This firmware only accepts a simple
  boot-protocol keyboard. The physical Xtrfy K5 is ignored too until **FN + DEL**
  drops it from N-key to 6-key rollover. The Comet presents a five-interface
  composite — keyboard, two mice, two mass-storage — and POST gives up on it.
  Proof: disabling virtual media made the keyboard work at POST, and
  re-enabling it broke it again, repeatably. So on this hardware **pre-boot
  input and virtual media are mutually exclusive**, which makes a KVM useless
  for installing an OS.

  **Requirements for any replacement.** It must present as a *simple* USB HID
  keyboard at POST while mass storage is attached, on firmware this old. Ask
  before buying, or buy somewhere with a return policy. JetKVM and NanoKVM are
  the obvious alternatives. A plain physical USB stick still boots these
  machines fine, so the fallback is unchanged: walk to the rack.

  **Not returned with it — keep these**, all set at the rack on 2026-09-23 and
  worth having regardless: **After Power Loss → Power On** (anu and inanna since 2026-09-24, HL-75; enlil since 2026-10-12),
  Network (PXE) Boot **off**, CD-ROM Boot and USB Storage Boot **on**, Legacy
  Support **off** with Secure Boot **on** (Proxmox boots via `shimx64.efi`).
  `GRUB_TIMEOUT=10` was set too, but the 2026-09-24 reinstalls put both nodes
  back on the default 5 (checked 2026-09-28) — left there, not worth restoring
  without a KVM to use it. The switch is back as it was: PoE off on
  port 4, `hue-bridge` left on port 6.

- [ ] **HL-95 · `ubuntu-latest` becomes Ubuntu 26 on 2026-10-19.** GitHub's
  notice on amaeli's HL-85 run, 2026-09-25. Every site's build job runs on
  `ubuntu-latest`, so each moves on its own. After that date, run each site's
  **Build & Deploy** once and check it is still green; pin `ubuntu-24.04` in a
  site's workflow only if one breaks.

- [ ] **HL-97 · Check site-b's workflow for Node 20.** Raised 2026-09-26,
  deferred by the owner. amaeli (HL-85) and site-a (HL-96) moved off Node 20:
  Node 24 via `.nvmrc`, and v7/v8 actions. **Read 2026-09-28:** site-b's
  `deploy-linux.yml` still uses `@v4` actions throughout (`checkout`,
  `setup-dotnet`, `upload-artifact`, `download-artifact`) and has no Node step,
  so it very likely needs the same move. Check the last run's annotations
  first; if it needs the fix, hand a prompt to a session in that repo as for
  site-a.

- [ ] **HL-102 · Verify what the 2026-09-28 audit could not reach.** The audit
  checked every doc against the live hosts (kish, edge, the four containers,
  both nodes); these can only be checked by hand or from elsewhere:
  - [x] **Deco:** DHCP pool `192.168.68.50`–`192.168.71.250`, and reservations for kish, USW-Lite-8-PoE,
    nergal, hue-bridge, anu and inanna ([network.md](network.md#addressing)).
    Checked 2026-10-13: range `192.168.68.50`–`192.168.71.250`, all six
    correct, plus enlil (`.12`) and edge (`.20`).
  - [x] **unifi:** USW-Lite-8-PoE's port map and PoE off on ports 1–4
    ([network.md](network.md#switch-port-map)). Checked 2026-10-13: all
    eight ports as documented.
  - [~] **BIOS** on anu and inanna: the settings in each node's README.
    enlil's were set at its console on 2026-10-12. **2026-10-13, from Linux
    on all three nodes:** Secure Boot enabled (so Legacy off), VT-x on (`vmx` in every
    thread's flags), VT-d on (ACPI `DMAR` table present). **Still owed, at
    the console:** PXE off, CD-ROM and USB Storage Boot on, After Power
    Loss → Power On. Do it at the next reboot that happens anyway, not one
    made for this (inanna's needs edge moved off first).
  - [x] **Rack:** 8U, 2U free, no UPS ([inventory.md](inventory.md#rack)).
    Checked 2026-10-13: no UPS. Size and free space corrected on 2026-10-14 by counting the units: 8U, 2U free (was recorded as 11U, 1U free).
  - [x] **From outside the network:** only 80, 443 and 51820/udp answer
    on `203.0.113.10` ([network.md](network.md#internet-exposure)).
    Checked 2026-10-13 from the Mac on a phone hotspot.
  - [x] **UptimeRobot:** three `(external)` Keyword monitors, alerts by email
    ([monitors.md](../hosts/kish/stacks/network-core/monitors.md)).
    Checked 2026-10-13: all three up, alerts to the owner's Gmail.
  - [x] **`secrets/README.md`:** read it yourself — the audit deliberately did
    not look at where secrets are kept. Read by the owner 2026-10-13: accurate.
  - **ADRs:** nothing to do; by the rule they keep the facts of their day.
  - **The rebuild runbook as a procedure** is HL-07; only its statements were
    checked.

- [ ] **HL-108 · Isolate IoT on the flat network.** Replaces HL-12: no VLANs
  while the Deco routes ([ADR 0015](decisions/0015-no-vlans-while-the-deco-routes.md)).
  All the IoT devices are on Wi-Fi
  except the Hue bridge. Raised 2026-10-19; to be discussed before any change.
  - **Wi-Fi IoT → Deco Device Isolation.** Isolated devices keep internet and
    reach each other, not the home network. **Open:** which devices to isolate,
    given what reaches them locally, such as casting, printing and the
    devices' own apps. **Waits for Home Assistant:** it will
    need local access to many of these devices, so which to isolate depends on
    where it runs and what it controls.
  - **Hue bridge (wired, port 6) → deny `.66` on the hosts.** `nergal` already
    does (DSM firewall). Left: the nodes — narrow the `management` IPSet to
    leave out `.66` (check that Proxmox IPSets take an exclusion) — and `kish`,
    which must still answer the bridge on 53 since it is its only DNS; harder,
    as Docker writes its own firewall rules. Scope (nodes only, or `kish` too)
    still to decide.
  - **unifi port isolation** is believed not to fit (an isolated port still
    reaches non-isolated ones), from third-party sources only. Test: isolate
    port 6 alone, then from the Pi `curl -sk https://hue.lan/api/0/config` — an
    answer confirms it.
- [ ] **HL-16 · Grafana/Prometheus.** Only if Uptime Kuma stops being enough.
  Deliberately last — it is the most fun and the least necessary.
- [ ] **HL-106 · Metal rack to replace the printed one.** Raised 2026-10-14,
  the owner is thinking it over. Wanted: 10", enclosed metal, 8U now with room
  to add on top later, for the office floor or a table; printed shelves and
  mounts to start. Today's rack ([inventory.md](inventory.md#rack)) is the
  MakerWorld "Modular 10" Server Rack" (model 1452571), M6 cage nuts, 200 mm
  outer depth. Findings so far:
  - **Enclosed, metal and stackable rarely come together in 10".** The stackable
    frames found are open (DeskPi RackMate T1 8U / T2 12U, about 16" deep, no
    official stacking kit); the enclosed cabinets are fixed heights (Delock
    4/6/8U, DSIT 12U at 310 mm deep). Options: an enclosed 12U now, an open
    stackable frame plus panels, or two enclosed cabinets stood on each other.
  - **Depth:** the ProDesk minis are about 177 mm deep, plus plugs and cable
    bend behind, so about 250 mm usable inside, about 300 mm outside. Still to
    measure: front of a ProDesk to the furthest point of its cables.
  - **PDU:** no 10" cabinet found with a dedicated PDU slot. Rear rails let a
    1U PDU at the back share a U with a short device at the front.
  - **Heat:** an enclosure warms the minis. Baseline at idle on 2026-10-14:
    CPU package 30–32 °C, NVMe 33–42 °C, chipset 33–43 °C. Compare after the
    move; the Beszel alert (HL-98) is at 75 °C.

---

## Documentation gaps

Legwork, not decisions. None open; check for new `TODO` markers with:

```bash
grep -rn "TODO" --include="*.md" --include="*.sh" --include="*.yml" .
```

---

## Done

One line per item — the full write-up of each is in git history
(`git log -S "HL-NN" -- docs/backlog.md`).

- [x] **HL-109 · 2026-10-19** — Public copy live at `eliya-amanoeel/homerack`, generated by `scripts/export-public.sh` ([ADR 0016](decisions/0016-public-copy-is-generated.md)) into the clone at `~/homerack`; README for outside readers, MIT license and GitHub topics. Re-export when there is something worth showing.
- [x] **HL-12 · 2026-10-19** — No VLANs: the Deco XE75 stays the router and cannot route or filter between them, so switch VLANs would only cut devices off ([ADR 0015](decisions/0015-no-vlans-while-the-deco-routes.md)). Isolation continues as HL-108.
- [x] **HL-107 · 2026-10-14** — `coretemp` loaded at boot on anu, inanna and enlil (`/etc/modules-load.d/coretemp.conf`); Beszel shows CPU temperatures, not only NVMe and chipset. In the reinstall steps in [hosts/anu/](../hosts/anu/README.md#reinstalling-a-node).
- [x] **HL-105 · 2026-10-12** — anu and inanna upgraded to pve-manager 9.2.21 (kernel `7.0.14-23`), matching enlil. anu rebooted with its containers in place; edge live-migrated to enlil and back around inanna's reboot. The `Qdevice (votes 0)` row cleared with inanna's reboot.
- [x] **HL-104 · 2026-10-12** — Third node `enlil` (ProDesk 600 G2 Mini, `.12`) installed and joined to `uruk`: BIOS 02.60, `backup` disk, SSH key-only, Beszel, Kuma, `enlil.lan`, third `uruk.lan` upstream. QDevice removed everywhere, `corosync-qnetd` off kish ([ADR 0014](decisions/0014-three-nodes-no-qdevice.md)). See [hosts/enlil/](../hosts/enlil/README.md).
- [x] **HL-92 · 2026-09-30** — The NAS is reached only from home or over WireGuard: `nergal.lan` in Pi-hole, Drive and Photos re-pointed, 6690 forward deleted, QuickConnect off, DDNS `nergal.synology.me` deleted ([ADR 0013](decisions/0013-nas-reached-only-from-home-or-wireguard.md)). `dsm.lan` not needed: DSM is at `https://nergal.lan:5001`.
- [x] **HL-103 · 2026-09-30** — `.lan` certs last 3 days instead of Caddy's 12h default (`cert_issuer internal { lifetime 3d }`), which caused `ERR_CERT_DATE_INVALID` on the first visit each morning. Deployed and reissued; the morning fix is unconfirmed — reopen if the warning returns.
- [x] **HL-35 · 2026-09-28** — unifi autobackup runs daily at 00:30 (files on 26, 27, 28 Sep). `backup.sh` run the same day, and fixed: keeps the newest 3 backups, and prunes only after a complete run.
- [x] **HL-82 · 2026-09-28** — Caddy on kish is a local compose project like Portainer, not a fourth method; kept outside Portainer on purpose ([ADR 0012](decisions/0012-caddy-on-kish-stays-outside-portainer.md)). CLAUDE.md and the kish README now list all three methods; no deploy script, the README's three commands suffice.
- [x] **HL-101 · 2026-09-28** — `www.site-a.example` was One.com's default record (`46.30.211.38`); now a CNAME to `site-a.example`, and `edge` redirects it (301) to `https://site-a.example`.
- [x] **HL-100 · 2026-09-28** — `edge.lan` → `192.168.68.20` added to Pi-hole's `dns.hosts`.
- [x] **HL-99 · 2026-09-28** — Website statistics with GoAccess instead of Umami (Search Console covers amaeli and site-a; site-b's login is shared). Hourly report per site at `https://goaccess.lan`, from Caddy access logs on `edge` with shortened IPs. Setup in [hosts/edge/goaccess](../hosts/edge/goaccess/README.md).
- [x] **HL-98 · 2026-09-27** — Beszel hub on kish (`https://beszel.lan`), agents on kish, anu and inanna; alerts to ntfy for status, disk 85%, temperature 75 °C and memory 90%. Setup in [stacks/beszel](../hosts/kish/stacks/beszel/README.md).
- [x] **HL-54 · 2026-09-26** — No infrastructure monitors added, by choice: none would alert on something not already caught or noticed. Reasons per monitor in monitors.md.
- [x] **HL-72 · 2026-09-26** — The repo was only recased; the Mac clone's remote now uses the new URL. No workflow hardcoded the old name, and runner `site-b-lxc` was unaffected.
- [x] **HL-86 · 2026-09-26** — add-a-site runbook finished: step 7 routes the site through `edge` and covers the cutover. No guest firewall on site containers, by the owner's choice; only `edge` has one.
- [x] **HL-94 · 2026-09-26** — kish, Portainer, network-core, Caddy and WireGuard READMEs and dns-outage cause 1 brought in line with HL-33's localhost binds, backup.sh, the absolute Pi-hole paths and wg-easy v15. Pi-hole upstreams and `.lan` records checked live.
- [x] **HL-56 · 2026-09-26** — Gateway admin, WiFi PSK and the switch's device SSH login are in the password manager. The SSH login already existed (user `eliya.amanoeel`); proven by logging in to `switch-01` at `.68`.
- [x] **HL-96 · 2026-09-26** — site-a builds on Node 24 (`.nvmrc`, `engines`), actions as amaeli plus setup-dotnet v6; npm audit to 0 (react-router 7, vite 8 with the old browser targets pinned); deployed green, site-a-form restarted and answering.
- [x] **HL-85 · 2026-09-25** — amaeli builds on Node 24 (`.nvmrc`, `engines`) with checkout/setup-node/upload-artifact v7 and download-artifact v8, off the Node 20 actions runtime; deployed green. The add-a-site workflow template matches.
- [x] **HL-90 · 2026-09-25** — First scheduled backup after the renames ran clean: Tasks OK on anu and inanna at 02:30, and each node's `/mnt/pve/backup/dump` holds that night's archives for all its guests (anu 101, 102; inanna 100, 103, 104, 9000, 9001).
- [x] **HL-93 · 2026-09-25** — The NAS is `nergal` (was `EnkiduCloud`), QuickConnect ID renamed to match. Drive, Photos and Secure SignIn re-pointed; 2FA re-enabled with approve sign-in. A `nergal.lan` record was added and removed the same day: nothing used it.
- [x] **HL-91 · 2026-09-25** — Site Caddyfiles live in each site's repo at `deploy/Caddyfile` (ADR 0010); amaeli's moved out of `hosts/amaeli/`. Only edge's stays here.
- [x] **HL-89 · 2026-09-24** — The Pi is `kish` (was `EnkiduPi`): hostname, `user-data`, cloud-init disabled so it sticks, proven by a reboot; `hosts/kish/`, scripts and runbooks renamed, `.local` replaced by `.lan` or the IP.
- [x] **HL-87 · 2026-09-24** — pve2 reinstalled as `inanna`; guests back in the HL-77 layout. The cluster UI is now `uruk.lan` (was `pve.lan`) and the shared SSH key is labelled `uruk`.
- [x] **HL-88 · 2026-09-24** — The backup job was tied to `node pve1` and ran twice daily (`2,22:30`), so it would have stopped after the rename; now all nodes, once at 02:30. See anu's README.
- [x] **HL-84 · 2026-09-24** — No automatic failover: a restore from backup is acceptable downtime, so both nodes stay ext4/LVM and no ZFS replication or HA. pve1 was reinstalled as `anu` the same day; pve2's rename is HL-87.
- [x] **HL-08 · 2026-09-24** — Both ProDesks run Proxmox VE 9.2 in cluster `uruk`, identical i7-6700T / 16 GB; Windows gone since 2026-09-18. Leftovers split into HL-85 and HL-86.
- [x] **HL-77 · 2026-09-24** — Guests spread: amaeli and site-a on pve1 (now anu); edge, site-b and postgres on pve2 (now inanna). The failover decision moved to HL-84.
- [x] **HL-75 · 2026-09-24** — Both nodes' BIOS set alike: VTx/VTd on, UEFI + Secure Boot, PXE off, After Power Loss → Power On. Not yet proven by a real power cut.
- [x] **HL-83 · 2026-09-23** — WireGuard drops were Microsoft Defender's network extension issuing "Stop command received" every 4-7 minutes; removing Defender fixed it. Re-added clients had also lost `PersistentKeepalive` and DNS, fixed separately.
- [-] **HL-15 · 2026-09-18** — UPS dropped: not buying one. Power cuts are covered by BIOS auto power-on and backups.
- [-] **HL-79 · 2026-09-22** — Dashy dropped: a links page over twelve services that a browser bookmarks folder already covers.
- [x] **HL-24 · 2026-09-18** — Switch port map, PoE, NAS reservation and Hue model read from the UIs.
- [x] **HL-18 · 2026-09-18** — [network.md](network.md) has no blanks left.
- [x] **HL-19 · 2026-09-18** — [inventory.md](inventory.md) has no blanks left; rack recorded as 11U with 3U free (wrong — 8U, corrected 2026-10-14, HL-102).
- [x] **HL-60 · 2026-09-18** — Hand-crimped cables re-patched; every link is GbE except the Hue bridge, whose port is 10/100 by design (v2, `BSB002`).
- [x] **HL-76 · 2026-09-18** — Servers fall back to `1.1.1.1` for DNS; fixed a PostgreSQL boot race found on the way.
- [x] **HL-71 · 2026-09-17** — SiteA's `send.ashx` replaced by the `site-a-form` service in LXC 102.
- [x] **HL-69 · 2026-09-17** — Confirmed all five sites could run on Linux, so ADR 0007 stood.
- [x] **HL-70 · 2026-09-16** — pve1's network drops were an IP conflict inside the DHCP pool; moved to `.10`.
- [-] **HL-14 · 2026-09-04** — Off-site encrypted backup dropped as disproportionate ([ADR 0006](decisions/0006-backups-are-deliberately-modest.md)).
- [x] **HL-33 · 2026-09-07** — Admin UIs reachable only through Caddy (bound to `127.0.0.1`).
- [x] **HL-68 · 2026-09-07** — `INSECURE=true` removed from wg-easy.
- [x] **HL-67 · 2026-09-07** — Caddy's CA (`caddy_data`) added to `backup.sh`.
- [x] **HL-11 · 2026-09-07** — Caddy reverse proxy with an internal CA for the `.lan` admin UIs.
- [x] **HL-66 · 2026-09-07** — `www.amaeli.se` fixed (DNS record and certificate).
- [x] **HL-32 · 2026-09-06** — The Pi resolves via itself, then `1.1.1.1`.
- [x] **HL-62 · 2026-09-06** — DSM port 5000 forward removed.
- [x] **HL-61 · 2026-09-05** — `switch-01` moved from a broken static address to a DHCP reservation.
- [x] **HL-10 · 2026-09-05** — Every rack host given a reserved address.
- [x] **HL-30 · 2026-09-05** — Discovery run on the Windows box (since wiped).
- [x] **HL-39 · 2026-09-05** — Public web exposure documented.
- [x] **HL-20 · 2026-09-05** — Windows box's README filled in (since removed).
- [x] **HL-55 · 2026-09-05** — `secrets/credentials.md` deleted.
- [x] **HL-34 · 2026-09-05** — All credentials moved to the password manager.
- [x] **HL-06 · 2026-09-05** — Compose files reconciled with reality; closed by HL-29.
- [x] **HL-09 · 2026-09-05** — Monitoring live in two layers: UptimeRobot and Uptime Kuma.
- [x] **HL-53 · 2026-09-05** — First repo audit for drift and dead weight.
- [x] **HL-52 · 2026-09-05** — Rebooted; `log2ram` live.
- [x] **HL-51 · 2026-09-05** — Pi hardening: `unattended-upgrades`, `fail2ban`, `log2ram`.
- [x] **HL-50 · 2026-09-04** — Scheduled backups via launchd (later reversed, [ADR 0006](decisions/0006-backups-are-deliberately-modest.md)).
- [x] **HL-01 · 2026-09-04** — `1.1.1.1` as DHCP secondary tried and reverted ([ADR 0005](decisions/0005-single-filtering-resolver.md)).
- [x] **HL-03 · 2026-09-04** — SD-card wear risk accepted: high-endurance card plus backups.
- [x] **HL-05 · 2026-09-04** — Windows Server licence confirmed genuine (since wiped).
- [x] **HL-43 · 2026-09-04** — `pi` added to the `unifi` group; `backup.sh` needs no sudo.
- [x] **HL-46 · 2026-09-04** — Removed the stale pre-migration Pi-hole copy.
- [x] **HL-45 · 2026-09-04** — `scripts/sync-fallback.sh` keeps the emergency DNS copy in sync.
- [x] **HL-47 · 2026-09-04** — `wireguard` deploys from this repo; Portainer stays a local compose file.
- [x] **HL-48 · 2026-09-04** — WireGuard healthcheck runs `wg show wg0`.
- [x] **HL-29 · 2026-09-04** — Portainer deploys `network-core` from this repo.
- [x] **HL-44 · 2026-09-04** — Image tags pinned.
- [x] **HL-42 · 2026-09-04** — VPN clients use Pi-hole for DNS.
- [x] **HL-38 · 2026-09-04** — WireGuard keys added to `backup.sh`.
- [x] **HL-37 · 2026-09-04** — WireGuard deployed and verified from cellular.
- [x] **HL-40 · 2026-09-04** — Internet SSH forward to the Windows box deleted.
- [x] **HL-41 · 2026-09-04** — Failed logons were SSH brute force; resolved by HL-40.
- [x] **HL-25 · 2026-09-04** — Discovery answers written into `docs/`.
- [x] **HL-02 · 2026-09-04** — First backup pulled and verified restorable.
- [x] **HL-31 · 2026-09-04** — Kuma monitor check folded into HL-09.
- [x] **HL-28 · 2026-09-04** — Pi password changed; SSH key-only.
- [x] **HL-23 · 2026-09-04** — Discovery run on `enkidupi`; repo restructured to match.
- [x] **HL-17 · 2026-09-04** — Portainer compose file reconstructed.
- [x] **HL-22 · 2026-09-04** — ADR 0002 filled in from the real port allocation.
- [x] **HL-21 · 2026-09-04** — Pi-hole local DNS records documented.
- [x] **HL-04 · 2026-09-04** — Pi confirmed `aarch64`.
- [x] **HL-00 · 2026-09-04** — Repository created.
- [x] **HL-26 · 2026-09-04** — All open work consolidated into this file.
- [x] **HL-27 · 2026-09-04** — Discovery scripts written; [ADR 0003](decisions/0003-document-before-changing.md).
