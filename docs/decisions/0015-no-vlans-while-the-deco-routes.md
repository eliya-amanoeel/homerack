# 0015 — No VLANs while the Deco is the router

**Date:** 2026-10-19 (HL-12)
**Status:** accepted

## Context

HL-12 asked for VLAN segmentation: IoT apart from the trusted LAN. The unifi
switch can tag VLANs, but VLANs only segment usefully when something routes and
filters between them. The router is a TP-Link Deco XE75, and it stays: a unifi
gateway and access points were considered and turned down by the owner.

What the Deco offers, as far as could be found on 2026-10-19:

- **No user-configurable VLANs.** No TP-Link spec for the XE75 lists them; user
  reports say Deco does not tag its SSIDs
  ([community thread](https://community.tp-link.com/en/business/forum/topic/860902)).
- **IoT Network:** a separate 2.4 GHz SSID. In router mode it is *not
  separated* from the main network
  ([comparison](https://community.tp-link.com/en/business/forum/topic/839316)).
- **Device Isolation:** the XE75 is on the supported list. Isolated devices
  keep internet and can reach each other, but not the home network
  ([TP-Link FAQ](https://www.omadanetworks.com/in/support/faq/3968/)). It acts
  on traffic that passes through the Deco — Wi-Fi clients — not on traffic
  between two ports of the switch.

With the Deco as the only router, a VLAN on the switch is either the one on the
uplink (port 8) or an island with no DHCP, no internet and no access from
Wi-Fi. Every wired device — `nergal`, `kish`, the three nodes, the Hue bridge —
needs the Deco side, so all of them would sit on the uplink VLAN: the flat
network again.

## Decision

No VLANs. The network stays one `/22`. Isolation is done with the tools that
work on a flat network instead, tracked as HL-108:

- **Wi-Fi IoT** — nearly every IoT device in the house — with Deco Device
  Isolation.
- **The Hue bridge**, the only wired IoT device, with deny rules on the hosts
  it should not reach, the way `nergal`'s DSM firewall already does.

unifi port isolation was looked at for the Hue bridge and is not the answer as
understood: an isolated port still reaches non-isolated ones, so fencing port 6
off the lab would mean isolating the lab ports from each other too. That
understanding comes from third-party sources and is untested on this switch.

An island VLAN for node-to-node traffic only (corosync, migrations) would work
without a router; with one NIC per node and a quiet LAN the gain is too small
to be worth it now.

## Consequences

- **No new hardware, no change to the Deco.** Addresses, reservations and
  Pi-hole stay as they are.
- **Isolation is per device or per host, not per subnet.** Each new IoT device
  needs Device Isolation turned on by hand, and each host that should refuse the
  Hue bridge needs its own rule.
- **Some local access may break.** Casting, printing and local apps reach their devices over the LAN; isolating those devices is a
  per-device choice in HL-108.
- **The Proxmox `management` IPSet stays the whole `/22`**; the note to narrow
  it once VLANs exist now means leaving out the Hue bridge (HL-108).
- **Revisit if the router changes.** A router with VLANs and inter-VLAN
  firewalling makes HL-12's original plan possible, and the switch is ready.
