# 0014 — Three nodes, no QDevice

**Date:** 2026-10-12 (HL-104)
**Status:** accepted — supersedes [0009](0009-cluster-quorum-via-qdevice-on-enkidupi.md)

## Context

ADR 0009 gave the two-node cluster `uruk` a third vote: `corosync-qnetd` on
`kish`, so either node could be down without the other losing quorum.

On 2026-10-12 a third node, `enlil`, joined. Proxmox requires the QDevice to be
removed before a node is added, so it was removed first. The question was
whether to set it up again afterwards.

The [Proxmox Cluster Manager docs](https://pve.proxmox.com/wiki/Cluster_Manager)
support a QDevice for an even number of nodes, and for an odd number "currently
discourage the use of QDevices". With an odd count the QDevice gets N−1 votes,
and "if the QNet daemon itself fails, no other node may fail or the cluster
immediately loses quorum".

Three nodes already give what the QDevice gave two: one vote each, quorum two,
so any one node can be down.

## Decision

No QDevice. Removed everywhere on 2026-10-12, with the cluster quorate
throughout:

- `pvecm qdevice remove` on anu; `/etc/pve/corosync.conf` has no `device`
  section
- `corosync-qdevice` disabled and purged on anu and inanna (enlil never had it)
- `corosync-qnetd` purged from kish: nothing listens on 5403, `/etc/corosync`
  is gone

Keeping `corosync-qnetd` installed but idle on kish, ready for a return to two
nodes, was considered and turned down: an unused service and an open port on
the Pi, to save about ten minutes of setup that may never be needed.

## Consequences

- **Three votes, quorum two.** Any one node can be down and the cluster stays
  fully usable; two down and it goes read-only.
- **kish is out of the cluster's quorum.** A Pi outage costs the cluster
  nothing, and the Pi has one service and one port fewer.
- **`pvecm status` showed a `Qdevice (votes 0)` row** afterwards. It counted
  for nothing, survived anu's reboot, and cleared when inanna rebooted the same
  evening (HL-105): it lasts until every node that knew the QDevice has
  restarted corosync.
- **Reinstalling a node no longer costs quorum.** The other two keep 2 of 3
  votes, so `pvecm expected 1` is no longer needed. Steps in
  [anu's README](../../hosts/anu/README.md#reinstalling-a-node).
- **If the cluster ever drops back to two nodes**, it needs a QDevice again:
  redo ADR 0009's setup — the steps were in
  [rebuild-kish.md](../runbooks/rebuild-kish.md) section 10 until this change
  (`git log -S corosync-qnetd -- docs/runbooks/rebuild-kish.md`).
