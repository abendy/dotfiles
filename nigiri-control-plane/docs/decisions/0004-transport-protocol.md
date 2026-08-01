# ADR 0004 — Transport protocol: HTTPS/1.1 + SSE over mutual TLS

- **Status:** proposed (accept after E4)
- **Date:** 2026-08-01

## Context

The protocol needs snapshot pulls, an incremental event stream with replay,
heartbeats, acks, capability negotiation, and room for future typed actions
— over multiple interchangeable network paths, debuggable during incidents.

## Decision drivers

Resumable streaming with a *standard* resume token; incident-time
debuggability (`curl --cert … https://10.99.0.1:4747/v1/snapshot | jq` from
a recovery shell is a feature, not an accident); mTLS maturity; identical
behavior across TB/LAN/TS paths; minimal invention.

## Considered alternatives

- **WebSocket** — bidirectional, but v1's client→agent traffic is plain
  request/response (acks, fetches); WS adds framing/keepalive/proxy quirks
  and loses `Last-Event-ID` resume-for-free. Not needed for actions later
  either (actions are POSTs with their own semantics).
- **Network.framework TCP + custom protocol** — maximum control, full
  protocol invention: framing, resume, auth binding, debug tooling all
  bespoke. Rejected on durability grounds (custom wire formats are where
  personal projects go to die).
- **UDS locally + network gateway** — adopted *partially*: UDS serves
  `nigirictl` locally; a separate gateway process for network would double
  the moving parts for no trust gain (mTLS already provides the boundary).
- **SSH transport (exec/subsystem/tunnel)** — already present, but as the
  *protocol* it couples monitoring to shell-access machinery (contra
  principle 4's separate authz boundaries), multiplexes poorly for SSE-style
  push, and makes "read-only by construction" hard to demonstrate. Retained
  as bootstrap (pairing), break-glass, and diagnostic transport — the brief's
  guardrail agrees.
- **gRPC** — streaming + schemas, but heavyweight deps and opaque-on-the-
  wire; JSON debuggability wins at this scale.

## Decision

HTTPS/1.1 + SSE (protocol doc §2), JSON bodies, TLS 1.3 mutual auth, TCP
4747 on all interfaces, plus UDS for local admin. Hummingbird 2/NIO server;
URLSession client. Capability negotiation reserves binary encodings and
actions without breaking v1.

## Consequences

SSE's one-directional stream + POSTs cover everything with browser-grade
debuggability; HTTP semantics give free correctness (status codes, caching
headers all marked no-store); HTTP/1.1 head-of-line concerns are irrelevant
at one-client scale; port 4747 is arbitrary and configurable.

## Security implications

TLS termination and client-cert verification in one audited stack (NIOSSL);
no unauthenticated endpoints (T0 = handshake only); DoS budget enforced
pre-auth (threat model T14); SSH remains a separately-audited, separately-
authorized channel.

## Validation required

E4 end-to-end spike incl. URLSession client-identity + custom trust
composition (the known-risky corner), SSE resume across simulated failover,
and slow-client backpressure behavior.

## Revisit conditions

Actions phase needs server-push request/response patterns SSE can't express
cleanly (WebSocket reconsidered then, as an *addition* under the same
capability negotiation); multi-node scale changes fan-out economics.
