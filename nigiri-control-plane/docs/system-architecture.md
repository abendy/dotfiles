# System architecture

Date: 2026-08-01. Decisions referenced here are argued in
[decisions/](decisions/); platform facts carry receipts in
[../spikes/README.md](../spikes/README.md) (L-numbers).

## 1. Shape of the system

```
┌────────────────────────── MacBook Pro (controller) ──────────────────────────┐
│  Nigiri Control.app (menu bar, SwiftUI)                                      │
│  ┌───────────┐ ┌──────────────┐ ┌──────────────┐ ┌────────────────────────┐  │
│  │ MenuBar & │ │ Situation    │ │ Connection   │ │ Local cache (SQLite)   │  │
│  │ popover   │ │ engine       │ │ manager      │ │ snapshot + 7d events   │  │
│  │ UI        │ │ (fail-state  │ │ (endpoint    │ │ prefs (UserDefaults)   │  │
│  │           │ │  inference)  │ │  catalog,    │ │ client key (Keychain)  │  │
│  └───────────┘ └──────────────┘ │  probes,     │ └────────────────────────┘  │
│        │  UserNotifications     │  failover)   │                             │
└────────┼───────────────────────┴┬─────────────┴──────────────────────────────┘
         │        mTLS HTTPS/1.1 + SSE, JSON, port 4747
         │   over any of: Thunderbolt link · LAN · Tailscale (direct/DERP)
         ▼
┌────────────────────────── Mac mini `nigiri-san` (managed) ───────────────────┐
│  nigirid (LaunchDaemon, runs as `nigiri`, no GUI dependency)                 │
│  ┌────────────┐ ┌───────────┐ ┌──────────────┐ ┌───────────┐ ┌────────────┐  │
│  │ Collector  │ │ Health &  │ │ Event        │ │ API       │ │ Self-      │  │
│  │ scheduler  │→│ alert     │→│ journal      │→│ server    │ │ observer   │  │
│  │ (adapters) │ │ engine    │ │ (SQLite WAL) │ │ (NIO/     │ │ (watchdog, │  │
│  └────────────┘ └───────────┘ └──────────────┘ │ Hummingbird│ │  health)   │  │
│        │ reads supported interfaces only        └───────────┘ └────────────┘  │
│        ▼                                          ▲ UDS                       │
│  sysctl/Mach/IOKit/SCDynamicStore APIs,           │                           │
│  tailscale CLI --json, Docker Engine API,     nigirictl (local admin/        │
│  tmux -F, launchctl print, DiagnosticReports  pairing/diagnostics CLI)       │
└──────────────────────────────────────────────────────────────────────────────┘
         ▲ SSH (existing) — bootstrap, pairing, recovery, break-glass. Not the protocol.
         △ Phase 4: outbound-only witness heartbeat (dead-man switch)
```

Three trust observations anchor everything:

- The **agent is the source of truth about the Mini**; the **client is the
  source of truth about reachability**; **absence of data is evidence**, and
  the client's situation engine treats it as such rather than as an error.
- Transport choice never changes trust: every path carries the same mutual-TLS
  identity check (ADR 0005), so failover is a routing decision, not a
  security decision.
- SSH remains the out-of-band root of trust for pairing, revocation, and
  recovery. The system must never make SSH access *less* available, and no
  update flow may remove it as a fallback.

## 2. MBP client — Nigiri Control

**Framework.** SwiftUI app with `MenuBarExtra` (macOS 13+, verified L10) in
`.window` style for the rich popover; `LSUIElement` so no Dock icon. AppKit is
allowed where SwiftUI falls short — expected spots: `NSStatusItem` fallback if
`MenuBarExtra` styling proves too rigid (known limitation area; decide in
Phase 1, both wrap the same view model), `NSWorkspace` for opening
`vnc://nigiri-san` / Terminal handoffs in later phases. Separate scenes: a
**Settings** window (standard `Settings` scene) and a **Diagnostics** window
(regular `Window` scene, closable, holds the path/probe/log views — too dense
for a popover).

**Background behavior.** Registered as a login item via `SMAppService.mainApp`
(L10); menu-bar apps are not App-Nap-exempt by magic — the connection manager
uses `URLSession` background-tolerant timers (`Timer` on the main run loop
plus `beginActivity(.userInitiated)` only while a probe burst runs) so the app
stays honest about power. The app is expected to run whenever the user is
logged in; a closed app means no monitoring — that is acceptable on the
controller side and shows up as staleness, never as false "healthy."

**Local state.**
- Keychain (default `kSecAttrAccessibleAfterFirstUnlock`, non-synchronizable):
  client private key + pinned agent SPKI. Secure-Enclave-backed if E6 shows
  the API path is workable from the app (it should be; the daemon-side
  question is the risky one).
- SQLite (GRDB, WAL) at `~/Library/Application Support/nigiri-control-plane/
  cache.sqlite`: last snapshot, rolling 7-day event mirror, ack ledger,
  path-probe history for the diagnostics view.
- `UserDefaults` for presentation prefs only — never secrets, never endpoints
  (endpoints live in the config file so they're versionable; see §5).

**Notifications.** `UserNotifications` framework; one authorization prompt on
first run (the app's only TCC surface). Grouped by alert identity;
re-notification governed by the alert engine's escalation rules, not by every
SSE event.

**Signing/updates.** Developer ID + notarization recommended (open question
Q2 — costs $99/yr); Sparkle 2 or build-from-repo as the update channel
(ADR 0010). Hardened Runtime on regardless.

## 3. Mini agent — nigirid

**Process model (ADR 0003).** One binary, installed as a classic LaunchDaemon
(`/Library/LaunchDaemons/com.abendy.nigiri-control-plane.agent.plist`,
`UserName nigiri`, `KeepAlive`, `ProcessType Background`). Rationale in brief:
survives logout and starts pre-login (unlike everything currently on the
machine — L6), avoids root entirely, and uid-501 execution is what lets the
colima socket, tmux socket, and Codex artifacts remain readable without any
privilege grants (L7, L8). SMAppService-based registration needs a GUI
approval flow — wrong fit for a headless machine; plist installation over SSH
is the deliberate choice, validated by E2. A per-user *session helper* is a
designed extension point (UDS ingest, §4) for the day a collector genuinely
needs the GUI session; v1 has none.

**Internal structure.** Swift 6 strict concurrency; actors own state:

- `CollectorScheduler` — per-collector `Task` loops with intervals, jitter,
  per-run timeout, and consecutive-failure backoff. One failing collector
  never blocks another (isolation requirement from the brief).
- `HealthEngine` — receives samples, evaluates alert policies (debounce,
  duration, hysteresis — see observability doc), emits state transitions.
- `Journal` — single writer actor over GRDB/WAL; assigns the global
  monotonic `seq`; enforces retention; owns the journal-epoch identity.
- `APIServer` — Hummingbird 2 on NIO (ADR 0004): mTLS listener on :4747 (all
  interfaces; authorization is cryptographic, not topological), UDS listener
  for `nigirictl` (filesystem-permission auth, 0700 directory).
- `SelfObserver` — watchdog, event-loop lag, collector stats, DB stats, cert
  expiry; exports through both the protocol and `nigirictl status`.

**Collector boundary (the plugin seam).** A collector is a Swift type
conforming to:

```swift
protocol Collector: Sendable {
  static var id: CollectorID { get }          // "system.cpu", "svc.docker"…
  static var schemaVersion: Int { get }
  var interval: Duration { get }              // from config
  func collect(_ ctx: CollectorContext) async throws -> [Sample]
}
```

Compiled-in, registry-instantiated from config — **no dynamic loading in v1**
(dylib plugins are a supply-chain and stability liability; the seam is the
protocol, not a loader). `CollectorContext` provides the only capabilities a
collector gets: a process-runner restricted to an allowlisted absolute-path
command table (e.g. `/usr/local/bin/tailscale`), an HTTP/UDS client factory,
and file readers restricted to declared path prefixes. That containment is
enforcement-by-construction against the "malicious collector" threat within
the limits of in-process code — the honest statement is that compiled-in
collectors are trusted code, and the context keeps them *honest by review*,
not sandboxed. True isolation (spawned collector processes) is the recorded
evolution if third-party collectors ever appear.

Supported-interface rule (design principle 9): every collector reads a
documented API or stable CLI surface — the per-collector table with its
privilege budget lives in [initial-feature-set.md](initial-feature-set.md).
No UI scraping, no AppleScript, no private frameworks.

**Journal.** SQLite WAL at `~/Library/Application Support/
nigiri-control-plane/journal.sqlite` (DDL in
[protocol-and-data-model.md](protocol-and-data-model.md)): `events` (global
`seq` via AUTOINCREMENT — survives reboots, never reused), `samples` (raw,
48 h) + `samples_5m` rollups (30 d), `alerts`, `clients`, `meta`
(journal_epoch UUID, config revision, schema version). Caps: 500 MB or 30
days, whichever first; enforcement runs in the journal actor so a
disconnected client can never grow the disk unboundedly (client replay is
best-effort within the window — an explicit `journal_gap` event tells the
client when it lost history). `PRAGMA quick_check` at open; on corruption:
move file aside, start a fresh epoch, raise `journal_error` alert, keep
serving live state (degrade gracefully for observation).

**Own health.** `launchd KeepAlive` restarts crashes; an internal watchdog
aborts the process if the event loop wedges >30 s (launchd revives it; the
next start writes an `agent_restart {reason: watchdog}` event — attributable
evidence). Version, uptime, and self-metrics ride every heartbeat.

## 4. Boundaries that make later phases additive

- **Actions**: the protocol reserves `POST /v1/actions/{verb}` semantics and
  a `capabilities.actions` list that v1 serves as `[]`. Scopes for them exist
  in the cert profile now (`actions:*` never issued in v1). Adding actions
  means adding verbs + policy, not reshaping the protocol. Fail-closed rule:
  unknown verb, missing scope, or stale request timestamp → refuse.
- **Session helper**: UDS ingest endpoint (`POST /internal/ingest`, UDS-only)
  accepts collector samples from same-uid processes; v1 ships the endpoint
  disabled by config. Codex hooks (L8) will later post lifecycle events here.
- **Witness**: `WitnessReporter` interface (outbound-only) with a null
  implementation in v1 (ADR: connectivity doc §Path D).
- **Multi-node / iOS**: node identity is explicit in every message envelope;
  the client's stores key by `node_id` even though exactly one exists.

## 5. Configuration model

Single TOML file per machine, versioned in this repo as templates (matching
disk-prune's `~/.config/disk-prune/config.json` convention):

- Mini: `~/.config/nigiri-control-plane/agent.toml` — node identity,
  listeners, collector enable/intervals, service & health-check definitions,
  alert thresholds, retention, redaction rules, witness (off), feature flags.
- MBP: `~/.config/nigiri-control-plane/client.toml` — endpoint catalog with
  path classes and priorities (including the static direct-link address —
  reachable with DNS fully dead), probe cadence, notification prefs, manual
  path pin.

Rules: schema-versioned (`config_version`), validated by `nigirictl config
validate` before use; the agent loads to a staging copy and swaps atomically
on success (bad config → keep last-good + `config_error` alert — the agent
never fails to start over a typo); every applied revision hashes into a
`config_changed` event. Secrets never live in config files — Keychain on the
MBP, `0600` key files under `~/Library/Application Support/
nigiri-control-plane/keys/` on the Mini (E6 may upgrade this to SE-backed).
What belongs where (UI vs file vs Keychain) is tabulated in
[open-questions.md](open-questions.md) §Q6 with the proposed split.

## 6. Module layout (SwiftPM, one package)

```
nigiri-control-plane/
  Package.swift
  Sources/
    NCPModel/        // pure types: messages, entities, versioning — no I/O
    NCPStore/        // GRDB schemas, migrations, retention (agent+client share)
    NCPTransport/    // mTLS config, pinning, SSE encode/decode, UDS helpers
    NCPAgentCore/    // scheduler, health engine, journal, server glue
    NCPCollectors/   // one file per collector + contract-test fixtures
    nigirid/         // daemon executable
    nigirictl/       // admin CLI executable
    NigiriControl/   // MBP menu-bar app (SwiftPM-built bundle, disk-prune style)
  Tests/             // per-module + protocol golden files + faultlab fixtures
  launchd/           // plist templates
  config/            // agent.toml / client.toml templates
  install.sh         // Mini-side build+install (Phase 1)
  spikes/            // experimental evidence only
```

Client and agent share `NCPModel`/`NCPStore`/`NCPTransport` — one language,
one protocol definition, zero codegen drift (a decisive driver in ADR 0001).
Dependency budget is deliberately small and pinned by `Package.resolved`:
GRDB, Hummingbird/NIO, TOMLKit, swift-log. Each addition needs an ADR note
(supply-chain threat T11).
