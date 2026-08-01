# Protocol and data model

Date: 2026-08-01. Wire format: **JSON over HTTPS/1.1 + Server-Sent Events,
mutual TLS, port 4747** (ADR 0004 holds the transport comparison). JSON is
chosen for a one-user system where `curl`-ability during an incident beats
marginal encoding efficiency; a binary encoding would be a v2 capability
flag, negotiated, if ever needed.

## 1. Versioning and compatibility

- **Path version** `/v1/...`: breaking changes bump it; v1 rules are
  additive-only (new fields, new event types, new endpoints).
- **Envelope `v`**: schema version of the message body (per-type integer).
- **Capability negotiation**: client calls `GET /v1/capabilities` first;
  both sides log the intersection. Unknown fields are always ignored;
  unknown *event types* are stored raw by the client (forward-compatible
  journal mirror) and rendered generically ("event of unknown type X").
- **Skew policy**: agent and client each declare `min_peer` versions;
  incompatibility is a *displayed state* ("client too old for agent — update
  path: …"), never a silent failure. Version identifiers ride every
  heartbeat, so skew is observable, alertable (`agent_version_mismatch`),
  and testable (golden-file tests pin v1 forever).

## 2. HTTP surface (v1)

| Method + path | Tier | Purpose |
|---|---|---|
| `GET /v1/capabilities` | T1 | versions, features, collector list, action list (`[]` in v1) |
| `GET /v1/ping` | T1 | 200-byte probe: node_id, boot_session, seq, agent time |
| `GET /v1/snapshot` | T1 | full current state (all latest samples + active alerts + paths agent knows) |
| `GET /v1/events?since=SEQ` (SSE; `Last-Event-ID` also honored) | T1 | journal replay from SEQ+1 then live tail; heartbeat events every 15 s |
| `POST /v1/acks` | T1 | acknowledge alerts (attributed) |
| `GET /v1/health` | T1 | agent self-diagnostic (same body as `nigirictl status`) |
| `GET /v1/diagnostics/bundle` | T2 | streamed redacted bundle (tar.zst) |
| `GET /v1/log?tail=N` | T2 | redacted agent log tail |
| *(reserved)* `POST /v1/actions/{verb}` | T3/T4 | 404 in v1; shape frozen now: `{request_id, nonce, issued_at, params}` so adding verbs is additive |
| UDS-only `POST /internal/ingest` | same-uid | future session-helper/Codex-hook sample ingest (disabled by default in v1) |

## 3. Envelope

Every event and every snapshot section shares:

```json
{
  "v": 1,
  "type": "state_transition",
  "seq": 48211,
  "node_id": "ncp-node-7f3a2b",
  "boot_session": "0FFC5AA7-6DBE-45AB-8B20-F7A53703AA30",
  "journal_epoch": "e1a9c2d4",
  "origin": "agent",
  "collected_at": "2026-08-01T14:03:22.114Z",
  "payload": { }
}
```

`origin` ∈ `agent | client | user | inferred` — the wire form of the
fact/observation/inference taxonomy (§7). Client-side receipt adds
`received_at` locally (never trusts the wire for it). `seq` is present on
journal events only; snapshots carry `as_of_seq` instead.

## 4. Representative messages

**Capabilities response**

```json
{
  "v": 1, "protocol": ["v1"], "agent_version": "0.3.1",
  "min_peer": "0.2.0",
  "features": ["sse", "replay", "ack", "bundle", "health"],
  "actions": [],
  "collectors": [
    {"id": "system.cpu", "schema": 1, "interval_s": 15, "state": "ok"},
    {"id": "svc.docker", "schema": 1, "interval_s": 30, "state": "ok"},
    {"id": "power.ups", "schema": 1, "interval_s": 60, "state": "no_hardware"}
  ],
  "node": {"node_id": "ncp-node-7f3a2b", "hostname": "nigiri-san",
            "hw_model": "Mac16,10", "os_build": "25F84"}
}
```

**Heartbeat event** (SSE `id: 48213`)

```json
{ "v":1, "type":"heartbeat", "seq":48213, "origin":"agent",
  "boot_session":"0FFC5AA7-…", "journal_epoch":"e1a9c2d4",
  "collected_at":"2026-08-01T14:03:30.002Z",
  "payload": {
    "agent_version":"0.3.1", "uptime_s":85507, "agent_uptime_s":3822,
    "clock":{"ntp_offset_ms":-14,"last_sync":"2026-08-01T13:41:02Z"},
    "self":{"loop_lag_ms":2,"queue_depth":0,"clients":1,
            "journal":{"seq":48213,"bytes":18734080,"last_write_ms":3},
            "collectors":{"ok":14,"degraded":1,"failed":0},
            "cert_days_left":591}
  }}
```

**Metric sample** (batched inside `samples` events; also the snapshot atom)

```json
{ "metric":"disk.root.free_bytes", "value":147102003200, "unit":"bytes",
  "collector":"system.disk", "schema":1,
  "collected_at":"2026-08-01T14:03:25.001Z",
  "freshness_s":5, "confidence":"measured", "error":null }
```

`confidence` ∈ `measured | derived | best_effort | stale | unavailable` —
e.g. screen-lock state ships as `best_effort` (L-note: no fully public API),
UPS as `unavailable` until hardware exists. `error` carries a structured
`{code, message}` when a collector degrades, so absence-of-value is explained
in-band.

**State transition**

```json
{ "v":1,"type":"state_transition","seq":48214,"origin":"agent",
  "collected_at":"2026-08-01T14:04:01.330Z",
  "payload":{"subject":"svc.tailscale","from":"ok","to":"degraded",
    "evidence":{"BackendState":"Running","Health":["router: no default route"]},
    "policy":"svc.tailscale.health_nonempty_120s"}}
```

**Alert lifecycle** (raised → acknowledged → resolved; one type, `phase`)

```json
{ "v":1,"type":"alert","seq":48215,"origin":"agent",
  "collected_at":"2026-08-01T14:06:01.400Z",
  "payload":{"alert_id":"al-9f21","phase":"raised","severity":"warning",
    "kind":"disk_free_low","subject":"disk.root",
    "summary":"Root volume below 15% free (13.9%)",
    "evidence":[{"metric":"disk.root.free_pct","value":13.9,
                  "threshold":15,"sustained_s":600}],
    "policy_rev":"cfg-2026-08-01-a"}}
```

```json
{ "v":1,"type":"alert","seq":48291,"origin":"user",
  "collected_at":"2026-08-01T14:09:12.000Z",
  "payload":{"alert_id":"al-9f21","phase":"acknowledged",
    "actor":"client:mbp-allan","note":"pruning tonight"}}
```

**Ack request/response** (`POST /v1/acks`)

```json
{"acks":[{"alert_id":"al-9f21","acked_at":"2026-08-01T14:09:11.512Z",
           "actor":"client:mbp-allan","note":"pruning tonight"}]}
```
→ `207`-style per-item result: `{"results":[{"alert_id":"al-9f21","status":"recorded","seq":48291}]}`
(idempotent: re-acking returns `already_acknowledged` + original seq).

**Client-origin observation** (stored only in the client DB; same envelope,
`origin:"client"`, no `seq`)

```json
{ "v":1,"type":"path_changed","origin":"client",
  "collected_at":"2026-08-01T14:11:40.100Z",
  "payload":{"from":"tailscale","to":"lan","reason":"probe_failures",
    "evidence":{"tailscale":{"consecutive_failures":2,"last_rtt_ms":null},
                 "lan":{"rtt_ms":3.1}}}}
```

**Error envelope** (all non-2xx)

```json
{"error":{"code":"auth_expired","message":"client certificate expired 2026-07-30",
           "retryable":false}}
```

## 5. Replay, ordering, and idempotency

- `seq` is a **journal-global monotonic integer** (SQLite AUTOINCREMENT —
  monotonic across reboots, never reused). SSE `id:` = seq; reconnection on
  any path sends `Last-Event-ID`, agent streams `seq+1…` from the journal,
  then goes live. Client applies `INSERT OR IGNORE` by seq — duplicates from
  racing reconnects/failovers are structurally harmless.
- `journal_epoch` guards the identity of the sequence space: a rebuilt
  journal (corruption recovery) starts a new epoch; the client sees the
  epoch change, drops replay expectations, requests a snapshot, and records
  an `origin:"inferred"` `journal_gap` event so history is honest about the
  discontinuity.
- If the client's `since` has been retention-pruned, the agent answers the
  SSE preamble with a `replay_truncated {oldest_available}` event — same
  honest-gap handling. Bounded retention therefore never becomes unbounded
  disk (brief requirement) *and* never silently loses history.
- Heartbeats are journal events too (retained at low resolution: latest 24 h
  raw, then dropped — they're liveness, not history).

## 6. Data model (entities)

Field conventions everywhere: `schema` (int), `source`, `collected_at`,
`received_at` (client-local), `freshness_s`, `confidence`, `severity` where
applicable, `unit` on numerics, optional `error`.

| Entity | Key fields (beyond conventions) | Notes |
|---|---|---|
| **NodeIdentity** | node_id (UUID minted at install), hostname, hw_model, serial?, os_version/build | serial optional — privacy of exported bundles |
| **AgentIdentity** | agent_version, build_sha, spki_fingerprint, started_at | rides heartbeat |
| **ClientIdentity** | client_id, name, spki_fingerprint, scopes[], enrolled_at, expires_at, revoked_at? | agent-side registry; also self-describing on client |
| **ConnectionPath** | path_class, endpoint, state (7-state enum), rtt_ms stats, last_ok_at, last_error, pinned? | client-owned |
| **SystemSnapshot** | as_of_seq, sections keyed by collector id → latest samples | one GET |
| **MetricSample** | metric, value, unit, collector, error? | §4 shape |
| **ServiceHealth** | service_id, state ok/degraded/down/unknown, detail, check_kind (proc/socket/api/http) | services are config-defined |
| **CollectorHealth** | collector_id, state, last_run_at, duration_ms, consecutive_failures, last_error | the observer observed |
| **StateTransition** | subject, from, to, evidence, policy | §4 shape |
| **Alert** | alert_id, kind, phase raised/ack/resolved, severity info/warning/critical, subject, summary, evidence[], policy_rev | lifecycle via events |
| **AlertPolicy** | kind, thresholds, sustain_s, hysteresis, debounce_s, maintenance_windows[], severity map | config-owned, revisioned |
| **EventAck** | alert_id, actor, acked_at, note | user-origin |
| **DiagnosticEvidence** | attached to alerts/transitions: samples, probe results, log excerpts (redacted) | bounded size per alert |
| **SoftwareVersion** | component, version, observed_at | agent, client, macOS, tailscale, docker… |
| **Capability** | feature strings + action descriptors (empty v1) | negotiation |
| **BootSession** | boot_session_uuid, booted_at, clean_shutdown? (E5), ended_at? | uptime/restart truth |
| **ConfigRevision** | rev hash, applied_at, source (file), validation_result | `config_changed` events |

## 7. Facts, observations, inferences — kept distinct

| origin | Producer | Examples | Trust rule |
|---|---|---|---|
| `agent` | Mini, measured | CPU, disk, service states | authoritative about the Mini, only as fresh as `collected_at` |
| `client` | MBP, measured | path states, RTT, failover events, MBP-side egress checks | authoritative about *reachability from the MBP* |
| `inferred` | MBP situation engine | "mini_unreachable", "agent_down_host_up", staleness verdicts, journal_gap | always carries the evidence set that produced it; never rendered with the same visual authority as measured facts |
| `user` | human | acks, manual path pins, maintenance windows | attributable, timestamped |
| *(config)* | files | intent: thresholds, service definitions | not events; revisions journal as `config_changed` |

UI consequence (principle 8): the popover renders measured vs inferred
distinctly (e.g. "Mini reports: disk 13.9% free (5 s ago)" vs "Inferred:
unreachable via all paths since 14:02 — evidence: 3 paths failing").

## 8. Storage schemas

**Agent journal** (`journal.sqlite`, WAL, GRDB migrations):

```sql
CREATE TABLE events(
  seq INTEGER PRIMARY KEY AUTOINCREMENT,
  type TEXT NOT NULL, v INTEGER NOT NULL,
  boot_session TEXT NOT NULL, origin TEXT NOT NULL,
  collected_at TEXT NOT NULL,           -- RFC3339, UTC
  payload BLOB NOT NULL);               -- JSON
CREATE TABLE samples(                    -- raw, 48 h
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  metric TEXT NOT NULL, collected_at TEXT NOT NULL,
  value REAL, text_value TEXT, unit TEXT,
  collector TEXT NOT NULL, confidence TEXT NOT NULL, error TEXT);
CREATE INDEX samples_metric_time ON samples(metric, collected_at);
CREATE TABLE samples_5m(                 -- rollups, 30 d: min/max/avg/last
  metric TEXT, bucket_start TEXT, min REAL, max REAL, avg REAL, last REAL,
  n INTEGER, PRIMARY KEY(metric, bucket_start));
CREATE TABLE alerts(alert_id TEXT PRIMARY KEY, kind TEXT, severity TEXT,
  phase TEXT, raised_seq INTEGER, resolved_seq INTEGER, subject TEXT,
  summary TEXT, evidence BLOB);
CREATE TABLE clients(client_id TEXT PRIMARY KEY, name TEXT, spki TEXT,
  scopes TEXT, enrolled_at TEXT, expires_at TEXT, revoked_at TEXT);
CREATE TABLE meta(k TEXT PRIMARY KEY, v TEXT);
  -- journal_epoch, schema_version, node_id, config_rev, retention marks
```

Retention job (journal actor, hourly): delete samples > 48 h after rolling
into `samples_5m`; delete rollups > 30 d; delete events > 30 d or beyond
500 MB total (oldest first), writing a `retention_pruned {through_seq}` meta
mark so `replay_truncated` answers are exact. `PRAGMA quick_check` at open;
failure → rename file `journal.corrupt-<ts>.sqlite`, new DB, new epoch,
`journal_error` alert. **If the DB is entirely unavailable** (disk full,
I/O errors): agent keeps serving live snapshots from memory, marks
`journal: unavailable` in heartbeats, and drops history — observation
degrades, never stops.

**Client cache** (`cache.sqlite`): `events_mirror` (same columns + received_at,
`INSERT OR IGNORE` by seq, 7-day retention), `snapshot_latest` (one row per
node), `probe_history` (14 d), `client_events` (client/user/inferred origin,
same envelope), `acks_pending` (outbox — acks queue while offline, POST on
reconnect, idempotent server-side). Cache unavailable ⇒ app runs
memory-only (fully functional while connected, no history when offline) and
says so in diagnostics.

## 9. Time

All timestamps RFC3339 UTC. The agent samples SNTP offset (`time.apple.com`)
hourly; heartbeats carry agent-clock + offset estimate; the client computes
its own agent-clock delta (NTP-style over `/v1/ping` RTT) and uses it when
judging freshness, so a drifting clock skews *labels* not *logic* — and
sustained |offset| > 2 s raises `clock_drift`. Monotonic ordering never
depends on wall clocks (that's what `seq` is for).
