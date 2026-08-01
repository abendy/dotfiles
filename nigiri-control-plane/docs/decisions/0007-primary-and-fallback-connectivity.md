# ADR 0007 — Primary and fallback connectivity: one identity, ordered multi-path catalog

- **Status:** proposed
- **Date:** 2026-08-01

## Context

Reachability today is a single stack — Wi-Fi → home router → user session →
Tailscale system extension (L4/L5/L6) — every layer of which is a named
failure mode in the brief. The client must reach the same agent identity
over whichever layers survive.

## Decision drivers

Principles 1–3 (useful during partial failure; paths non-binary; failure
discrimination); no path may be a trust boundary (ADR 0005 carries trust);
static addressing must survive total name-resolution failure; the design
must not destabilize the household network.

## Considered alternatives

- **Tailscale-only** (status quo formalized) — one vendor's control plane +
  one session-bound process as the sole window; the exact single-stack
  problem, rejected.
- **VPN-of-VPNs** (WireGuard bare + Tailscale) — a second overlay to
  operate/debug for marginal gain over the LAN+static entries; rejected.
- **SSH tunnels as fallback transport** — couples monitoring to shell authz
  and adds a tunnel manager; SSH stays break-glass instead.
- **Migrate Mini to open-source `tailscaled` now** — pre-login VPN +
  Tailscale SSH support (L5) are real benefits, but it trades away the
  cask-managed convention and GUI-variant support surface mid-project;
  parked as a revisit trigger rather than a prerequisite (auto-login makes
  the gap mostly theoretical today).

## Decision

Client-side connection manager over an ordered endpoint catalog for one
pinned agent identity: **direct-link static (10.99.0.1) > LAN
(reservation/last-known + optional Bonjour hint) > Tailscale MagicDNS >
Tailscale raw IP (100.87.216.112)**, with Phase 4 adding the
LTE-backed path *through* Tailscale rather than beside it. Probing,
7-state path model, hysteresis, and failover-without-duplication per
connectivity doc; situation engine separates reachability from agent
health.

## Consequences

The catalog is config (versionable, incident-editable); raw-IP entries make
DNS a degradation not an outage; per-path probe history is the diagnostic
raw material; probe traffic is a permanent low hum (bounded, ~6 req/min
active) — accepted as the price of truthful freshness.

## Security implications

Every entry authenticates identically (mTLS pinning); `auth_failed`
quarantines a path rather than failing over silently (a MITM attempt on one
path cannot herd the client to another); catalog edits are config-revision
events (attributable).

## Validation required

Phase 2 partition drills (faultlab): each single-layer failure yields the
correct named situation and the correct surviving path within 3 probe
cycles; flap tests under loss; failover replay-duplication test.

## Revisit conditions

Logout-survival or Tailscale-SSH need flips the tailscaled migration
(catalog absorbs it transparently); IPv6-only or CGNAT changes at home
alter direct-path assumptions; multi-node era may want mesh-aware
prioritization.
