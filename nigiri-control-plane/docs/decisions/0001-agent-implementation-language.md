# ADR 0001 — Agent implementation language: Swift

- **Status:** proposed (accept after E2/E4)
- **Date:** 2026-08-01

## Context

The Mini agent is a long-lived daemon reading macOS-specific state (Mach
host statistics, IOKit power sources, SCDynamicStore, DispatchSource
pressure events, launchd, DiagnosticReports) and serving an mTLS API. It
must build on the Mini itself with Command Line Tools only (no Xcode — L1),
run for years with minimal maintenance, and share protocol/model code with
the MBP client.

## Decision drivers

Native access to the exact APIs most collectors need; one language across
agent, CLI, and client (shared `NCPModel`/`NCPStore`/`NCPTransport`
modules — zero protocol drift); repo precedent (disk-prune is SwiftPM with a
menu-bar executable, proving the toolchain path); code signing/notarization
native; small dependency surface; single-maintainer sustainability.

## Considered alternatives

- **Go** — the strongest rival: superb daemon ergonomics, trivial static
  binaries, and uniquely `tsnet` (embedding a Tailscale listener directly in
  the agent). Costs: every macOS-specific collector goes through cgo or
  shelling out — the majority of v1's collector value sits behind C/ObjC
  frameworks; a second language splits the codebase from the SwiftUI client;
  protocol types duplicate. `tsnet` is genuinely attractive but optional —
  the agent listens on the OS's Tailscale interface regardless of variant.
- **Rust** — memory safety without GC and good TLS stacks; macOS framework
  access via bindings is workable but the binding maintenance lands on the
  maintainer; no client-code sharing; slowest path to working software here.
- **Python** — explicitly rejected for production per the brief's guardrail:
  runtime dependency management on a machine we're trying to make *more*
  deterministic, weak macOS API story, packaging pain for daemons.
  Permitted for throwaway probes only.

## Decision

Swift 6 (strict concurrency) for agent, CLI, and client, one SwiftPM
package. Server stack: SwiftNIO via Hummingbird 2 (revisit to hand-rolled
NIO if E4 finds the dependency heavier than its value).

## Consequences

Shared model code makes protocol changes one edit; collectors call
frameworks directly (fewer subprocesses, fewer parsing seams); server-side
Swift is a smaller ecosystem than Go's — mitigated by the tiny HTTP surface
(7 endpoints + SSE) and E4 proving it early; build times on the M4 are
acceptable (disk-prune evidence).

## Security implications

Memory-safe language; dependency budget stays ~4 pinned packages (supply-
chain T11); no cgo/FFI layer to audit; codesigning/HR native.

## Validation required

E4 (Hummingbird mTLS+SSE spike), E2 (daemon lifecycle), CI build on macOS
runner from clean checkout with CLT-equivalent toolchain.

## Revisit conditions

E4 fails to get client-cert mTLS working cleanly in NIOSSL; or a future
requirement (embedded tsnet-style listener, cross-platform node support)
outweighs the shared-code advantage — Go becomes the fallback with a
JSON-schema-frozen protocol as the compatibility contract.
