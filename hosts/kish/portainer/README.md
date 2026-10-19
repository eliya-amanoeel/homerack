# Portainer CE

Docker management UI. Runs from its **own local compose file**
(`~/stacks/portainer/`), not as a Portainer stack and not part of `network-core`
— so restarting that stack doesn't take the UI with it.

- **UI:** https://portainer.lan — through Caddy. The container publishes 9000 on
  `127.0.0.1` only (HL-33); with Caddy down, `ssh -N -L 9000:127.0.0.1:9000 pi@192.168.68.71`
  and open http://localhost:9000.
- **Image:** `portainer/portainer-ce:lts` · **Restart:** `always`
- Pinned to the **LTS** track (2.45.x) rather than `latest`, which follows the
  STS/feature releases. Keeps patches, never jumps a feature version.
- **Data:** named volume `portainer_data`
- Mounts `/var/run/docker.sock`, which is effectively root on the host. Anyone
  who logs in to Portainer controls the Pi — which is why port 9000 is not on
  the LAN.

## Portainer has its own DNS, deliberately

The compose file sets `dns: [192.168.68.71, 1.1.1.1]`. Without the fallback,
Portainer resolves through Docker's embedded resolver (`127.0.0.11`), which
forwards to the host's nameserver — Pi-hole. That creates a deadlock: with the
`network-core` stack down, Portainer cannot resolve `github.com` to clone the
repo, at exactly the moment it needs to redeploy the stack that would bring DNS
back. This bit us during the HL-29 migration, surfacing as:

```
dial tcp: lookup github.com on 127.0.0.11:53: server misbehaving
```

Pi-hole stays first so internal `.lan` names still resolve.

Recreate with [docker-compose.yml](docker-compose.yml). It was originally
started with `docker run`; as of 2026-09-04 it is compose-managed from
`~/stacks/portainer` on the Pi.

`portainer_data` is declared **external**, so `docker compose down` and a
recreate preserve your account and settings. Verify after any recreate:

```bash
curl -o /dev/null -w '%{http_code}\n' http://localhost:9000/api/users/admin/check
# 204 = admin account intact.  404 = fresh install, i.e. the volume was lost.
```

The image is distroless — there is no shell, so `docker exec portainer sh`
fails. That is expected, not a broken container.
