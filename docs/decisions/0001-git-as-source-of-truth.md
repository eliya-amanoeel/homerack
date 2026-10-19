# 0001 — Git as the source of truth for the lab

**Date:** 2026-09-04
**Status:** accepted

## Context

The lab grew by hand: services were configured through Portainer and the Windows
GUI, and the only record of how anything works is in my head and in the running
machines. If the Pi's SD card dies, the configuration dies with it.

## Decision

This repository is the source of truth. Configuration is written here first and
applied to hosts, not the other way round. Anything that only exists on a host is
considered undocumented and at risk.

Concretely:
- Compose files live in `hosts/<host>/stacks/<service>/`
- Secrets stay out of git; `.env.example` documents what's needed
- Hardware, addressing and rationale live in `docs/`

## Consequences

- Rebuilding a host becomes a checklist rather than an archaeology exercise.
- Costs discipline: changes made ad-hoc in a web UI drift from the repo and must
  be reconciled. Portainer's "stack from git" feature can reduce this later.
- Doesn't back up *data* — only configuration. Backups are a separate problem
  (see [backlog](../backlog.md)).
