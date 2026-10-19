# 0003 — Document the current state before changing anything

**Date:** 2026-09-04
**Status:** accepted

## Context

After scaffolding the repo, the backlog held both documentation gaps and fixes
for real risks (no backups, single point of DNS failure, a possible dying SD
card). The tempting order is to fix the risks first, since they are the ones that
can bite.

But the repo currently describes a lab that does not quite exist: the compose
files under `hosts/enkidupi/` were written from scratch and have never been compared
against what actually runs. Changing the lab first means documenting a moving
target, and it means any fix is applied to a system nobody has an accurate
picture of.

Several "risk" items are also discovery in disguise — whether the Pi boots from
an SD card, whether the OS is 64-bit, whether the Windows install is an
evaluation. None can be fixed before they are answered.

## Decision

Complete a discovery pass before making changes. Two read-only scripts
(`scripts/discover-enkidupi.sh`, `scripts/discover-prodesk.ps1`) dump real host
state; their output fills in `docs/` and reconciles the compose files. Only then
do the Tier 1 fixes begin.

The one exception is anything that is both trivial and household-affecting —
HL-01, a secondary DNS entry in DHCP, is a single setting and need not wait.

## Consequences

- The first fixes are applied to a system that is actually understood, and the
  rebuild runbook becomes testable rather than hypothetical.
- Discovery output is scratch, not an artifact: it contains live credentials and
  is gitignored. The durable record is the edited `docs/`, not the dump.
- Costs a delay before any risk is reduced. Accepted because the risks are
  chronic rather than acute — nothing here is actively on fire.
