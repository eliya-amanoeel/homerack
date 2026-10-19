# 0016 — The public copy is generated from this repo

**Date:** 2026-10-19
**Status:** accepted

## Context
The owner wants to show the lab publicly. Making this repo public would
publish its whole history, not just today's files. A
read-only audit on 2026-10-19 (gitleaks plus pattern scans over all 223
commits) found no secrets, but it did find the home's public IP, other people's
sites and addresses, every MAC address, and a since-deleted brief that belongs
in a private repo only. Removing those from history means
rewriting every commit, which breaks every clone (Portainer's included). And
one miss cannot be taken back once the repo is public.

## Decision
This repo stays private and stays the only one edited
([ADR 0001](0001-git-as-source-of-truth.md) still holds). A separate public repo
is generated from it by `scripts/export-public.sh`:

- **It exports the committed `HEAD`,** as one `Snapshot <date>` commit in the
  public repo per export. No history is carried over.
- **Redactions are listed in `scripts/export-public/redactions.tsv`,** the one
  file that is never exported:
  - the home's public IPs become documentation addresses (`203.0.113.x`)
  - hosted sites other than amaeli become `site-a`/`site-b` on `.example`
  - two paused engagements are dropped entirely, and a `!BLOCK` entry refuses
    any new mention of them
  - MAC addresses are blanked
- **Private IPs stay.** They show the design and cannot be reached from outside.
- **The export is refused** if a mapped value, a MAC, or a public IP or domain
  missing from `allowlist.txt` is left, or if gitleaks finds anything.
- **Publishing stays manual.** The owner reviews the diff and pushes by hand,
  with the GitHub noreply address as the commit email. There is no automation:
  the review is the safety net.

## Consequences
- Day-to-day work does not change. Portainer deploys from this repo and never
  sees the public one.
- The public repo shows snapshots, not the working history.
- A new public name, such as a domain or a DDNS host, blocks the export until it
  is mapped or allowed. That is the main upkeep.
- The checks match strings. They cannot judge meaning, so prose that identifies
  a site without naming it passes. The diff review catches that, or nothing does.
- Accepted on 2026-10-19: a reader who finds the owner's other public repos may
  match an anonymised site to one of them.
