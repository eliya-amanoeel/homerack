# 0005 — One resolver, and it filters

**Date:** 2026-09-04
**Status:** accepted (supersedes the approach taken in HL-01)

## Context

`enkidupi` was the LAN's only DNS server, so rebooting it took the household's
internet with it. HL-01 addressed that by handing out `1.1.1.1` as a secondary
resolver in DHCP.

Testing showed the fix was worse than advertised. Clients do not treat resolvers
as an ordered list — they query whichever answers, and fail over eagerly. So any
query landing on the secondary skipped Pi-hole entirely: no ad-blocking, and no
`.lan` names. Verified directly:

```
enkidupi.lan     via 1.1.1.1  ->  (no answer)
doubleclick.net  via 1.1.1.1  ->  216.58.201.206   (not blocked)
```

The failure is silent. Ads appear sometimes; a `.lan` name fails once and works
on retry. That is a bad class of bug — it looks like a broken Pi-hole and isn't.

## Decision

Removed the public secondary. `enkidupi` is again the only resolver, and every
query is filtered.

This chooses **consistency over availability**, the opposite of HL-01. The Pi
going down means the house has no DNS until it returns or someone sets a
resolver by hand.

## Consequences

- Ad-blocking and `.lan` names work every time, or not at all — no intermittent
  behaviour to misdiagnose.
- `enkidupi` is a single point of failure for DNS again, and it is now also the
  WireGuard endpoint and the monitoring host. Its SD card matters (HL-03).
- The manual escape hatch stands: set a device's DNS to `1.1.1.1` to get online
  during an outage. See [the DNS outage runbook](../runbooks/dns-outage.md).
- The version without a trade-off is a **second Pi-hole** as the secondary —
  availability *and* filtering. `prodesk-spare` is idle and could host it (HL-49,
  and a candidate answer to HL-08). Until then this is a knowing compromise, not
  an oversight.
