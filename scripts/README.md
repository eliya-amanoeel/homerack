# Scripts

Keep them small and readable — a script you don't trust at 2am is worse than no
script.

| Script | What it does | Safe? |
|---|---|---|
| `discover-kish.sh` | Dumps the Pi's real state for filling in docs | read-only |
| `backup.sh` | Pulls non-reproducible data off the Pi | read-only on the Pi |
| `check-docs.sh` | Verifies the backlog and links are consistent | read-only |
| `harden-kish.sh` | Installs unattended-upgrades, fail2ban, log2ram | changes the Pi (sudo) |
| `sync-fallback.sh` | Refreshes the emergency DNS restore copy on the Pi | writes one file |
| `export-public.sh` | Builds the redacted public copy of this repo | replaces the target folder, never pushes |

## Backups are manual, on purpose

Run `./scripts/backup.sh` when you want one — see
[the backup runbook](../docs/runbooks/manual-backup.md) for when that is worth
doing. Retention: the newest 3 backups are kept (`HOMELAB_BACKUP_RETAIN` to change).

**Nothing is scheduled.** A `launchd` agent existed briefly and was removed
deliberately ([ADR 0006](../docs/decisions/0006-backups-are-deliberately-modest.md));
git history has it if that ever changes.

**It only runs when this Mac is on, and every copy lives on this one machine.**
That is a deliberate choice, not an oversight — see
[ADR 0006](../docs/decisions/0006-backups-are-deliberately-modest.md). What these
archives protect is roughly an hour of rebuilding; everything else is in git.
Revisit if the lab ever holds data that exists nowhere else.

## backup.sh needs no sudo

Every step runs unauthenticated (since 2026-09-04): container data is read
through the containers themselves, and `pi` is in the `unifi` group so the
native controller's autobackups are readable too. That means it can be
scheduled without a password prompt to answer, should that ever be wanted.

## ⚠️ The backup output contains secrets

`$DEST` (default `~/homelab-backups`) is **not** a safe place to sync casually.
It holds:

- `wireguard.tar.gz` — the server key and every client private key
- `portainer.tar.gz` — Portainer's BoltDB, which carries users, TLS keys and the
  **GitHub token** used to deploy the git stacks
- `pihole.tar.gz` — the admin password hash
- `caddy.tar.gz` — the internal CA's **root signing key**, which can mint
  certificates any device trusting it will accept

Treat the directory like the credentials it contains, and encrypt before any
off-site copy (HL-14).

## ⚠️ `backup.sh` depends on the `alpine` image

Several steps spawn throwaway `alpine:3.20` containers to read Docker volumes
without sudo. The tag is pinned so a surprise base-image change cannot break the
backup path. Because those containers are `--rm`, Portainer shows `alpine:3.20` as
**Unused** between runs — do not prune it. Deleting it makes every backup re-pull
from DockerHub, which counts against the anonymous rate limit (100 pulls / 6h)
and fails outright if the Pi has no internet at the time.

When cleaning up images, remove specific tags rather than using **Prune**.

## sync-fallback.sh

Run after **any** change to the `network-core` stack:

```bash
./scripts/sync-fallback.sh
```

`~/stacks/network-core-fallback/` on the Pi is the emergency restore path in the
[DNS outage runbook](../docs/runbooks/dns-outage.md). It is a plain local copy
because the normal path — Portainer cloning this repo — needs DNS, which is
precisely what you would be restoring. Being a copy, it drifts; this resyncs it,
verifies the checksums match on both sides, and validates the compose file on
the Pi.

## check-docs.sh

Run after editing [the backlog](../docs/backlog.md); the pre-commit hook also
runs it. It catches the five ways this repo has actually drifted:

1. an id listed as both open and done
2. a markdown link to a file that no longer exists
3. **an id missing from the sequence** — added after HL-35 and HL-56 vanished
   into a runaway regex and nobody noticed for several commits
4. an id referenced somewhere but never defined
5. a link to a `#heading` that no longer exists in the target file — added
   after a renumbered section left `add-a-site.md#7-backups` pointing nowhere

Ids retired without being worked are declared in an HTML comment near the top of
the backlog, so check 3 does not flag them.

## export-public.sh

Builds the public copy of this repo ([ADR 0016](../docs/decisions/0016-public-copy-is-generated.md)).
Run it on the Mac, from inside this repo, with a clone of the public repo as the
target:

```bash
./scripts/export-public.sh ~/homerack
```

It exports the last commit, so commit first. It replaces everything in the
target except `.git`, applies `export-public/redactions.tsv`, and refuses the
result if anything sensitive is left. It does not commit or push. Review
`git diff` in the target, then commit there as `Snapshot <date>` and push.

When it is blocked, the output names each `file:line`. Map the value in
`redactions.tsv` if it should be hidden, or add it to `allowlist.txt` if it is
meant to be public. `redactions.tsv` holds the real values, so it is the one
file never exported.

To keep a whole passage out of the public copy but documented here, put a line
that is only `<!-- private -->` before it and a line that is only
`<!-- /private -->` after it. The export removes both lines and everything
between them. The comments are invisible when GitHub renders the file.

## Documenting current state (do this first)

The discovery script exists so the repo can be filled in from reality rather than
from memory. It changes nothing.

```bash
# The Pi — run from your laptop
ssh pi@kish.lan 'bash -s' < scripts/discover-kish.sh > /tmp/kish-discovery.txt
```

> **Redact before sharing or committing.** The Pi script prints container
> details, and any environment variable a container is given later could hold a
> credential. Replace such values with placeholders — they belong in `.env`
> files on the host, never in git.

### What the scripts can't reach

Three sources need collecting by hand:

- **Switch port map** → unifi controller, Devices → `USW-Lite-8-PoE` → Ports. Records
  which physical port feeds which device, and PoE draw. Goes in
  [network.md](../docs/network.md).
- **DHCP reservations and the gateway** → your router's admin UI. Leave its
  secondary DNS **empty**: a secondary was tried and removed, because clients
  use it at random and skip Pi-hole
  ([ADR 0005](../docs/decisions/0005-single-filtering-resolver.md)).
- **Hue bridge** → the Hue app, Settings → Bridge, for model and IP. Or find it
  on the network with `curl -s https://discovery.meethue.com`.

Once collected, the answers go into `docs/` and the discovery dumps get thrown
away — they are scratch, not artifacts. `.gitignore` covers `*-discovery.txt`.
