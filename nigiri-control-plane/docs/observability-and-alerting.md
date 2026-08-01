# Observability and alerting

Date: 2026-08-01. Two subjects: how alerts behave (so a month of unattended
operation produces signal, not noise), and how the observer observes itself.

## Alert engine placement

The **agent** owns alerts about the Mini (it has the data and keeps working
while the client is away — alerts raised offline are journal events the
client replays on reconnect, satisfying "alert occurred while MBP was
offline" for every case except total-Mini-death, which is Path D's job).
The **client** owns alerts about reachability and staleness (the agent cannot
report its own unreachability). Both engines share one policy vocabulary so
behavior is uniform.

## Alert semantics

- **Severity**: `info` (journal only, no notification) · `warning` ·
  `critical`. Severity is per-policy, escalation is a new event on the same
  alert_id (dedup key), never a second alert.
- **Debounce / sustain**: every threshold rule carries `sustain_s` — the
  condition must hold continuously (evaluated per sample) before raising.
  Single-sample raises are reserved for intrinsically critical events
  (unexpected restart, journal corruption, auth failure, UPS on battery).
- **Hysteresis**: distinct raise/resolve thresholds (e.g. disk warn raises
  <15%, resolves >18%) so oscillation at a boundary can't flap.
- **Duration floors on resolve**: `resolve_sustain_s` (default 120 s) before
  emitting `resolved`, same reason.
- **Deduplication**: alert identity = `(kind, subject)`; re-evaluation
  updates evidence on the open alert rather than raising anew.
- **Suppression & dependencies**: a `mini_unreachable` situation suppresses
  notification (not evaluation) of per-service client-side derivatives;
  agent-side, `docker.container.*` alerts suppress under `svc.docker` down
  (the parent alert carries the story). Suppressed alerts still journal with
  `suppressed_by` so nothing is invisible in history.
- **Maintenance windows**: config-defined (`starts, ends, subjects glob`);
  matching alerts raise as `info` with `maintenance: true`. Entering a window
  is itself a journal event (attributable intent).
- **Acknowledgement**: user event via `POST /v1/acks`; an acked alert stops
  re-notifying but stays visibly active until resolved. Acks are attributed
  (`client:mbp-allan`) and journaled — they're part of history.
- **Notification grouping & rate limiting**: client groups by alert_id
  thread; global notification budget (default 6/hour, critical exempt) with
  an overflow summary notification ("3 more warnings suppressed — open
  History"). Re-notify on escalation only, or every 4 h for unacked critical.
- **Evidence attached**: every raise carries the samples/probe results that
  crossed the policy (bounded: ≤10 items, ≤4 KB) — the popover's "why"
  affordance renders these, satisfying principle 8 without log-reading.

### Default thresholds (config-revisable, all in `agent.toml` / `client.toml`)

| Alert | Raise | Sustain | Resolve | Severity |
|---|---|---|---|---|
| disk_free_low | <15% or <25 GiB | 10 m | >18% | warning |
| disk_free_critical | <7% or <12 GiB | 2 m | >9% | critical |
| memory_pressure | level ≥ warn | 5 m | normal | warning (critical if `critical` level 60 s) |
| thermal_pressure | ≥ serious | 5 m | nominal | warning (critical at `critical` any) |
| cpu_saturated | load1 > 2×cores | 15 m | <1.5× | info→warning |
| tailscale_unhealthy | Health[] nonempty or BackendState ≠ Running | 2 m | healthy | warning |
| container_unhealthy | health=unhealthy or expected-not-running | 2 m | healthy/running | warning |
| check_failing | configured check fails | 3 samples | 2 ok | warning |
| collector_failing | 3 consecutive errors | — | 1 ok | warning (info first failure) |
| clock_drift | abs offset > 2 s | 2 samples | <1 s | warning |
| telemetry_stale (client) | no fresh data > 90 s while path available | — | fresh | warning |
| mini_unreachable (client) | all paths non-available | 3 probe cycles | any path ok | critical |
| agent_down_host_up (client) | protocol dead + SSH banner answers | 2 cycles | protocol ok | critical |
| auth_failed (client) | any pinning/cert rejection | immediate | manual | critical |
| unexpected_restart | boot session changed w/o clean-shutdown evidence | immediate | ack | warning |
| journal/config error | on occurrence | immediate | healthy write / valid load | warning–critical |
| ups_on_battery / ups_runtime_low | on event / < 10 m runtime | immediate | AC restored | warning / critical |

## Observability of the observer

**Agent self-metrics** (in every heartbeat; history in journal; full dump via
`GET /v1/health` and `nigirictl status` over UDS — inspectable both through
the protocol and locally, as required):

- event-loop lag (watchdog aborts >30 s wedge; launchd revives; next boot
  journals `agent_restart {reason: watchdog}`)
- per-collector: last run, duration percentile, consecutive failures, state
- journal: seq, bytes, last-write latency, retention marks, epoch
- event-queue depth (scheduler → journal backpressure signal)
- connected clients (count + names + negotiated versions)
- listener state per socket (bound/failed — a failed :4747 bind is a
  critical self-alert)
- cert days-remaining (self + known clients)
- config revision + validation state
- last successful witness post (Phase 4)

**Client self-metrics** (diagnostics view + its own log): render loop health,
notification-delivery failures (UNUserNotificationCenter errors — surfaced,
since a monitoring app that can't notify is broken in the worst silent way),
cache DB state, probe-scheduler health, last SSE event age.

**Meta-alerting rule**: collector_failing, journal_error, config_error,
listener-bind failure, and notification-delivery failure are all alerts
*themselves* — the system may degrade, silently never. The final backstop is
architectural: heartbeats stop ⇒ client staleness/unreachable alerts fire ⇒
worst-case failure mode of the whole system is a *loud* unknown, not a quiet
green.

## Logging

`swift-log` → os.log (unified logging) on both processes + a bounded local
file ring (10 MB × 3) for the redacted tail endpoints. Levels: notice for
lifecycle, info for transitions, debug off by default. The redaction scrub
(threat model) runs at emission for anything leaving the process. Log noise
budget: steady-state healthy operation should write < 1 line/min at notice.
