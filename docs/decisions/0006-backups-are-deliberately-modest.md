# 0006 — Backups are deliberately modest

**Date:** 2026-09-04
**Status:** accepted

## Context

Work was underway to run `restic` on the Pi, backing up to encrypted Backblaze
B2 storage nightly. Before setting up the account, the obvious question got
asked: what is actually being protected?

Adding it up honestly:

| Data | If lost | Real cost |
|---|---|---|
| Compose files, docs | — | nothing, they are in this repo |
| Pi-hole blocklists (24 MB of every archive) | regenerated on demand | nothing |
| Local DNS records | documented in `network.md` | retype 7 lines |
| Uptime Kuma database | recreate from `monitors.md` | ~15 minutes |
| WireGuard keys | reissue 2 client configs | ~10 minutes |
| unifi controller | re-adopt the switch, redo settings | ~30 minutes |
| Portainer database | stacks are in git; recreate the account | ~15 minutes |
| Websites on `prodesk` | **all in their own git repos** | nothing |
| Let's Encrypt certs | auto-renew | nothing |

Total loss of the Pi costs roughly **an hour**, following
[rebuild-enkidupi.md](../runbooks/rebuild-kish.md).

*Revised 2026-09-05:* Kuma's database was empty when this was written and is no
longer — it now holds four monitors and a notification channel (HL-09). Every
one of them is written down in
[monitors.md](../../hosts/kish/stacks/network-core/monitors.md), so the cost
of losing it is re-entering them, not losing them. The conclusion is unchanged;
the row above is corrected because a decision resting on a stale figure is worse
than no decision at all.

An encrypted off-site pipeline is not proportionate to an hour of rebuilding. It
would add a cloud account, a monthly bill, and a repository password whose loss
makes every backup permanently unreadable — a new single point of failure, in
exchange for protecting data that mostly regenerates itself.

## Decision

Keep the existing arrangement and go no further:

- `scripts/backup.sh` is run **by hand** when wanted, pulling the
  non-reproducible bits off the Pi to the Mac. Free, no accounts, no key to
  lose, nothing scheduled. See [the backup runbook](../runbooks/manual-backup.md).
- No `restic`, no cloud storage, no off-site copy, no background job.
- HL-14 is closed as **not worth doing**, rather than left open as a permanent
  reproach.

## Consequences

- A fire or theft taking both the flat and the laptop loses the lab's state. The
  websites and all configuration survive in GitHub, so what is actually lost is
  an hour of setup — accepted.
- Backups happen only when you remember. Given that they protect about an hour
  of rebuilding, that is an accepted risk rather than a gap to close. A
  `launchd` agent was set up and then deliberately removed; git history has it
  if the calculation ever changes.
- **This decision depends on things staying reproducible.** It should be
  revisited if the lab ever holds data that exists nowhere else: photos, a media
  library, documents, a database behind one of the sites, or Home Assistant
  history. At that point the calculation changes completely and the restic plan
  is the right answer.
- One gap stays worth closing cheaply: `prodesk`'s IIS configuration (bindings,
  app pools, site paths) is the only part of the lab that is neither in a repo
  nor quickly reconstructed. A few KB of `appcmd` export — see HL-20.
