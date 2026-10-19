# Runbook: "the internet is down"

Nine times out of ten this is DNS, and DNS is the Pi.

## Immediate fix (buy yourself time)

On the affected device, set DNS manually to `1.1.1.1`. The internet comes back,
the household calms down, and you can debug without an audience.

Do **not** make that permanent as a secondary DNS server in the router: it was
tried and removed, because phones and laptops use a secondary at random and so
silently skip Pi-hole ([ADR 0005](../decisions/0005-single-filtering-resolver.md)).

## Fastest restore, if the stack is gone rather than broken

A copy of the `network-core` compose is staged on the Pi at
`~/stacks/network-core-fallback/`. It points at the same absolute data paths as
the real stack, so it brings DNS back with all config intact:

```bash
ssh pi@192.168.68.71 'cd ~/stacks/network-core-fallback && docker compose -p network-core up -d'
```

Use the project name `-p network-core` so it reuses the existing
`network-core_uptime-kuma-data` volume. Take it down again with
`docker compose -p network-core down` before redeploying from Portainer.

## Diagnose

```bash
ping 192.168.68.71           # is the Pi up at all?
ssh pi@192.168.68.71
docker ps                     # is the pihole container running?
docker logs pihole --tail 50
sudo ss -tulpn | grep :53     # is something else holding port 53?
```

Common causes, in order of likelihood:

0. **The Pi's own lookups.** The Pi asks itself first and falls back to
   `1.1.1.1` (HL-32, set in NetworkManager), so `apt` and `docker pull` keep
   working while Pi-hole is down. If they don't, check the order is still there:
   ```bash
   nmcli -g ipv4.dns con show "Wired connection 1"    # 192.168.68.71,1.1.1.1
   ```
   Don't edit `/etc/resolv.conf` by hand: NetworkManager rewrites it.
1. **Container stopped / crash-looping.** Read `docker logs pihole` for why,
   then `docker start pihole`, or **Pull and redeploy** `network-core` in
   Portainer — `https://portainer.lan` needs DNS, so from the Mac use
   `ssh -N -L 9000:127.0.0.1:9000 pi@192.168.68.71` and http://localhost:9000.
   If the stack itself is gone, the fallback above.
2. **`systemd-resolved` grabbed :53** after an OS update. Disable it (step 3 of
   [rebuild-kish.md](rebuild-kish.md)).
3. **SD card has gone read-only.** The classic Pi failure, and `kish` does
   boot from one (119 GB `mmcblk0`). `touch /tmp/x` works but `touch ~/x` fails
   → the card is dying. Go to [rebuild-kish.md](rebuild-kish.md) with a new
   high-endurance card (moving off SD was considered and declined, HL-03).
4. **Upstream resolver unreachable.** `dig @1.1.1.1 example.com` from the Pi.
   If that fails too, it's the WAN, not you.
