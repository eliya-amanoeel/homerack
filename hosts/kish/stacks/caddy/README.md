# Caddy — reverse proxy with an internal CA

Gives each admin UI a name and HTTPS instead of an IP and a port number.

| Name | Proxies to | Was |
|---|---|---|
| `https://pihole.lan` | 127.0.0.1:8081 | `http://192.168.68.71:8081/admin` |
| `https://portainer.lan` | 127.0.0.1:9000 | `http://192.168.68.71:9000` |
| `https://kuma.lan` | 127.0.0.1:3001 | `http://192.168.68.71:3001` |
| `https://wg.lan` | 127.0.0.1:51821 | `http://192.168.68.71:51821` |
| `https://beszel.lan` | 127.0.0.1:8090 | new, HL-98 |
| `https://goaccess.lan` | http://192.168.68.20:8081 (`edge`, reachable from the Pi only) | new, HL-99 |
| `https://unifi.lan` | https://127.0.0.1:8443 | self-signed cert warning |
| `https://uruk.lan` | https://192.168.68.10:8006 (`anu`), or https://192.168.68.11:8006 (`inanna`) or https://192.168.68.12:8006 (`enlil`) while anu is down | self-signed cert warning |

The names are served by Pi-hole (`dns.hosts`), all pointing at the Pi. Caddy
runs with host networking, so `127.0.0.1` is the Pi itself. The "Was" column
is history: since HL-33 the Pi-hole, Portainer, Kuma, wg-easy and
Beszel ports are bound to `127.0.0.1`, so with Caddy down they are reached with
`ssh -L <port>:127.0.0.1:<port> pi@192.168.68.71`, not from the LAN. unifi's
`:8443` and the Proxmox nodes' `:8006` still answer directly.

## Deploying a change

A **local copy** on the Pi, `/home/pi/stacks/caddy/`, owned by `pi` — not a
Portainer git stack. From the repo on the Mac:

```bash
ssh pi@kish.lan 'cp ~/stacks/caddy/Caddyfile ~/stacks/caddy/Caddyfile.bak'
scp hosts/kish/stacks/caddy/Caddyfile pi@kish.lan:stacks/caddy/Caddyfile
ssh pi@kish.lan 'docker exec caddy caddy validate --config /etc/caddy/Caddyfile && docker restart caddy'
```

**`caddy reload` does not work here:** the Caddyfile sets `admin off`, so there
is no admin API on :2019 for it to talk to (with host networking it would
otherwise listen on the Pi itself). A change is applied with `docker restart
caddy` — every `.lan` UI is down for a few seconds; DNS is not affected.
`scp` writes into the existing file, so the single-file bind mount sees it;
an editor that replaces the file would leave the container on the old inode.
New site names get a certificate from the internal CA on the first request.

## Why an internal CA

`cert_issuer internal` in the Caddyfile makes Caddy issue certificates from its
**own** authority rather than Let's Encrypt. No domain, no DNS challenge,
nothing reaches the internet — and no risk to any live site. Until HL-103 this
was `local_certs`, the same issuer without a way to set the lifetime.

Issued certificates last **3 days** (Caddy's default is 12 hours, which made
the first visit each morning fail with `ERR_CERT_DATE_INVALID`). They must stay
shorter than the intermediate certificate's 7 days.

The trade-off: browsers do not know this authority, so each device must trust its
root certificate once.

### Installing the root certificate

Extract it:

```bash
ssh pi@kish.lan 'docker exec caddy cat /data/caddy/pki/authorities/local/root.crt' \
  > caddy-homelab-root.crt
```

**macOS:**
```bash
sudo security add-trusted-cert -d -r trustRoot \
  -k /Library/Keychains/System.keychain caddy-homelab-root.crt
```

**iOS:** AirDrop or email the file, install the profile, then enable it under
Settings → General → About → Certificate Trust Settings.

**Windows:** import into *Trusted Root Certification Authorities*.

**Android:** Settings → Security → Encryption & credentials → Install a
certificate → CA certificate. Note that since Android 7, apps may ignore
user-installed CAs even when browsers accept them.

Any device without it sees a certificate warning — including guests.

## Caveats

- **`caddy_data` holds the CA's root key.** Lose that volume and Caddy generates
  a new authority, and every device has to trust the new root. It is worth
  keeping; `scripts/backup.sh` collects it as `caddy.tar.gz`.
- **A compromised Pi could issue certificates your devices trust** for any name,
  because the signing key lives here. That is the real difference from Let's
  Encrypt, where no such key exists on your hardware.
- **unifi's backend is proxied with `tls_insecure_skip_verify`.** Its self-signed
  certificate is not verified — the trust boundary is Caddy, not the browser.
  Acceptable on a loopback hop within the same host.
