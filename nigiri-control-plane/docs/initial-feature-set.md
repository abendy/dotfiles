# Initial feature set (v1 — read-only)

Date: 2026-08-01. Rule applied throughout: **no metric without an operational
question**, and no collector whose privilege burden outweighs its answer
(rejections listed at the end). Interfaces cite the validation log
([../spikes/README.md](../spikes/README.md)).

## Menu bar

One template-image glyph (SF Symbols, monochrome per menu-bar convention,
color only in the popover) with five states — the entire point is glanceable
truth without noise:

| State | Meaning (situation-engine output) |
|---|---|
| Healthy | connected, fresh, no active alerts ≥ warning |
| Warning | highest active alert = warning |
| Critical | highest active alert = critical, or `auth_failed` |
| Offline | situation engine names an unreachability (with its layer, in the popover) |
| Stale/Unknown | connected-but-stale, or not yet determined |

No badge counts, no animation except a brief transition pulse. Clicking opens
the popover; option-click opens Diagnostics directly.

**Popover** (top to bottom): node identity line (`nigiri-san · Mac16,10 ·
macOS 26.5.2`) · situation line with confidence and evidence affordance
("Reachable via Tailscale (direct) · heartbeat 4 s ago") · active path +
freshness · highest-severity active alert (tappable → ack) · compact
CPU / load / memory-pressure / swap / disk-free-with-trend / thermal tiles ·
service health strip (agent, SSH, Screen Sharing, Tailscale, Docker, tmux,
configured checks) · last 5 state transitions · footer: last heartbeat,
agent version, buttons for History, Diagnostics, Settings.

## System-state collectors

| Collector (id) | Operational question it answers | Interface (supported) | Interval | Privilege | Confidence |
|---|---|---|---|---|---|
| agent.self | is the observer itself healthy / what version | in-process | 15 s (rides heartbeat) | none | measured |
| system.os | what OS/build is running (did an update land?) | `ProcessInfo`, SystemVersion plist | 1 h | none | measured |
| system.hw | hardware identity for context/inventory | `sysctl hw.model` | boot | none | measured |
| system.boot | did it restart? cleanly? how long up? | `kern.bootsessionuuid`, `kern.boottime` (L2); E5 shutdown-cause | 60 s | none | measured / best_effort (cause) |
| session.console | is a user session present (today's Tailscale/colima depend on it) | `SCDynamicStoreCopyConsoleUser` | 30 s | none | measured |
| session.lock | locked/screensaver state (context for Screen Sharing use) | CGSession dictionary — semi-public | 30 s | none | **best_effort**, labeled |
| system.cpu | is compute saturated (build stuck? runaway proc?) | `host_statistics64` + `getloadavg` | 15 s | none | measured |
| system.memory | pressure/swap — is 24 GB the bottleneck | `DispatchSource.memoryPressure` + `vm.swapusage` + vm stats | 15 s | none | measured |
| system.disk | free-space now + trend (256 GB fills fast; disk-prune cadence enough?) | `statfs` / URL capacity keys | 60 s | none | measured |
| system.thermal | is the M4 throttling (mini in a cabinet…) | `ProcessInfo.thermalState` + notifications | on-change + 60 s | none | measured |
| net.interfaces | which interfaces/addresses exist (Wi-Fi vs future wired, TB link up?) | `getifaddrs` + SCDynamicStore watch | on-change + 60 s | none | measured |
| net.route | what's the default route (did failover happen?) | SCDynamicStore `State:/Network/Global/IPv4` | on-change | none | measured |
| net.egress | can the *Mini* reach the internet (vs everyone else's view) | HTTPS 204 probe + separate DNS-resolve probe → distinguishes DNS-dead from IP-dead | 60 s | none (outbound) | measured |
| net.tailscale | is Tailscale healthy from the inside; peers; DERP home | `tailscale status --json` CLI (L5) | 30 s | none | measured |
| time.sync | is the clock trustworthy (freshness math, TLS, logs depend on it) | SNTP to time.apple.com | 1 h | none (outbound UDP) | measured |
| power.source | AC vs UPS-battery; UPS charge/runtime | `IOPSCopyPowerSourcesInfo` | 60 s / 10 s on battery | none | measured (`no_hardware` today — L2) |
| system.restart-evidence | did it panic / restart unexpectedly | boot-session delta + DiagnosticReports `*.panic` scan (L9) + E5 | at boot + 10 m | none (dir readable unprivileged) | measured (panic) / best_effort (cause) |

Explicitly **deferred**: pending-restart indicator (no supported API — see
threat-model rejections); per-process top-N (value unclear for v1, revisit
with a real question); Wi-Fi RSSI (CoreWLAN needs location-ish entitlements
on modern macOS — privilege ∄ value for a stationary mini).

## Service-state collectors

All config-defined in `agent.toml`; every check is `proc | socket | api |
http` kind; one failing collector isolates (scheduler contract).

| Service | Check | Interface |
|---|---|---|
| nigirid | self (heartbeat, loop lag, journal writes) | in-process |
| SSH | localhost:22 TCP accept | socket probe (L6) |
| Screen Sharing | localhost:5900 TCP accept | socket probe (L6) — availability only; no prefs reading |
| Tailscale | via net.tailscale + process presence | CLI json |
| Docker daemon | Engine API `GET /_ping`, `/info` over configured socket (`~/.colima/default/docker.sock` today — L7; path survives #37 either way) | HTTP-over-UDS |
| Containers | `GET /containers/json?all=1` → state + health per container; config marks which are *expected* running | Engine API |
| tmux | `tmux list-sessions -F '#{session_name}\t#{session_windows}\t#{session_attached}\t#{session_created}'` (structured format strings — stable interface) | CLI, user socket (same uid) |
| launchd jobs | configured label list → `launchctl print gui/501/<label>` + `system/<label>`, minimal parse (state, pid, last exit) — brittleness contained by fixture contract tests (E8) | CLI |
| HTTP/TCP checks | user-defined endpoints (dev servers, future services): status, latency, optional body substring | URLSession / socket |
| Codex | **observation deferred to later phase** — hook-driven design recorded (L8); v1 ships nothing (avoids touching the carefully-stabilized app-server arrangement in remote-workflow.md) | — |

## Alerts shipped in v1

Client-side (origin `inferred`): mini unreachable (all paths) ·
agent-unreachable-while-SSH-answers · active path changed · all remote paths
lost · telemetry stale · auth failed. Agent-side: disk free (warn 15% /
crit 7% or absolute floors) · memory pressure sustained · thermal sustained ·
unexpected restart · container unhealthy/unexpectedly-stopped · configured
check failing · Tailscale unhealthy · UPS on battery / runtime low (inert
until hardware) · collector repeatedly failing · clock drift ·
agent-version mismatch · journal/config errors. Engine semantics (debounce,
hysteresis, dedup, maintenance windows, grouping, rate limits) live in
[observability-and-alerting.md](observability-and-alerting.md).

## Event history view

Client window, backed by the 7-day mirror + client events: connection/path
changes, agent restarts, boots, service transitions, alert lifecycle, config
revisions, collector failures, version changes. Filterable by origin —
the measured/inferred distinction is visible here too. Retention: 7 d client
(config), 30 d agent journal (config), caps per storage doc.

## Diagnostics view (read-only)

Endpoint catalog with live per-path state/RTT/last-error · active + standby
paths and why · probe history sparkline · auth state (cert names, expiry,
scopes) · last protocol error · heartbeat and clock-offset estimate ·
collector health table · agent log tail (redacted, T2) · **Export diagnostic
bundle** (shows file list first; redaction per threat model §Redaction) ·
manual path pin (1 h expiry).

## Deliberately absent from v1

Any remote action (no restart buttons — not even "restart Tailscale"),
Codex integration, witness, iOS anything, MBP-side telemetry, historical
charting beyond sparklines, multi-node UI (model supports it; UI doesn't).
