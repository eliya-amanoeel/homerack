# 0008 — Site hosting pattern on Proxmox: edge VM, one LXC per site, no Docker

**Date:** 2026-09-17
**Status:** accepted

## Context

[ADR 0007](0007-leave-windows-for-proxmox.md) moves the five sites off Windows
onto Proxmox. HL-69 confirmed all five run on Linux: three static builds
(amaeli and two sites since taken down), one static build with a .NET Framework handler
to replace (SiteA, HL-71), and one Blazor app on modern .NET with PostgreSQL
(SiteB).

Proxmox will run for years, so the deciding requirement is **one consistent
pattern** for every site — so that backups, updates, deployments and adding the
next site are the same routine each time. Three questions had to be settled:

1. **How public traffic reaches sites** while they move one at a time. There is
   one public IP, and the router forwards 80/443 to `prodesk`.
2. **What each site runs in.** Proxmox offers VMs (own kernel, strongest
   isolation, live migration) and LXC system containers (share the host kernel,
   very light). Docker would need one of the two underneath.
3. **How sites are built and deployed.** Today each repo has a GitHub workflow
   on a self-hosted runner on `prodesk` that runs `npm ci`, builds, and
   `robocopy`s into IIS.

Research behind the choices:

- The [Proxmox documentation](https://pve.proxmox.com/wiki/Linux_Container)
  recommends a **VM** for Docker-style application containers where isolation
  and live migration matter. A
  [widely read r/selfhosted thread](https://www.reddit.com/r/selfhosted/comments/1k3hzs1/proxmox_lxc_containers_vs_virtual_machines_for/)
  shows the real-world split: Docker inside LXC works for many, but Proxmox
  updates have broken it for others, and the shared kernel is the recurring
  security objection. The breakage reports are about **Docker inside LXC** and do
  not apply to software installed directly in the container (`apt install caddy`,
  no Docker). The **shared-kernel objection applies to every LXC container**,
  with or without Docker — which is why the internet-facing guest below is a VM.
- Community guidance puts **reverse proxies, DNS and lightweight services in
  LXC**, and anything running Docker in a VM.
- [GitHub's hardening guidance](https://docs.github.com/en/actions/reference/security/secure-use)
  says self-hosted runners "can be persistently compromised by untrusted code in
  a workflow" and that sensitive material on runner machines should be minimal.
  Running `npm ci` on the production host is exactly that exposure.

Options considered: all LXC without Docker; one Docker VM for all sites (the
Pi's model, and closest to local Docker Desktop use); Docker inside LXC
(rejected — fragile on Proxmox upgrades and not recommended); and a hybrid.

## Decision

**An edge proxy in a VM, one LXC container per site, no Docker. Sites are built
on GitHub and deployed by a thin self-hosted runner.**

```
internet → router 80/443 → edge (VM, Caddy)
                            ├─ migrated site  → its LXC container (Caddy on :80)
                            └─ not yet moved  → prodesk (IIS)
```

- **`edge` is a Debian VM running only Caddy.** It receives all public 80/443
  traffic, holds the Let's Encrypt certificates, and routes by hostname. It gets
  a VM because it is the one guest facing the internet — the thread's
  shared-kernel objection is taken seriously exactly where it matters — and
  because a VM can **live-migrate**, which matters most for the single entry
  point.
- **Every site is its own Debian LXC container**, unprivileged, with Caddy on
  port 80 serving `/var/www/<site>` (or proxying to a systemd service in
  `/opt/<site>` for .NET). No certificates, no public exposure.
- **PostgreSQL gets its own LXC container.** SiteB reaches it over the LAN.
- **Build on GitHub-hosted runners, deploy with a thin runner.** The workflow
  builds on a clean GitHub machine and uploads the output as an artifact. A
  self-hosted runner inside the site's container — labelled
  `[self-hosted, linux]` — only downloads that artifact and `rsync`s it into
  place. No Node or npm on any server.
- **Addressing:** guests take static IPs from `192.168.68.20`–`.49`, below the
  Deco's DHCP pool ([network.md](../network.md)). `edge` is `.20`, `amaeli` is
  `.21`.
- **Cutover:** the 80/443 forward moves from `prodesk` to `edge` once, when the
  first site moves. After that, moving a site is one Caddyfile change on `edge`.
  Rollback is pointing the forward and Pi-hole's split-horizon records back at
  `.57`; IIS stays untouched until the last site has left.

## Consequences

**Easier.**

- **Backups:** one Proxmox job covers every guest, and each site restores on its
  own. Edge's certificates are inside its backup.
- **Migration between nodes:** `edge` live-migrates with no downtime even
  without shared storage. Site containers restart-migrate with a few seconds of
  downtime each, which is acceptable.
- **Deployments** keep today's shape — "Run workflow" in GitHub — but npm code
  never executes on the servers.
- **Adding a site** is: clone the LXC template, drop in its files, add a runner,
  add one block to `edge`'s Caddyfile. The same for all five.
- No Docker layer to break on a Proxmox upgrade, and no image registry to run.
- Certificates are handled by Caddy; `win-acme` goes away with the last site.

**Harder, or newly owed.**

- **Two guest types** (VM and LXC) means two templates to build and keep
  current. The price of the extra isolation on `edge`.
- **Guest count grows to about seven** (edge, five sites, PostgreSQL), each
  patched separately. **`unattended-upgrades` in every guest is required, not
  optional.** The edge VM has its own kernel and needs its own reboots; LXC
  containers get their kernel with Proxmox.
- **Uniformity has to be enforced.** Every guest comes from a template and
  follows a runbook for adding a site, written while doing amaeli. Hand-built
  one-offs are how this pattern decays. If drift appears anyway, that is the
  point to bring in Ansible (as HL-13 already proposes for the Pi).
- The **edge VM needs the QEMU guest agent** so snapshot-mode backups are
  consistent while it runs.
- **SiteB's database needs `pg_dump`** inside its container as well — a
  snapshot of a running database is not a guaranteed-consistent backup.
- `edge` is still a single entry point: if it is down, every public site is.
  Live migration covers planned maintenance, not a crash. This matches the risk
  `prodesk` carries today.
- **Memory is tight until the RAM upgrade:** roughly 1 GB for `edge`, ~256 MB
  per static site, 1–2 GB for SiteB plus PostgreSQL, on 8 GB today.
- **Five runners** to register, one per site repo. They update themselves.
- Each workflow must change: `runs-on` gains the `linux` label, the build job
  moves to `ubuntu-latest`, and `robocopy` becomes `rsync`. Until then, an
  unlabelled `runs-on: self-hosted` could land on either the Windows or the Linux
  runner.
- Brief certificate errors (seconds) are expected at the first cutover, because
  Let's Encrypt can only validate `edge` once port 80 reaches it.
