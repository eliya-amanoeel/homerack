# 0013 — The NAS is reached only from home or over WireGuard

**Date:** 2026-09-30 (HL-92)
**Status:** accepted

## Context

`nergal` had two ways in from the internet. Port 6690 was forwarded so the
Synology Drive clients could sync from anywhere, on the reasoning that sync
cannot depend on an on-demand VPN. QuickConnect (ID `<quickconnect-id>`) gave a second
way in through Synology's relay, with no forwarded port. DDNS kept
`nergal.synology.me` pointing at the home IP.

Both answered anyone and asked for a login, unlike WireGuard, which stays silent
without a key. Of the four forwarded ports, 6690 was the most likely way in.

## Decision

**The NAS is reached only from the home network or over WireGuard, by the name
`nergal.lan`.**

On 2026-09-30:

- Pi-hole: `nergal.lan` → `192.168.68.56`.
- Every Synology Drive client and the Photos app were pointed at `nergal.lan`
  and confirmed working, at home and over WireGuard.
- The Deco's 6690 forward was deleted; `nc` from outside now times out.
- QuickConnect was turned off in DSM.
- The DDNS entry `nergal.synology.me` was deleted. Nothing used it: the
  WireGuard configs reach home by IP, and DSM's certificate did not come from
  it.

## Consequences

- From the internet, only 80, 443 and 51820/udp are forwarded.
- **Drive waits when it can't reach the NAS** and catches up on the next
  connection; nothing is lost.
- Remote sync now depends on `kish`, which runs WireGuard. A `kish` outage
  pauses remote sync; at home it is unaffected.
- The Drive clients warn about DSM's certificate, which does not name
  `nergal.lan`. Accepted once per client; a certificate for `nergal.lan` from
  Caddy's CA on `kish` would remove the warning.
- Any Synology app added later must use `nergal.lan`, not a QuickConnect ID.
  Approve sign-in (Secure SignIn) works with QuickConnect off, but after 2FA
  was removed and re-added on 2026-09-30 only the OTP entry came back: DSM sent
  requests no app received. Removing and re-adding approve sign-in fixed it.
- **Away from home, Drive and Photos work only with WireGuard on.**
