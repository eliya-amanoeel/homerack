# GoAccess — website statistics (HL-99)

One report per site at **https://goaccess.lan**, rebuilt hourly from Caddy's
access logs on `edge`. Visits, pages, referrers, 404s, browsers and OS. No
clicks or events, and SiteB (Blazor) only shows first page loads.
Umami was considered and dropped: Search Console already covers amaeli and
site-a, and SiteB's one shared login makes login tracking meaningless.

```
browser → goaccess.lan (Pi-hole → kish .71) → kish Caddy → edge :8081 → /var/lib/goaccess/html
```

## Pieces

| Where | What |
|---|---|
| `edge` [Caddyfile](../Caddyfile) | `access_log` snippet: `/var/log/caddy/<site>.log`, JSON, IPs masked to /24 (IPv4) and /48 (IPv6), rolled at 50 MiB, kept 90 days |
| `edge` `/usr/local/bin/goaccess-report` | [goaccess-report](goaccess-report): per site, excludes the whole LAN, `192.168.68.0/22` (own visits, Uptime Kuma) and known crawlers; history persists in `/var/lib/goaccess/db/<site>`, so reports outlive the logs |
| `edge` systemd | [goaccess-report.service](goaccess-report.service) as `caddy`, [goaccess-report.timer](goaccess-report.timer) hourly at :05 |
| `edge` Caddyfile | `http://:8081` serves `/var/lib/goaccess/html` to `192.168.68.71` only, 403 to anyone else |
| Proxmox, VM 100 firewall | `IN ACCEPT -source 192.168.68.71 -p tcp -dport 8081` |
| `kish` [Caddyfile](../../kish/stacks/caddy/Caddyfile) | `goaccess.lan` → `192.168.68.20:8081` |
| Pi-hole `dns.hosts` | `192.168.68.71 goaccess.lan` |

GoAccess is Debian's package (`apt install goaccess`, 1.9.3 on install).

## Deploying a change

On the Mac, from the repo:

```bash
scp hosts/edge/goaccess/goaccess-report* debian@192.168.68.20:/tmp/
```

On `edge`:

```bash
sudo install -m 755 /tmp/goaccess-report /usr/local/bin/
sudo install -m 644 /tmp/goaccess-report.service /tmp/goaccess-report.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl start goaccess-report.service   # run now instead of waiting for :05
```

A run is safe to repeat: GoAccess remembers the last line it parsed per log and
does not count lines twice (checked on 2026-09-28).

## Checks

```bash
systemctl list-timers goaccess-report.timer                  # next run
systemctl show goaccess-report -p Result -p ExecMainStatus   # last run: success, 0
```

The index page shows when the reports were last rebuilt.

## Pitfalls

- **Validate edge's Caddyfile as `caddy`, not root:**
  `sudo -u caddy caddy validate --config <file> --adapter caddyfile`.
  Validation opens the log files, and as root it creates them root-owned with
  mode 600. The running Caddy then cannot open them and the reload fails
  (happened on 2026-09-28). If it does: delete the empty files, reload again.
- **Firewall rule fields:** the Proxmox dialog has an address and a port on
  both the Source and Destination rows. 8081 belongs in **Dest. port**; in
  Source port it silently matches nothing.
- **Starting over:** stop the timer, delete `/var/lib/goaccess/db/<site>`, run
  the service. History then only goes back as far as the logs (90 days).
