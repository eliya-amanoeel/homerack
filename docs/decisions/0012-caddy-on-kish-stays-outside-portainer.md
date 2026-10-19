# 0012 — Caddy on `kish` stays outside Portainer

**Date:** 2026-09-28 (decided 2026-09-22 under HL-82)
**Status:** accepted

## Context

Most stacks on `kish` are Portainer git stacks deployed from this repo. Caddy,
which serves every `.lan` admin UI, is not: it is a compose project in
`~/stacks/caddy/` owned by `pi`, which Portainer only discovered and lists as
**Limited** (no *Pull and redeploy*). HL-82 first recorded this as a fourth,
undocumented deployment method. It is the same method Portainer itself uses
(`~/stacks/portainer/`), so there are three, not four: Portainer git stacks,
local compose projects, and native apt packages.

The question was whether to convert Caddy into a git stack for uniformity.

## Decision

**Caddy stays a local compose project, deployed over SSH.**

Portainer's UI is bound to `127.0.0.1` (HL-33), so `portainer.lan` through Caddy
is the only normal route to it. A Portainer-managed Caddy would close a loop: a
bad Caddyfile takes down the UI you would deploy the fix from. Being deployable
with nothing but SSH is the point, the same defence as Portainer setting its own
`dns:` and as the `network-core` fallback copy (HL-45).

Deployment is the three commands in the
[caddy README](../../hosts/kish/stacks/caddy/README.md): back up, `scp`,
validate and `docker restart caddy` (`admin off` means `caddy reload` cannot
work). A wrapper script was considered and not written; three commands do not
need one.

## Consequences

- "Limited" in Portainer is expected for `caddy`, as for `portainer`.
- The Pi's copy must be kept equal to the repo by hand; compare checksums when
  in doubt.
- **If this is ever reconsidered:** the compose project name sets the volume
  prefix, so recreating it under any name but `caddy` starts with empty volumes,
  a new internal CA and a re-trust on every device. The conversion also needs
  `compose down` first, which cuts the route to Portainer — use
  `ssh -L 9000:127.0.0.1:9000` meanwhile.
