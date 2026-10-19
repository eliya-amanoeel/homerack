# Monitoring

Two layers, because neither one alone tells you your sites are up.

| Layer | Where it runs | What it can see | What it is blind to |
|---|---|---|---|
| **1. UptimeRobot** | outside your network | the visitor's path: ISP, router, port forwards, public DNS | anything internal |
| **2. Uptime Kuma** | on `kish` | site health, certs, DNS, the Proxmox UIs | everything between the internet and your door |

Kuma's config lives in its SQLite volume, not git, so this file is the
recreatable record. UptimeRobot's lives in their account; it is recorded here
too because it is part of the same story, not because it belongs to this stack.

**Reading a page:** external red + Kuma green means the fault is between the
internet and your door — ISP, port forward, or public DNS. Both red means `edge` or
the site itself. That distinction is the diagnostic.

---

# Layer 1 — UptimeRobot (external)

Free tier: 50 monitors, 5-minute checks, no card. https://uptimerobot.com

Three monitors, one per site. Alerts go to **email** — deliberately a different
channel from Kuma's ntfy, so one broken path cannot silence both.

| Friendly Name | URL |
|---|---|
| [x] `app.site-b.example (external)` | `https://app.site-b.example` |
| [x] `site-a.example (external)` | `https://site-a.example` |
| [x] `amaeli.se (external)` | `https://amaeli.se` |


| Field | Value | Why |
|---|---|---|
| Monitor Type | **Keyword** (preferred) or HTTP(s) | see below |
| Keyword | some text always on the page — a title, a footer, a company name | |
| Monitoring Interval | `5 minutes` | free-tier default; fine |
| Alert Contacts | your email | separate channel from ntfy, on purpose |

**Prefer Keyword over plain HTTP(s).** An HTTP check passes on any 200 —
including a server returning a blank page, a default site, or a half-deployed build.
A keyword check also requires the page to *contain* expected text. Same effort,
and it catches "up but broken", which is a real failure mode for a web host.

**Suffix the names with `(external)`** so an alert tells you which layer fired
without opening anything.

---

# Layer 2 — Uptime Kuma (internal)

UI: https://kuma.lan (port 3001 is `127.0.0.1` only, HL-33)

## Settings that apply to every monitor

Kuma's defaults are not all sensible. Set these on each one:

| Field | Value | Why |
|---|---|---|
| Heartbeat Interval | `60` | once a minute is plenty here |
| **Retries** | **`2`** | **the important one.** At `0`, a single blip marks it down and notifies. Alerts you learn to ignore are worse than none. |
| Heartbeat Retry Interval | `60` | with Retries 2, you are told after ~3 minutes of real failure |
| Request Timeout | `20` | default 48s means a hung service takes nearly a minute to flag. HTTP monitors only — the DNS type has no such field |
| Resend Notification if Down | `0` | one alert per outage. Set `30` if you would rather be nagged every half hour. |
| Notification | ✅ your ntfy channel | tick it on every monitor |

## Notification channel — do this first

So it attaches automatically as you create each monitor.

- [x] **ntfy** — `Homelab Heartbeat`. Settings → Notifications, type `ntfy`,
      server `https://ntfy.sh`, unguessable topic, **Default enabled** +
      **Apply on all existing monitors**, then **Test**

## The monitors

### DNS resolution — the one that matters most

- [x] **Type** DNS · **Friendly Name** `dns resolution`
      **Hostname** `example.com` · **Resolver Server** `192.168.68.71`
      **Port** `53` · **Resource Record Type** `A`

Tests resolution itself. Pi-hole's admin page can answer perfectly while DNS is
broken — checking the web UI would tell you the wrong thing.

### The three public sites

For each: **Type** HTTP(s), **URL** as below, plus the common settings above.

| Friendly Name | URL |
|---|---|
| [x] `app.site-b.example` | `https://app.site-b.example` |
| [x] `site-a.example` | `https://site-a.example` |
| [x] `amaeli.se` | `https://amaeli.se` |

Under **Advanced**, on all three:

| Setting | Value | Why |
|---|---|---|
| **Certificate Expiry Notification** | ✅ **on** | the highest-value setting here — see below |
| Ignore TLS/SSL error | ❌ off | you have real certs; a TLS break should be loud |
| Upside Down Mode | ❌ off | inverts pass/fail |
| Max Redirects | `10` | fine as default |
| Accepted Status Codes | `200-299` | fine as default |

**Why certificate expiry matters most:** Let's Encrypt certs last 90 days and
renew automatically — until renewal silently stops. Nothing tells you. The
failure surfaces when the sites break for every visitor, potentially months
later.

Since the sites moved behind `edge` (2026-09-17), Caddy there obtains and renews
every certificate; it renews when about a third of the lifetime is left. As of
2026-09-28 all of them expire on **16 Dec 2026**, `www.site-a.example` on 27 Dec.
The first renewals are therefore due around mid-November — if a certificate
still shows a December expiry in late November, renewal has failed. Check with:

```bash
echo | openssl s_client -connect 192.168.68.20:443 -servername amaeli.se 2>/dev/null | openssl x509 -noout -enddate
```

### ⚠️ Why layer 1 exists: these test the LAN path

Pi-hole serves split-horizon DNS, so on the Pi these names resolve to
`192.168.68.20` (`edge`) while the public internet resolves them to `203.0.113.10`.
Kuma therefore reaches `edge` **directly across the LAN**, bypassing your ISP link,
the router, and the port forwards — and stays green through every failure in
between. That gap is exactly what layer 1 covers.

### Infrastructure

Common settings above; these are all HTTP(s) unless noted.

| Friendly Name | Type | Target | Note |
|---|---|---|---|
| [x] `anu direct` | HTTP(s) | `https://192.168.68.10:8006` | ✅ **Ignore TLS error** — self-signed. Added 2026-09-16 as `pve1 direct`, renamed 2026-09-24 |
| [x] `inanna direct` | HTTP(s) | `https://192.168.68.11:8006` | ✅ **Ignore TLS error** — self-signed. Added 2026-09-18 as `pve2 direct`, renamed 2026-09-24 |
| [x] `enlil direct` | HTTP(s) | `https://192.168.68.12:8006` | ✅ **Ignore TLS error** — self-signed. Added 2026-10-12, cloned from `inanna direct` |
| [x] `uruk.lan (Caddy)` | HTTP(s) | `https://uruk.lan` | ✅ **Ignore TLS error** — Kuma does not trust Caddy's CA. Red while `anu direct` is green means Caddy or DNS. Added 2026-09-16 as `pve.lan (Caddy)`, renamed 2026-09-24 |

Skipped by choice (2026-09-26):
- **WAN ping:** its alert goes out through ntfy.sh, so it cannot arrive while
  the internet is down.
- **Portainer:** nothing running depends on it; a crash is noticed and
  restarted the next time it is needed.
- **wg-easy:** the check would cover the admin UI, not the tunnel.
- **unifi controller:** the switch runs without it (the Wi-Fi is the Deco's,
  not unifi's).
- **Hue bridge:** noticed as soon as the lights stop responding.
- **USW-Lite-8-PoE:** anu, inanna and enlil hang off it, so its failure already turns
  `anu direct`, `inanna direct`, `enlil direct` and the site monitors red.

---

# The remaining blind spot

**Kuma runs on `kish` and cannot report its own death.** If the Pi loses
power or its card fails, every layer-2 monitor stops and no ntfy alert is sent —
silence is indistinguishable from everything being fine.

Layer 1 does not cover this either: UptimeRobot watches the sites on Proxmox,
which keep working while the Pi is down.

Two ways to close it, neither required:

- **Dead man's switch (layer 3).** A free [healthchecks.io](https://healthchecks.io)
  check that the Pi pings on a schedule; if the pings stop, *they* email you.
  ~10 minutes, and the only thing that catches total failure of the Pi.
- **Notice by hand.** The house losing DNS is loud and immediate. For a home lab
  this is a legitimate choice — **and the one taken on 2026-09-25**: heartbeat
  monitors are paid on UptimeRobot, and no second account was wanted.

# Don't over-monitor

Every monitor that goes red for something you would ignore trains you to ignore
alerts. Watch what you would act on; skip the rest.
