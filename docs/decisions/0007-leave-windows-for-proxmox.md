# 0007 — Leave Windows entirely; both ProDesks become Proxmox hosts

**Date:** 2026-09-07
**Status:** accepted

## Context

`prodesk` runs Windows Server 2022 on bare metal and serves five public
websites under IIS, with PostgreSQL behind one of them and `win-acme` renewing
the certificates. `prodesk-spare` sat empty with no OS.

HL-08 previously recorded the goal as "run both ProDesks as Proxmox hosts" and
assumed the Windows install would survive as a **P2V** guest. That framing was
wrong about the intent: the goal is to stop running Windows at all, not to
virtualise it.

The two machines turned out to be the **same platform** — both HP ProDesk 400 G2
**MINI**, SODIMM memory on a socketed LGA1151 board. `prodesk-spare` has been
brought up to match `prodesk` exactly (i7-6700T, 16 GB) and has a larger disk,
so it can carry the full workload during a migration.

## Decision

**Move off Windows entirely.** Rebuild the five sites on Linux guests under
Proxmox VE rather than migrating the Windows install.

- `prodesk-spare` gets Proxmox first, while `prodesk` keeps serving live traffic.
- The sites are rebuilt there from their own git repos; SiteB's database
  comes across as a `pg_dump`/restore.
- Cutover is a single change of the 80/443 forwards, made only after the
  rebuilt sites are verified on the LAN.
- `prodesk` is then wiped and becomes the second Proxmox host.
- **Proxmox is installed on ext4/LVM, not ZFS.** On a single SSD, ZFS spends RAM
  on checksumming that cannot self-heal without redundancy, and LVM-thin already
  provides the snapshots we would actually use.

**This decision is conditional on the sites being portable.** If any turns out
to be ASP.NET *Framework*, it cannot run on Linux at all and this ADR must be
revisited — that site would need porting to .NET 8 or staying on Windows.

## Consequences

**Easier.**

- `win-acme` disappears. Caddy — already understood here from HL-11 — handles
  Let's Encrypt automatically, so the scheduled task, its `LastResult` checks and
  the three-step dance to add a hostname all go away.
- Manual Windows patching (a deliberate choice on `prodesk`, but a standing
  chore) is replaced by `unattended-upgrades`, as on `enkidupi` under HL-51.
- The whole lab becomes Debian, which is one operating system to know.
- Much lower risk than a P2V: the new stack is built and tested alongside the
  old one, and the live sites keep serving from an untouched machine until the
  moment of cutover.
- The Windows Server licence stops being on the critical path. It is still worth
  recording under HL-56, since it is a retail licence we own.

**Harder, or newly owed.**

- The sites must actually be portable. This is the one assumption that can
  invalidate the plan, and it is checked before any of it starts.
- Two-node Proxmox clusters have a **quorum problem**: with two votes, either
  node failing leaves the survivor without quorum and its cluster read-only.
  Fixing it means a QDevice — `corosync-qnetd` — on a third always-on host.
  `enkidupi` is the obvious candidate, at the cost of coupling the hypervisors
  to the Pi that is already the LAN's only resolver. Alternative: run the two
  nodes standalone and move guests by backup/restore, giving up live migration.
- The cutover window is real. Certificates are issued over HTTP-01, so the
  forwards and DNS must land in the right order or issuance fails.
- Clustering has an ordering constraint: **a node joining a cluster must have no
  guests.** So the spare, which will hold the sites, must be the node that
  *creates* the cluster; `prodesk` joins it afterwards while empty.
