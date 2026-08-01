# ADR 0005 — Application authentication: mutual TLS with pinned per-device keys, SSH-anchored pairing

- **Status:** proposed (accept after E4/E6)
- **Date:** 2026-08-01

## Context

Authentication must bind to device identity (not IP/network position), work
identically on every path, survive DNS/Tailscale failure, keep telemetry and
future actions behind separate authorization, and stay recoverable after
credential loss — for exactly two parties today.

## Decision drivers

Principle 5 (Mini secure despite compromised MBP/path); transport-
independent trust; no new trust roots (SSH already exists and is already
sacred); offline verifiability (no CA/OCSP infrastructure to be down during
an incident); human-verifiable ceremony.

## Considered alternatives

- **Private CA + issued certs** — machinery for open-ended device
  populations; adds a root key to protect and a revocation transport to
  operate. Two devices don't need it; the *scopes* benefit of certs is kept
  without the CA.
- **Bearer tokens/API keys** — replayable if exfiltrated, no channel
  binding, weaker theft story than Keychain/SE-held private keys.
- **SSH-key reuse as app credential** — tempting (keys exist) but collapses
  the authz boundary the brief demands: possession of shell access would
  *be* possession of telemetry access, and future action scopes would have
  nowhere to live.
- **Tailscale identity as sole credential** — makes the tailnet's control
  plane the app's root of trust (contra threat T4) and dies with Tailscale
  on exactly the paths designed to survive it. Kept as defense-in-depth
  (ACL/grants narrowing reachability).

## Decision

Per-device P-256 keys (SE-backed where E6 allows; Keychain/0600-file
otherwise) in self-signed certs carrying scope claims; TLS 1.3 mutual auth;
**bidirectional SPKI pinning** established by a one-time pairing ceremony
over existing SSH with a 6-word fingerprint phrase confirmed on both ends.
Scopes: `telemetry:read`, `diagnostics:read` issued in v1; `actions:*`
defined, never issued. Expiry 24 months; rotation by overlapped re-pair;
revocation via `nigirid clients revoke` (SSH or local); recovery = re-pair
(SSH is the recovery root, matching the parent repo's key model).

## Consequences

No PKI to operate; `auth_failed` is an unambiguous, non-retryable state
(security signal, per connection-manager rules); adding the iOS client
later = one more enrollment with narrower scopes; losing *SSH* remains the
true lockout (unchanged from today — physical access recovers it).

## Security implications

Pairing compromise requires prior SSH compromise; stolen-MBP window bounded
by revocation runbook + Keychain protections; scope claims make T3/T4
actions additive without re-authenticating the world; no secrets transit
except during the SSH-wrapped ceremony.

## Validation required

E4 (NIOSSL client-cert verify + URLSession identity); E6 (SE key in daemon
context); ceremony usability dry-run (do the 6 words actually get read?);
revocation-during-live-SSE test.

## Revisit conditions

Device count grows past ~4 (CA machinery starts paying rent); Apple ships
managed device attestation usable peer-to-peer; scopes need per-action
granularity finer than cert reissue comfortably handles (move scopes to a
signed grant file consulted at authz time).
