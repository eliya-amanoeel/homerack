# 0011 — `edge` stays on the cluster, not on the Pi

**Date:** 2026-09-28
**Status:** accepted

## Context
[ADR 0008](0008-site-hosting-pattern-on-proxmox.md) made `edge` a VM on
Proxmox but only compared options inside Proxmox. Running the public reverse
proxy on `kish` instead was never written down as an option, so the question
came up again while adding access logs to `edge` (HL-99).

## Decision
**`edge` stays a VM on the cluster.** Reasons:

1. **No extra dependency for the sites.** The sites run on the cluster. With
   `edge` there too, a public site depends on the router and the cluster. On the
   Pi, it would depend on the router, the Pi *and* the cluster.
2. **The Pi already carries the LAN.** It is the only DNS resolver and runs
   unifi, WireGuard and the cluster's quorum vote (ADR 0009). An internet-facing
   HTTP server is the part most likely to be attacked, and a compromise there
   would land on the box the whole network depends on. On the cluster it stays
   inside one VM with its own kernel.
3. **The cluster gives `edge` live migration between `anu` and `inanna`**, and
   it and its certificates are covered by the Proxmox backup job.

WireGuard being forwarded to the Pi is not a precedent: it is one UDP port that
does not answer unauthenticated packets, not a web server.

## Consequences
- The Pi's role stays LAN infrastructure; nothing public-facing beyond
  WireGuard is added to it.
- When the whole cluster is down, the sites have no fallback such as a
  maintenance page. That was the one thing the Pi would have offered, and it is
  accepted.
