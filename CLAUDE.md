# homelab

Configuration-as-code for a 10" rack home lab. See [README.md](README.md) for the
hardware table and layout.

## Tracking work

**[docs/backlog.md](docs/backlog.md) is the single tracker.** Every open item
lives there with a stable `HL-NN` id, grouped into tiers by urgency. When work is
finished, tick the box and move the item to the Done section as **one line** (id,
date, what) — do not delete it. Detail worth keeping goes into the host README,
a runbook or an ADR; the rest stays in git history. Reference ids in commit messages (`HL-06: reconcile ...`).

`TODO` markers in other files are blanks awaiting a value, and are indexed in the
backlog's "Documentation gaps" section rather than tracked individually.

## Working in this repo

- **Config lives under `hosts/<host>/`.** Docker services are compose stacks in
  `hosts/kish/stacks/<service>/`.
- **Never commit secrets.** Compose files read from `.env`; commit only
  `.env.example` with placeholder values.
- **Service runtime data is gitignored** (`hosts/*/stacks/*/data/`). It's backed
  up by `scripts/backup.sh`, not by git.
- **When a non-obvious choice is made**, add an ADR in `docs/decisions/` using
  the template in that directory's README.
- **When something breaks and gets fixed**, consider whether it needs a runbook
  in `docs/runbooks/`.
- **Keep `docs/network.md` current.** IPs and ports drift; a stale network map is
  worse than none.
- **A public copy is generated from this repo** by `scripts/export-public.sh`
  (ADR 0016). Never edit the public repo. When an export is blocked, map the new
  value in `scripts/export-public/redactions.tsv` or allow it in `allowlist.txt`,
  and decide which one with the owner. The clone is `~/homerack`; the steps are
  in `scripts/README.md`. Personal details (home devices, accounts) stay out of
  the public copy: put them between private markers, as described there.

## Caveats

- **Names:** the Pi is `kish` (was `enkidupi` until 2026-09-24), the Proxmox
  nodes `anu` and `inanna` (were `pve1`, `pve2`) and `enlil` (since 2026-10-12), the cluster UI `uruk.lan`, the NAS `nergal` (was `EnkiduCloud` until
  2026-09-25), the switch `USW-Lite-8-PoE`, its name in unifi (`switch-01` in
  these docs until 2026-10-17).
  ADRs keep the names of their day. Hosts are reached by `.lan` name or IP,
  never `.local`.
- `kish` is ARM64 (aarch64), Debian 13. Image tags need `linux/arm64` variants.
- **Three deployment methods coexist on the Pi**, and confusing them wastes time:
  1. **Portainer git stacks** deployed from this repo: `network-core` (Pi-hole
     and Uptime Kuma), `wireguard`, `beszel`.
  2. **Local compose projects** in `~/stacks/<name>/`, applied over SSH:
     Portainer itself and Caddy (ADR 0012). Portainer lists both as "Limited".
  3. **Native apt packages**: the unifi Network Application. (`corosync-qnetd`,
     the cluster's old third vote, was removed 2026-10-12 — ADR 0014.)
- **Git stacks deploy from this repo** (HL-29). Editing a compose file here and
  pushing, then "Pull and redeploy" in Portainer, is how such a stack changes.
  Polling is off, so a push alone does not deploy.
- **Pi-hole's data lives at `/opt/homelab/network-core/`** with absolute binds.
  Never make those paths relative: a git stack is cloned to a new directory each
  deploy, so Pi-hole would start with an empty config.
- **Portainer sets its own `dns:`** so it does not depend on Pi-hole. Without
  that, a `network-core` outage leaves Portainer unable to resolve github.com to
  redeploy the stack that would fix it.
- `kish` is the only DNS resolver on the LAN, and resolves through itself.
  Changes to the `network-core` stack have blast radius beyond the lab.
- `sudo` on the Pi needs a password, but `timestamp_type=global` means one
  authenticated session unlocks it for all `pi` sessions until it expires.
  Portainer's stack data is root-owned.
- SSH on the Pi is key-only. sshd drop-ins are **first-match-wins** and
  cloud-init's `50-` file sets `PasswordAuthentication yes`, so ours is `01-`.
  Always confirm with `sudo sshd -T`, never by reading the file.
- Pi-hole is v6: config lives in `/etc/pihole/pihole.toml`, not env vars, and
  `custom.list` is generated — never edit it.
