# Testing strategy

Date: 2026-08-01. Principle: the failure-mode matrix is the test plan's
source of truth — every matrix row eventually maps to an automated or
scripted-manual test, and "we believe X recovers" is not done until the
faultlab has watched it recover.

## Layers

**Unit (swift-testing, per module).** Model coding/decoding, envelope rules,
alert-policy state machines (raise/sustain/hysteresis/resolve tables as
parameterized cases), retention math, redaction scrub (canary corpus: seeded
fake keys/tokens must never survive), situation-engine truth table
(path-states × agent-facts × staleness → exactly one situation).

**Protocol compatibility.** Golden-file fixtures for every v1 message pinned
forever; a v1-frozen decoder test target proves future changes stay
additive. Unknown-field and unknown-event-type tolerance tests. Skew matrix:
{old client, new agent} × {new client, old agent} against capability
negotiation.

**Collector contracts.** Each collector runs against recorded fixtures of
its interface (captured `tailscale status --json` for healthy/degraded/
logged-out, `launchctl print` output per OS build — E8's drift watch,
Docker Engine API responses incl. colima quirks, tmux format output, sysctl
values, DiagnosticReports trees). Contract = parses, labels confidence,
degrades to structured error on malformed input — never throws past the
scheduler. Fixture recapture is a scheduled chore after each macOS update
(the drift is the point: fixtures diffing = interface moved).

**Storage.** GRDB migration ladder tests (every historical schema → head);
forward-compat test (vN binary opens vN+1 DB per rollback policy); WAL
crash-consistency (kill -9 mid-write loops); corruption drills (bit-flipped
DB → epoch rotation + gap event, moved-aside file intact); retention-cap
property tests (never exceeds size/age budget under event floods);
idempotent-replay property tests (duplicate/out-of-order/overlapping SSE
replays converge to identical mirror).

**Auth.** Handshake matrix: no cert / expired / revoked / wrong-key /
correct — expected states each time (`auth_failed` distinctness); pairing
ceremony end-to-end over a throwaway SSH container-pair; revocation takes
effect on live SSE stream; scope enforcement (T1 cert vs T2 endpoint);
rate-limit behavior under handshake floods (DoS budget from threat model).

## faultlab — the repeatable failure harness

A `faultlab/` CLI (dev-only, not shipped) that makes matrix rows
push-button instead of "go unplug the router":

- **Network faults (MBP-side, pf/dnctl):** per-path block, latency, loss —
  anchors keyed by destination (100.87.216.112, LAN IP, 10.99.0.1) so
  "Tailscale dead but LAN alive," "DNS dead but IPs alive" (block :53 +
  100.100.100.100), "everything dead" are one command each, with automatic
  teardown timers so a forgotten fault can't strand the dev machine.
- **Agent faults (over SSH):** kill -9 / -STOP (wedge, exercises watchdog)
  / crashloop binary swap / journal chmod / disk-full via quota file /
  clock-set (protocol-level skew tests use injected clocks instead where
  possible).
- **VM Mini (Virtualization.framework, e.g. Tart) on the MBP:** a macOS VM
  running the real agent for destructive drills real hardware shouldn't
  host: reboot loops, logout/login cycles, sleep/wake, Tailscale process
  kill, interface removal, snapshot/restore for repeatability. Known
  fidelity limits (no SE, thermal/UPS/TB unavailable) — those specific
  collectors get hardware-only test days instead.
- **Chaos soak:** 72 h run with a scripted schedule of random faults; pass =
  zero false Critical, zero stuck alerts, zero duplicate events, bounded
  DBs, agent memory flat.

**Scheduled real-hardware drills** (calendared, twice yearly + after macOS
majors): actual Mini reboot, actual router power-cycle, TB-link recovery
walk-through, update+rollback rehearsal, restore-from-stolen-MBP (revoke +
re-pair). Each drill's expected client display is written down first; drift
between expectation and display is a bug in one of them.

## Security tests (recurring)

Invariant greps in CI (no string-exec in process-runner, no new entitlements
diff, dependency-pin diff review); bundle-redaction canary; unauthenticated
surface scan (nmap-style: only 4747 TLS + SSH expected); replay of captured
SSE stream against a fresh client (must dedupe); downgrade attempt
(`/v0/`, garbage `Last-Event-ID`, oversized bodies) → clean refusals.

## Ordering

Phase 0 exit needs: E2/E3/E4 spike evidence. Phase 1 exit needs: unit +
protocol + storage suites green in CI (GitHub Actions, macOS runner) +
first faultlab network profiles. The VM lab and full chaos soak are Phase 2
exit criteria, because that's when the connection manager's claims become
load-bearing.
