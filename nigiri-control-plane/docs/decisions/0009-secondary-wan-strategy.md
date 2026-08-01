# ADR 0009 — Secondary WAN: always-on LTE router feeding Tailscale, isolated from the primary LAN

- **Status:** proposed (Phase 4; hardware pending Q10)
- **Date:** 2026-08-01

## Context

When the home ISP or router dies while the user is away, no amount of
Tailscale/DERP cleverness reaches a Mini whose only uplink is gone
(relays route around NAT, not dead links). An independent WAN path is the
only remedy — the brief's guardrail against treating relays as one is
correct and adopted.

## Decision drivers

Independence from primary ISP *and* primary router; must not destabilize
the household network; fail-closed cost control (data caps); UPS
coverage; away-from-home usability; reuse of existing identity/encryption
(no second remote-access system to secure).

## Considered alternatives

- **Secondary wired ISP** — strongest path, monthly cost and install
  friction for a personal devbox; rejected for now (revisit if LTE data
  reliability disappoints).
- **Cellular failover feature of a prosumer router** (replace primary
  router with failover-capable unit) — couples the fallback to the very
  router whose failure is a target scenario; rejected.
- **USB LTE dongle directly on the Mini** — cheapest, but modem management
  lands on macOS (fragile), and the network shelf (modem/switch) gains
  nothing; rejected.
- **Activate-on-failure fallback** — a dormant path activated by the thing
  that just failed is untested exactly when needed; rejected for
  always-connected with idle-cost control.
- **A separate management gateway box** (Pi-class device on LTE as a jump
  host) — adds an independently-compromisable, independently-maintained
  trust anchor; Tailscale-on-existing-identity is strictly simpler.

## Decision

A dedicated LTE/5G router (GL.iNet Spitz/Peplink-class; model chosen at
purchase) on UPS power, its own isolated subnet (192.168.207.0/24), no
bridge to the primary LAN. The Mini attaches via USB-C Ethernet as a
*secondary* interface (service order below primary); Tailscale binds all
interfaces, so when the primary uplink dies, coordination + DERP + direct
UDP ride LTE and **Path A keeps working over Path C's transport**.
Always-connected; data-capped SIM; usage alerting from router metrics +
witness canary cadence.

## Consequences

Remote reachability survives primary-ISP and primary-router death (the two
scariest away-from-home rows in the matrix); ongoing SIM cost (Q10);
another box on the shelf to monitor (its own service check when built);
preboot-SSH (FileVault) does *not* ride this path unless deliberate
port-forwarding is configured — default no, noted in the runbook.

## Security implications

The LTE subnet is WAN-hostile by assumption: no inbound forwards by
default, nothing listens there but Tailscale/SSH/4747 with their own
authn; the LTE router's admin plane is its own attack surface — LAN-side
admin only, firmware in the update cadence; data exfil cost of a
compromised Mini rises (egress via LTE) — witness/data alerts partially
cover.

## Validation required

Phase 4 drill: pull primary WAN → measure time-to-reachable via LTE;
confirm no route flapping for household traffic; verify service-order
behavior after reboot; data-idle baseline over a week.

## Revisit conditions

LTE coverage/data economics at the site poor (→ secondary wired ISP);
home moves; multi-node era concentrates value enough to justify wired
redundancy.
