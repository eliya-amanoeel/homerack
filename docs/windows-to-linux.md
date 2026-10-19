# Windows → Linux/Proxmox cheat sheet

Written for moving the sites from `prodesk` (Windows Server + IIS) to Proxmox
(HL-08, finished 2026-09-24). Kept as a reference: when something on Linux is
confusing, find the Windows thing you already know in the left column.

## Component by component

| On Windows | On Proxmox/Linux | Note |
|---|---|---|
| The physical server running Windows Server | **Proxmox host** (`anu`, `inanna`, `enlil`) | Only runs guests; your sites never run directly on it |
| A Hyper-V VM | **VM** or **LXC container** | A container is a lightweight mini-Linux that shares the host's kernel; it starts in seconds and uses little RAM. `edge` is a VM, the sites and `postgres` are containers ([ADR 0008](decisions/0008-site-hosting-pattern-on-proxmox.md)) |
| IIS | **Caddy** (or nginx) | The web server |
| An IIS **site** with host-header bindings | A **site block** in the Caddyfile, e.g. `amaeli.se { ... }` | One block per hostname |
| `C:\inetpub\wwwroot\amaeli` | `/var/www/amaeli` | Where the files live |
| `web.config` rewrite rules | Lines in the Caddyfile | e.g. `try_files` for React routing, `redir` for `www` → the main address |
| IIS **ARR / URL Rewrite** acting as reverse proxy | Caddy `reverse_proxy` | See [edge proxy](#what-is-an-edge-proxy) |
| **win-acme** + Task Scheduler for certificates | **Built into Caddy** | Obtains and renews Let's Encrypt certificates automatically, no separate tool |
| ASP.NET Core Module hosting Blazor | **Kestrel** (the web server built into .NET) run as a **systemd service**, with Caddy in front | SiteB |
| Windows Services (`services.msc`) | **systemd** (`systemctl`) | Keeps programs running and starts them at boot |
| Task Scheduler | **systemd timers** or **cron** | e.g. `goaccess-report.timer` on `edge` |
| IIS logs in `C:\inetpub\logs` | Caddy access logs in `/var/log/caddy/` | Only where a `log` block turns them on; `edge` has them per site |
| GitHub runner as a Windows service | The same runner, as a **systemd service** | Same GitHub side; the workflow must ask for `[self-hosted, linux]` |
| PowerShell + `robocopy` | **bash** + `rsync` | |
| Event Viewer | **`journalctl`** | |
| Windows Firewall | **Proxmox firewall**, set per guest in the UI | Only `edge` has one on; the site containers deliberately do not |
| RDP | **SSH**, or the console in the Proxmox UI | No desktop, only a terminal |
| Windows Update | **`apt update && apt upgrade`** | Every guest also runs `unattended-upgrades` |
| Windows Server Backup | **Proxmox backup job** (`vzdump`) | Backs up a whole guest as one file |
| `Administrator` | `root`, or your user plus `sudo` | VMs: `debian` + `sudo`; containers: `root` |

## What is an edge proxy?

**The IIS equivalent:** one IIS server with **ARR** that receives all internet
traffic, keeps no sites of its own, and forwards each hostname to the right
backend server.

- **"Proxy":** it receives the visitor's request and fetches the page from
  another server on the visitor's behalf.
- **"Edge":** it sits at the edge of your network, the first machine internet
  traffic hits.

**What it does:**

- **One entry point:** the router forwards 80/443 to a single place, however
  many sites or guests there are.
- **Routing by hostname:** `amaeli.se` goes to the amaeli container,
  `app.site-b.example` to the site-b one.
- **Certificates in one place:** it handles HTTPS for every site, and the
  backends just serve plain pages.
- **Moving or adding a site = one block:** that is how the sites left IIS one
  at a time, and how the next one gets added.

**There are two in this lab.** `edge` (a VM, [ADR 0011](decisions/0011-edge-stays-on-the-cluster.md))
faces the internet. Caddy on `kish` does the same job for the LAN: it gives the
admin UIs names like `pihole.lan`, `uruk.lan` and `goaccess.lan`.

```
internet → router 80/443 → edge (VM, Caddy, .20)
                            ├─ amaeli.se          → amaeli container (.21)
                            ├─ site-a.example        → site-a container (.22)
                            ├─ app.site-b.example   → site-b container (.23) → postgres (.24)
                            └─ www.amaeli.se, www.site-a.example → redirect to the main address
```

## "How do I…" — everyday equivalents

Most commands that change something need `sudo` in front.

| I want to… | Windows | Linux |
|---|---|---|
| See if a service is running | `Get-Service caddy` | `systemctl status caddy` |
| Restart a service | `Restart-Service caddy` | `systemctl restart caddy` |
| Read a service's log | Event Viewer | `journalctl -u caddy -e` |
| Follow a log live | — | `journalctl -u caddy -f` |
| See scheduled tasks and their next run | Task Scheduler | `systemctl list-timers` |
| See what listens on which port | `netstat -ano` | `ss -tlnp` |
| Check disk space | Explorer / `Get-PSDrive` | `df -h` |
| Check memory | Task Manager | `free -h` |
| See running processes | Task Manager | `htop` (or `top`) |
| Edit a config file | Notepad | `nano /path/to/file` (Ctrl+O save, Ctrl+X exit) |
| Copy a folder, mirroring deletions | `robocopy src dst /MIR` | `rsync -a --delete src/ dst/` |
| Install updates | Windows Update | `apt update && apt upgrade` |
| Install a program | an installer / `winget install` | `apt install <package>` |
| Look up a DNS name | `nslookup name` | `dig +short name` (or `nslookup name`) |
| Clear the DNS cache | `ipconfig /flushdns` | Mac: `sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder` |
| Check a Caddyfile before applying | — | `edge`: `sudo -u caddy caddy validate --config <file> --adapter caddyfile` (as `caddy`, never root) · `kish`: `docker exec caddy caddy validate --config /etc/caddy/Caddyfile` |
| Apply a Caddyfile change | `iisreset` | `edge`: `systemctl reload caddy` · `kish`: `docker restart caddy` (its admin API is off) |
| Run a command inside a VM without logging in | — | on its node: `qm guest exec <id> -- <command>` |
| Forget a server's old SSH key after a rebuild | — | Mac: `ssh-keygen -R <ip or name>` — only after checking the new fingerprint |
