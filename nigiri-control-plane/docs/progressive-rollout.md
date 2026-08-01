# Progressive rollout

Date: 2026-08-01. The prompt's phase structure survives contact with the
evidence almost intact; revisions are noted where made and why. Every phase
has exit criteria — a phase isn't done because its code merged, it's done
when its claims have been demonstrated.

## Phase 0 — Architecture validation (no product code)

Run the experiments in [../spikes/README.md](../spikes/README.md):

- E2 classic LaunchDaemon on macOS 26 headless (BTM behavior, pre-login
  start, logout survival) — *gates ADR 0003*.
- E4 mTLS + SSE spike (Hummingbird + URLSession, pinning both ways, Last-
  Event-ID resume) — *gates ADR 0004/0005; also sizes the Hummingbird
  dependency decision with real code*.
- E3 Thunderbolt Bridge static link (needs a physical visit + TB4 cable) —
  *gates ADR 0008*.
- E6 Secure-Enclave key from daemon context — *decides key storage detail*.
- E1 FileVault preboot-SSH drill — **deliberately schedulable later** (it
  reboots the Mini and FileVault is currently off; it gates Q3, not v1
  implementation). Revised from the prompt's Phase 0: don't block the
  read-only release on it, do block the FileVault-enable decision on it.
- E5/E7/E8 (shutdown-cause cost, mystery interfaces, launchctl fixtures) —
  cheap, fold into early implementation.
- Decide Q1 (repo home) and Q2 (Developer ID) — they shape CI and signing
  from the first commit.
- Confirm the failure-mode matrix against one deliberate real fault (router
  off for 5 minutes, watching *current* tooling fail) to calibrate baseline.

**Exit:** ADRs 0001–0011 status flipped to accepted (or amended with
evidence); spike results recorded in the validation log.

## Phase 1 — Read-only local prototype

Agent skeleton (scheduler, journal, server, self-observer) + client skeleton
(menu bar states, popover, cache, notifications) + pairing over SSH + one
path (Tailscale MagicDNS endpoint — it's the always-works-today path) +
collectors: agent.self, system.{boot,cpu,memory,disk,thermal}, net.
{interfaces,egress,tailscale}, svc.{ssh,screenshare} + heartbeat/SSE/replay
end-to-end + `nigirictl` (status, pair, clients, config validate).

**Exit:** week-long unattended run: menu bar truthful through ≥1 organic
Mini reboot and ≥1 agent kill; replay produces zero duplicates/gaps
(journal-verified); update+rollback drill executed once on purpose; unit/
protocol/storage CI green; privilege audit confirms zero TCC prompts and no
root beyond install.

## Phase 2 — Resilient connectivity

Full endpoint catalog (LAN + raw-TS-IP + TB static) + connection manager
(probes, 7-state paths, hysteresis, failover, manual pin) + situation engine
v1 (the discrimination table from connectivity doc) + stale-vs-fresh
semantics everywhere in UI + diagnostics window + faultlab network profiles
+ VM lab stood up.

**Exit:** scripted partition drills produce the *named* situation for each
of: TS-dead/LAN-alive, LAN-dead/TS-alive, DNS-dead, all-dead, agent-dead/
SSH-alive — with no false "Mini down" and no flapping under 30% loss; TB
recovery walk-through documented and performed once for real.

## Phase 3 — Operational monitoring

Remaining collectors (session.*, launchd jobs, Docker/colima, tmux, HTTP/TCP
checks, restart-evidence, time.sync, power.source-if-UPS-purchased) + full
alert engine (policies, windows, acks, grouping) + event-history view +
diagnostic bundle export + UPS purchase/integration if Q7 approved +
runbooks written from matrix rows.

**Exit:** 30-day soak: zero false criticals, notification budget respected,
DB sizes within caps; one real disk-pressure event or simulated equivalent
handled end-to-end (raise → notify → ack → resolve); bundle export passes
redaction canary; runbook drill for agent-down and unexpected-restart.

## Phase 4 — Remote resilience

Secondary WAN per ADR 0009 (LTE router, isolated subnet, Tailscale binding,
data alerts) + witness (healthchecks.io-class, `WitnessReporter` real
implementation, client-side witness observer + "alert while away" delivery
via witness push apps) + offline alert delivery story documented + rollback
hardening (automated selfcheck gate) + FileVault decision execution if Q3
approved post-E1 (with preboot-unlock runbook + drill).

**Exit:** pull-the-WAN-plug drill: Mini reachable via Path C within 5 min,
witness timeline correct, MBP-away simulation (tethered) sees correct
remote picture; power-loss drill with UPS: clean shutdown journaled,
auto-restart verified, timeline reconstructed from evidence alone.

## Later phases (architectural provisions only — no implementation planning)

- **Codex lifecycle events**: hooks (SessionStart/End, PermissionRequest —
  verified interface L8) posting to the agent's UDS ingest; read-only
  session/state surfacing in the popover.
- **Codex approval handoff**: PermissionRequest hook → alert-class event →
  client approval UI → *typed response verb* under T3 scopes + local
  confirmation. Never generic remote input injection.
- **Capability-based actions**: `POST /v1/actions/{verb}` activation with
  per-verb policy, nonce/freshness, cooldowns, audit — service restarts
  first (colima, tailscale kickstart), each an ADR-able decision.
- **Remote service remediation / Screen Sharing & terminal launch**:
  client-side launchers (`vnc://`, ssh Terminal profiles) are cheap and
  local; agent-side remediation rides the actions framework.
- **iOS companion**: read-only first, reusing T1 with a scoped cert; push
  via witness provider until a dedicated relay earns its keep.
- **Multiple managed nodes / MBP workload exposure**: node_id already
  namespaces everything; the client grows a node switcher; an MBP-resident
  agent is just another node.
- **Local LLM job observation**: a session-helper collector reading
  documented queues/APIs of whatever runs jobs (defined when the workload
  exists — no speculative collector).
- **Managed power operations**: network PDU / switched-outlet UPS behind
  T4 with the full safeguard list from the connectivity doc.
