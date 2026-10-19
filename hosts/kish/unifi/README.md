# unifi Network Application (native install)

Controls `USW-Lite-8-PoE`. **Installed via apt, not Docker** — there is no compose
file for this and never was. Discovery found it running as a systemd service.

- **Version:** `unifi` 10.6.101-35991-1
- **Database:** `mongod-armv8` 8.0.29 (plus `mongodb-org-tools` 8.0.31),
  listening on `127.0.0.1:27117` — localhost only, not exposed
- **Service:** `unifi.service`, active and enabled
- **UI:** https://unifi.lan through Caddy; https://192.168.68.71:8443 directly
  as the fallback
- **Data:** `/var/lib/unifi` · **Logs:** `/var/log/unifi`

## Ports

| Port | Purpose |
|---|---|
| 8443 | Web UI (HTTPS) |
| 8080 | Device inform — the switch needs this or it shows disconnected |
| 8843 / 8880 | Guest portal HTTPS / HTTP |
| 6789 | Speed test (mobile app) |
| 3478/udp | STUN — devices use it to reach the controller |
| 10001/udp | Device discovery |
| 5514/udp | Remote syslog from devices |
| 28082 | Listening on all interfaces; purpose not identified |
| 27117 | MongoDB, localhost only |

## Operating it

```bash
sudo systemctl status unifi
sudo journalctl -u unifi -f
sudo tail -f /var/log/unifi/server.log
```

## Backups

The controller writes autobackups to `/var/lib/unifi/backup/autobackup/`.
Configure retention in Settings → System → Backups. This is the **only** thing
that restores a controller — the apt package alone gets you an empty one.

`scripts/backup.sh` collects these without sudo: `pi` is in the `unifi` group,
which may read `/var/lib/unifi`.

## Credentials

Values live in the password manager. One note the password manager will not tell you:

- **Switch local recovery** — the **device SSH login**, user
  `eliya.amanoeel`, password in the password manager. The controller pushes it to the
  switch, which keeps it when the controller is gone:
  `ssh eliya.amanoeel@192.168.68.68`. From there a
  rebuilt controller can re-adopt the switch without a factory reset
  (`set-inform http://192.168.68.71:8080/inform`). Since unifi 9.2 the setting
  is **not** under Settings: **unifi Devices → Device Updates & Settings →
  Device SSH Settings**. Proven working 2026-09-26 (HL-56).

## Notes

- **The switch keeps switching without this.** Losing the controller costs
  management and stats, not connectivity. Don't panic-restore at 2am.
- Upgrades come through apt, so `apt upgrade` can move the controller a major
  version. Take a backup first.
