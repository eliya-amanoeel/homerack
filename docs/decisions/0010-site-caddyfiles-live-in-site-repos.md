# 0010 — Site Caddyfiles live in the site repos; edge's lives here

**Date:** 2026-09-25
**Status:** accepted

## Context

[ADR 0008](0008-site-hosting-pattern-on-proxmox.md) gives every site its own LXC
container with Caddy on port 80, behind Caddy on `edge`. amaeli moved first, and
its Caddyfile went into this repo at `hosts/amaeli/`. site-a and SiteB
moved later, and theirs went into their own repos at `deploy/Caddyfile`, next to
their systemd units. So the Caddyfiles were split between two places with no
rule for which went where.

## Decision

**Each site's Caddyfile lives in that site's repo at `deploy/Caddyfile`. `edge`'s
Caddyfile stays in this repo at `hosts/edge/`.**

A site's Caddyfile follows the app: whether it needs `try_files` (client-side
routing), which paths can be cached forever (the build's hashed output), and
proxying to the app's own service all change when the site's code changes. Kept
in the same repo, they change in the same commit. `edge`'s Caddyfile maps
hostnames to guest IPs. That is knowledge about the lab, which no single site
owns.

## Consequences

- A site change and the Caddy change it needs are one commit and one review.
- Adding a site means a `deploy/` folder in its repo, not files here.
  [add-a-site.md](../runbooks/add-a-site.md) step 4 says so.
- This repo no longer shows every guest's web config in one place. A guest's
  README points to the site's repo instead.
- Deploying a Caddyfile is still by hand (`scp`, validate, reload). The
  workflows deploy only the build.
