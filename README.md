# homerack

Configuration and documentation for my 10" rack home lab. It has two halves: a
three-node **Proxmox** cluster, `uruk`, that hosts websites, and a Raspberry Pi,
**`kish`**, that runs the network around it. This repo is the single source of
truth for what hardware exists, what runs where, why it is built that way, how
to rebuild it, and what's next.

The public repo [`eliya-amanoeel/homerack`](https://github.com/eliya-amanoeel/homerack)
is generated from a private working repo, with the home's address and other
people's sites and details replaced by placeholders
([ADR 0016](docs/decisions/0016-public-copy-is-generated.md)).

## Proxmox: the cluster `uruk`

Three HP ProDesk minis, `anu`, `inanna` and `enlil`, running Proxmox VE 9.2 as
one cluster.

- **Guests are built from templates.** A Debian 13 LXC template and a VM
  template are the starting point for every guest. Each website gets its own
  LXC container, PostgreSQL gets another, and the public reverse proxy, `edge`,
  is a VM with its own kernel ([ADR 0008](docs/decisions/0008-site-hosting-pattern-on-proxmox.md)).
- **Quorum, learned the hard way.** As two nodes, one node down left the other
  unable to start, stop or migrate guests until someone ran `pvecm expected 1`.
  A QDevice on `kish` gave the cluster a third vote
  ([ADR 0009](docs/decisions/0009-cluster-quorum-via-qdevice-on-enkidupi.md)).
  When a third node joined, the QDevice was removed, as the Proxmox docs advise
  for an odd number of nodes ([ADR 0014](docs/decisions/0014-three-nodes-no-qdevice.md)).
  Now any one node can be down.
- **One web UI for all three nodes** at `https://uruk.lan`. Caddy on `kish`
  health-checks the nodes and fails over from `anu` to `inanna` to `enlil`.
- **Every guest is backed up daily** by one job covering all nodes, to an SSD
  separate from the guests' disks. The first restore was tested the day the
  job was set up ([anu's README](hosts/anu/README.md#storage)).
- **Live migration, but no automatic failover, on purpose.** Each node keeps
  its guests on a single disk, so storage is ext4 with LVM-thin rather than ZFS,
  and for these sites a restore from backup is acceptable downtime.
- **Nodes are reinstalled one at a time, without rebuilding the cluster.** Two
  were reinstalled and renamed this way. The procedure is in
  [anu's README](hosts/anu/README.md#reinstalling-a-node).
- **Watched from the Pi.** A Beszel agent on each node reports to the hub on
  `kish`, including CPU temperatures.

## `kish`: the Pi outside the cluster

The idea: everything the network needs runs on one small, always-on box that
does not depend on the cluster, and that the cluster does not depend on.

- **It runs the LAN.** Pi-hole is the only DNS resolver. WireGuard is the only
  way in from outside to the admin interfaces. Caddy, with its own internal CA,
  gives every admin UI a `.lan` name over HTTPS. Uptime Kuma and the Beszel hub
  watch the sites and the hosts, and the unifi controller manages the switch
  ([hosts/kish/](hosts/kish/README.md)).
- **It is never public-facing beyond WireGuard.** The public reverse proxy
  stays on the cluster, so an attack on a web server cannot land on the box the
  whole network depends on ([ADR 0011](docs/decisions/0011-edge-stays-on-the-cluster.md)).
- **It can be fixed with nothing but SSH.** Portainer sets its own DNS, so a
  Pi-hole outage cannot stop the redeploy that would fix it. Caddy and
  Portainer are plain compose projects outside Portainer
  ([ADR 0012](docs/decisions/0012-caddy-on-kish-stays-outside-portainer.md)),
  and a local copy of the DNS stack is the restore path when DNS is down
  ([the DNS outage runbook](docs/runbooks/dns-outage.md)).
- **It is out of the cluster's quorum.** Since the third node joined, a Pi
  outage costs the cluster nothing ([ADR 0014](docs/decisions/0014-three-nodes-no-qdevice.md)).
- **The name.** Kish was the first city of kingship in the Sumerian King List,
  and Uruk's rival, so the Pi is named for the city outside cluster `uruk`. The
  nodes are named after Sumerian gods, and the NAS after Nergal.

## The rack

| Host | Hardware | Role | OS |
|---|---|---|---|
| `kish` | Raspberry Pi 4B rev 1.5, 4 GB | Pi-hole, Uptime Kuma, Portainer, unifi controller, WireGuard, Beszel hub, Caddy for the `.lan` UIs | Debian 13 (trixie), aarch64 |
| `anu` | HP ProDesk 400 G2 | Hypervisor, cluster `uruk` — runs amaeli and site-a; was `pve1` ([HL-77](docs/backlog.md)) | Proxmox VE 9.2 |
| `inanna` | HP ProDesk 400 G2 | Hypervisor, cluster `uruk` — runs edge, site-b and postgres; was `pve2`, before that `prodesk` (Windows, IIS) | Proxmox VE 9.2 |
| `enlil` | HP ProDesk 600 G2 | Hypervisor, cluster `uruk` — third node since 2026-10-12, no guests yet ([HL-104](docs/backlog.md)) | Proxmox VE 9.2 |
| `USW-Lite-8-PoE` | unifi Lite 8 PoE | Switching + PoE | unifi firmware |
| `hue-bridge` | Philips Hue Bridge | Zigbee lighting | vendor firmware |

The rack itself is 3D-printed, 8U. Outside it: a TP-Link Deco XE75 mesh as the
router, and a Synology DS420+ NAS, `nergal`.

Details in [docs/inventory.md](docs/inventory.md) · addressing in [docs/network.md](docs/network.md) · coming from Windows? [docs/windows-to-linux.md](docs/windows-to-linux.md).

Hardware and services verified against the live hosts, last on 2026-10-17.

## Also here

- **Websites served from home.** `edge` takes all public traffic on 80/443 and
  gets the Let's Encrypt certificates. GitHub Actions deploys each site through
  a self-hosted runner in its container
  ([ADR 0008](docs/decisions/0008-site-hosting-pattern-on-proxmox.md)).
- **Off Windows.** The sites moved from Windows Server and IIS to the Proxmox
  cluster one at a time, with the reasoning in
  [ADR 0007](docs/decisions/0007-leave-windows-for-proxmox.md) and a translation
  guide in [docs/windows-to-linux.md](docs/windows-to-linux.md).
- **A small attack surface.** Only 80, 443 and WireGuard are reachable from the
  internet, re-checked from outside. The admin interfaces are reached from home
  or over WireGuard only ([ADR 0004](docs/decisions/0004-remote-access-via-wireguard.md),
  [ADR 0013](docs/decisions/0013-nas-reached-only-from-home-or-wireguard.md)).
- **Decisions are written down.** Every non-obvious choice has an ADR in
  [docs/decisions/](docs/decisions/), including the ones that reversed an earlier
  decision.
- **Runbooks for what breaks**, in [docs/runbooks/](docs/runbooks/): a DNS
  outage, a rebuild of the Pi, a manual backup, and adding a new site.
- **The docs are checked, not trusted.** A pre-commit hook blocks credentials
  and runs [scripts/check-docs.sh](scripts/check-docs.sh), and the docs are
  audited against the live hosts.

## Tech stack

Proxmox VE (LXC, VM, three-node cluster) · Debian · Docker and Portainer · Caddy ·
Pi-hole v6 · WireGuard · Uptime Kuma · Beszel · GoAccess · unifi · GitHub Actions ·
Bash

## Layout

```
docs/          inventory, network map, decisions, runbooks, backlog
hosts/         per-host config — the thing you'd restore from
scripts/       helper scripts (backup, hardening, doc checks, the public export)
```

## What's next

All open work is tracked in **[docs/backlog.md](docs/backlog.md)** — one file,
stable IDs, grouped by urgency. Start there.

## Setup after cloning

```bash
git config core.hooksPath .githooks
```

Enables the pre-commit hook that blocks credentials from being committed. Git
does not carry this setting across clones, so it must be run once per clone.

## Conventions

- **Every service lives under a host.** `hosts/<host>/stacks/<service>/`
- **Secrets never land in git.** Compose files reference `.env`; only
  `.env.example` is committed. Credentials live in [secrets/](secrets/), which is
  gitignored and guarded by a pre-commit hook.
- **Non-obvious choices get an ADR** in `docs/decisions/`.
- **Anything that would page you at 2am gets a runbook** in `docs/runbooks/`.
- **Open work goes in `docs/backlog.md`**, not scattered `TODO`s. A `TODO` in a
  file is a blank to fill in; a backlog item is a task to do.

## Restoring from scratch

See [docs/runbooks/rebuild-kish.md](docs/runbooks/rebuild-kish.md) — untested, see HL-07.

## Built with Claude Code

The lab was planned, built and documented together with
[Claude Code](https://claude.com/claude-code), which works from
[CLAUDE.md](CLAUDE.md) and co-authors the commits. I make the decisions,
approve each change before it is committed, and do the hands-on work in the
rack.

## License

Released under the [MIT License](LICENSE), © 2026 Eliya Amanoeel.
