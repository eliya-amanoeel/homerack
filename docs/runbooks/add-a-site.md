# Runbook: add a site to Proxmox

The pattern from [ADR 0008](../decisions/0008-site-hosting-pattern-on-proxmox.md):
one LXC container per site, Caddy on port 80, built on GitHub and deployed by a
thin runner. Written while moving **amaeli** (container `101`), 2026-09-17.
Every site after it should follow these steps exactly — if a step turns out
wrong, fix it here rather than improvising.

**Who runs what:** Proxmox UI and container shell steps are done by hand; the
prompt tells you where you are (`eliya@MyBook-Pro` = Mac, `root@anu`, `root@inanna` or `root@enlil` = host,
`root@<site>` = the container).

## Before you start, pick

| | Rule | amaeli |
|---|---|---|
| CT ID | next free from `101` | `101` |
| Hostname | the site's short name | `amaeli` |
| IP | next free in `.20`–`.49` ([network.md](../network.md)) | `192.168.68.21` |
| Repo | `eliya-amanoeel/<repo>` | `eliya-amanoeel/amaeli` |

## 1. Clone the template (Proxmox UI)

1. Right-click **9000 (tpl-debian13)** → **Clone**: Mode **Full Clone**, Target
   Storage `local-lvm`, the CT ID and hostname above.
2. **<ID> → Network** → `net0` → Edit: IPv4 **Static**, `<IP>/22`, gateway
   `192.168.68.1`.
3. **<ID> → Options** → **Start at boot**: Yes.
4. **Start**.

Full clone, not linked: a linked clone stays dependent on the template.

## 2. Give the clone its own identity (console, not SSH)

Open **<ID> → Console** (or `pct enter <ID>` from its node's shell):

```bash
rm -f /etc/ssh/ssh_host_* && dpkg-reconfigure openssh-server && systemctl restart ssh
cat /etc/machine-id                       # must be a 32-char hex string, not empty
ip -4 addr show eth0 | grep inet          # must show the static IP
```

Do this **before** the first SSH login from the Mac, or the Mac remembers the
template's copied host key and later warns that it changed.

Then from the Mac:

```bash
ssh root@<IP> 'hostname; systemctl is-enabled ssh.socket ssh.service'   # <site>, disabled, enabled
```

## 3. Install Caddy (container)

From Caddy's official repository — Debian's own package is years behind:

```bash
apt install -y debian-keyring debian-archive-keyring apt-transport-https gnupg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
apt update && apt install -y caddy
```

**Let `unattended-upgrades` update Caddy too** — by default it only updates
Debian's own sources:

```bash
cat > /etc/apt/apt.conf.d/51unattended-upgrades-caddy <<'EOF'
// Let unattended-upgrades update Caddy from its official repository too.
// Without this, only Debian's own sources are updated automatically.
Unattended-Upgrade::Origins-Pattern {
    "site=dl.cloudsmith.io";
};
EOF
unattended-upgrade --dry-run --debug 2>&1 | grep -i "allowed origins"   # must include site=dl.cloudsmith.io
```

## 4. Serve the site folder (container)

**`try_files {path} /index.html` only for sites with client-side routing** (a router in
`package.json`). Without routes it turns every unknown URL into a `200` homepage
— a soft 404 that hides broken links from visitors and search engines.

**The site's Caddyfile lives in the site's repo**, at `deploy/Caddyfile`, with a
`deploy/README.md` saying what the site needs beyond this runbook
([ADR 0010](../decisions/0010-site-caddyfiles-live-in-site-repos.md)). Only
`edge`'s Caddyfile is in this repo. For a new site, start from amaeli's
(`eliya-amanoeel/amaeli`, `deploy/Caddyfile`), the plainest one, and commit it
to the new site's repo first.

In the container:

```bash
mkdir -p /var/www/<site>
```

From the Mac, in the site's repo:

```bash
scp deploy/Caddyfile root@<IP>:/etc/caddy/Caddyfile
ssh root@<IP> 'caddy validate --config /etc/caddy/Caddyfile && systemctl reload caddy'
```

The `WARN ... no automatic HTTPS` line from `validate` is expected: HTTPS is
`edge`'s job.

Test **from the Mac**, not inside the container:

```bash
H=http://<IP>
curl -s -o /dev/null -w "home:        %{http_code}\n" $H/                 # 200
curl -s -o /dev/null -w "unknown:     %{http_code}\n" $H/does-not-exist   # 404, or 200 only with try_files
curl -sI $H/ | grep -i -E "x-content-type|x-frame|referrer"               # the headers
```

## 5. Deploy runner (container)

Runs as its own user, which may only write the site folder:

```bash
useradd --create-home --shell /bin/bash runner
chown -R runner:runner /var/www/<site>
su - runner
```

In GitHub: **repo → Settings → Actions → Runners → New self-hosted runner →
Linux, x64**. As `runner`, run the page's **whole Download block** — all of it,
starting with `mkdir actions-runner && cd actions-runner`. Skipping that first
line leaves the archive in the home folder and `config.sh` missing. For runner
2.337.0 the block is:

```bash
mkdir actions-runner && cd actions-runner
curl -o actions-runner-linux-x64-2.337.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.337.0/actions-runner-linux-x64-2.337.0.tar.gz
echo "70920811a4f8ad4328818682bca5c6469c1c942fab52448868071d0063816613  actions-runner-linux-x64-2.337.0.tar.gz" | shasum -a 256 -c   # must print OK
tar xzf ./actions-runner-linux-x64-2.337.0.tar.gz
```

Newer versions have a different URL and checksum — take them from the page.
Then configure with these flags added:

```bash
./config.sh --url https://github.com/eliya-amanoeel/<repo> --token <TOKEN> \
  --name <site>-lxc --labels linux --unattended
exit
```

As root, install it as a service:

```bash
cd /home/runner/actions-runner
./svc.sh install runner && ./svc.sh start && ./svc.sh status | head -5
```

Delete the downloaded archive — the runner does not need it once unpacked, and
it is already compressed, so it would add ~215 MB to every nightly backup:

```bash
rm -v /home/runner/actions-runner/actions-runner-linux-x64-*.tar.gz
```

The runner page should list `<site>-lxc` **Idle**. The registration token expires
after about an hour — don't paste it anywhere else.

## 6. Workflow (site repo)

Replace `.github/workflows/deploy.yml`:

```yaml
name: Build & Deploy

on:
  workflow_dispatch:

permissions:
  contents: read

concurrency:
  group: deploy
  cancel-in-progress: false

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - uses: actions/setup-node@v7
        with:
          node-version-file: '.nvmrc'   # the repo's .nvmrc holds `24`
          cache: 'npm'
      - run: npm ci
      - run: npm run build
      - uses: actions/upload-artifact@v7
        with:
          name: dist
          path: dist/
          retention-days: 7

  deploy-linux:
    needs: build
    runs-on: [self-hosted, linux]
    steps:
      - uses: actions/download-artifact@v8
        with:
          name: dist
          path: dist
      - run: rsync -a --delete dist/ /var/www/<site>/
```

Adjust the build steps to the site; the build-then-deploy shape stays. Run it
from **Actions → Build & Deploy → Run workflow**, then check `http://<IP>` shows
the real site.

## 7. Route it through `edge`

`edge` (VM `100`, `192.168.68.20`) is the only guest facing the internet: the
router forwards 80 and 443 to it, and its Caddy gets the Let's Encrypt
certificate itself over port 80. The site's container stays HTTP-only.

1. **Public DNS** (at the domain's DNS provider): an `A` record for the domain,
   and `www` if the site uses it, → `203.0.113.10`. Domains that already point
   there need nothing. Check from the Mac, against a public resolver:
   ```bash
   dig +short <domain> @1.1.1.1      # 203.0.113.10
   ```
   Do this **before** the next step: Caddy asks for the certificate as soon as
   it reloads, and keeps failing while the name points elsewhere.
2. **The route**, in [hosts/edge/Caddyfile](../../hosts/edge/Caddyfile):
   ```caddy
   # <site>: LXC <ID>.
   <domain> {
   	import access_log <site>
   	reverse_proxy <IP>:80
   }

   # Only if the site has a www name: one canonical address.
   www.<domain> {
   	redir https://<domain>{uri} permanent
   }
   ```
   `import access_log` gives the site its log for GoAccess; also add
   `<site>:<domain>` to `sites=` in
   [goaccess-report](../../hosts/edge/goaccess/goaccess-report) and deploy it
   ([goaccess README](../../hosts/edge/goaccess/README.md)).
3. **Deploy it** from the Mac, in this repo (`edge` logs in as `debian`, with
   sudo):
   ```bash
   scp hosts/edge/Caddyfile debian@192.168.68.20:/tmp/ && ssh debian@192.168.68.20 'sudo -u caddy caddy validate --config /tmp/Caddyfile --adapter caddyfile && sudo install -m 644 /tmp/Caddyfile /etc/caddy/Caddyfile && sudo systemctl reload caddy'
   ```
   Validate **as `caddy`**: as root, validating creates the new site's access
   log root-owned, and the reload then fails.
4. **Split-horizon record** on `kish`, so LAN clients go straight to `edge` like
   the other sites. The write **replaces the whole array**: read it first and
   pass back every existing entry plus the new one
   ([network.md](../network.md#dns)):
   ```bash
   docker exec pihole pihole-FTL --config dns.hosts                  # read
   docker exec pihole pihole-FTL --config dns.hosts '[ ..., "192.168.68.20 <domain>" ]'
   docker exec pihole pihole reloaddns                               # required
   dig +short <domain> @192.168.68.71                                # 192.168.68.20
   ```
5. **Test** from the Mac, then from a phone on mobile data, which takes the
   public path:
   ```bash
   curl -sI https://<domain>/ | head -1                              # HTTP/2 200
   ```

**Moving a site that is already live elsewhere** is the same steps; the cutover
is step 3. Until `edge` reloads, the old server keeps answering, and reverting
the block and redeploying is the rollback. If the domain's DNS has to move too,
lower its TTL a day ahead. amaeli, site-a and SiteB moved this way from IIS
on 2026-09-17.

## 8. Backups

Nothing to configure: the Datacenter backup job uses **Selection mode: All**, so
the new container is included from its first night. Check it appears under
**backup (<node>) → Backups** the next day — each node keeps backups of its own
guests on its own disk.

**Testing a restore** — do this once per new *kind* of guest, and whenever
unsure. Never start a restored copy with its network connected: it carries the
original's static IP (an IP conflict, see HL-70) and its runner registration
(a duplicate runner on GitHub).

1. **backup (<node>) → Backups** → the site's backup → **Restore**: CT ID `199`,
   storage `local-lvm`, **Start after restore unticked**.
2. **199 → Network** → `net0` → Edit → **Disconnect** ✅. **199 → Options** →
   Start at boot: **No**.
3. Start `199`, then in **<node> → Shell**:
   ```bash
   pct enter 199 <<'EOF'
   echo "== files";  ls /var/www/<site> | head
   echo "== caddy";  caddy validate --config /etc/caddy/Caddyfile 2>&1 | tail -1
   echo "== page";   curl -s http://localhost | head -3
   EOF
   ```
4. Stop `199` → **More → Remove**, with *Purge from job configurations* and
   *Destroy unreferenced disks* ticked.

## 9. Record it

- The README of the node it runs on ([anu](../../hosts/anu/README.md),
  [inanna](../../hosts/inanna/README.md) or [enlil](../../hosts/enlil/README.md)): add the guest.
- [network.md](../network.md): add the IP to the guest range, the service,
  the split-horizon record and the public DNS record.
- [monitors.md](../../hosts/kish/stacks/network-core/monitors.md): add the
  site's Kuma monitor, and its `(external)` monitor in UptimeRobot.
- [backlog.md](../backlog.md): tick the site's item, if it has one.

## No guest firewall, by choice

Only `edge` has the Proxmox guest firewall on. The site containers deliberately
do not (decided 2026-09-26, HL-86): the internet cannot reach them, since the
router forwards only to `edge`, and PostgreSQL and the app backends are already
restricted by `pg_hba` and `127.0.0.1` binds. Another LAN device can reach a
site's port 80 and SSH directly; that was judged not worth the extra thing to
debug when a connection fails. Don't add one to a new site without revisiting
this.
