# 0009 — Cluster quorum via a QDevice on enkidupi

**Date:** 2026-09-18
**Status:** superseded by [0014](0014-three-nodes-no-qdevice.md) (2026-10-12)

## Context

Cluster `uruk` has two nodes, `pve1` and `pve2`, one vote each. Quorum needs a
majority, and one vote of two is not one. So whenever either node was down, the
other could not start, stop, create or migrate guests until someone ran
`pvecm expected 1` by hand. Running guests were unaffected. This showed up
during pve2's first reboot, the same day the cluster was formed.

That hits hardest when a node dies and its guests should be started on the other
node, which is the reason for having two nodes at all.

The fix is a third vote from something that is not a hypervisor. There were two
places to put it:

- **enkidupi** — `corosync-qnetd` is a small native Debian package, available
  for arm64.
- **The Synology NAS** — it would have to run in Container Manager under DSM, a
  less standard setup that DSM updates can disturb.

The objection to the Pi was coupling: it is already the LAN's only DNS resolver
and runs the rest of the management stack. That objection is weaker than it
looks. The QDevice only matters when a node is already down. With both nodes
up they hold 2 of 3 votes, so the Pi being down costs nothing.

## Decision

Run the QDevice on `enkidupi`: `corosync-qnetd` from apt, and
`corosync-qdevice` on both nodes, set up with
`pvecm qdevice setup 192.168.68.71` from pve1.

The setup needs root SSH to the Pi, which is normally off (`PermitRootLogin no`).
It was opened only for the setup: pve1's key in `/root/.ssh/authorized_keys`, a
`00-qdevice-temp.conf` drop-in with `PermitRootLogin prohibit-password` (numbered
`00` because sshd uses the first match), then both removed. Confirmed
`permitrootlogin no` with `sshd -T` afterwards.

## Consequences

- **Three votes, quorum two.** Either node, or the Pi, can be down and the
  cluster stays fully usable. Two of the three down at once and it goes
  read-only, as before.
- **A new service on the Pi**: `corosync-qnetd`, TCP **5403**, listening on all
  interfaces. It is not forwarded from the internet. Its certificates live in
  `/etc/corosync/qnetd/nssdb`, on the nodes in `/etc/corosync/qdevice/net/nssdb`.
- **It is a native apt package**, like the unifi Network Application, not a
  container. It is not part of any compose stack and Portainer does not see it.
- **Rebuilding the Pi** means redoing the setup: install `corosync-qnetd`, open
  root SSH temporarily as above, then run `pvecm qdevice remove` and
  `pvecm qdevice setup 192.168.68.71` from a node. Until then the cluster just
  has two votes again.
- **Removing or reinstalling a node** means removing the QDevice first, as
  Proxmox requires, so the remaining node loses quorum while the other is down
  until `pvecm expected 1`. Done this way when pve1 was reinstalled as `anu` on
  2026-09-24, and again when pve2 became `inanna` the same evening; the setup
  was rerun from anu both times. Steps in
  [anu's README](../../hosts/anu/README.md#reinstalling-a-node).
- **Adding a third Proxmox node** gives an odd number of nodes, and a QDevice
  should then be removed. Proxmox refuses to set one up on an odd-sized cluster.
