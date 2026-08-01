# ADR 0008 — Direct management link: Thunderbolt Bridge with static /30

- **Status:** proposed (accept after E3)
- **Date:** 2026-08-01

## Context

A recovery path must exist that depends on no router, DHCP, DNS, Tailscale,
or ISP — reaching the agent when the home network is misconfigured or dead.
The Mini has three free Thunderbolt ports (L4); the MBP has TB4 ports and,
when needed, can be carried to the Mini.

## Decision drivers

Zero standing dependencies; zero additional hardware if possible;
deterministic addressing typed from memory during an incident; explicit
cable-attachment boundary; must never leak default-route traffic.

## Considered alternatives

- **Dedicated USB-C Ethernet adapters + cable** — identical properties at
  L3, costs two adapters, survives TB-port contention; retained as the
  fallback if E3 finds TB-bridge instability (sleep/hotplug edges are the
  suspected weak spot).
- **Both TB and Ethernet adapters** — a second physically-direct link adds
  no failure-mode coverage (same cable-attached boundary); rejected as
  redundancy theater.
- **Crossover-style direct link into the home switch VLAN** — depends on
  the switch (a named failure item); rejected.
- **link-local (169.254/16) addressing** — survives with zero config but
  addresses are non-deterministic (typing an unknown address during an
  incident defeats the purpose); rejected in favor of static.

## Decision

Thunderbolt Bridge with static addressing: Mini `bridge0` **10.99.0.1/30**,
MBP **10.99.0.2/30**, no router/DNS configured on the service, service
order below primary interfaces on both machines. Client catalog pins
`10.99.0.1:4747` as the `direct` entry. Bonjour is optional convenience
only. Setup lands in `osx-devbox`/MBP notes when implemented (doc
contract). **Boundary, stated in the docs and the UI: this path exists only
while a cable physically connects the machines** — it is the
walk-over-and-plug-in path unless Q5 reveals permanent adjacency.

## Consequences

Recovery requires physical proximity + a TB4 cable in a known drawer (the
runbook literally lists the drawer); when attached, it's also the fastest
path (40 Gb/s) and failover makes it preferred automatically; macOS treats
the bridge as an ordinary interface so no exotic configuration debt.

## Security implications

The wire is not trusted: mTLS as everywhere (threat T7); static /30 with no
gateway cannot route beyond the pair; no listener beyond 4747/22 changes
its exposure by the link existing.

## Validation required

E3: static-config persistence across reboots/hotplug/sleep, RTT baseline,
route-table hygiene (no default-route capture), behavior with Wi-Fi
disabled both ends, and the failover drill (kill LAN+TS → attach cable →
client converges to direct within one probe cycle).

## Revisit conditions

E3 instability → Ethernet-adapter variant; TB ports become contended by
storage/displays; permanent adjacency (Q5 yes) → revisit path priority and
possibly leave it cabled as primary.
