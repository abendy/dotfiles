# Security threat model

Date: 2026-08-01. Scope: the v1 read-only system plus the boundaries reserved
for future actions. Governing rules: **fail closed for control, degrade
gracefully for observation**; authentication binds to **device keys, not
addresses**; and the Mini must end up **no less secure than before this
project existed**.

## Assets

A1 the Mini itself (code execution on it) · A2 SSH trust (authorized_keys —
the existing crown jewels) · A3 telemetry (moderately sensitive: usernames,
hostnames, network topology, container names, session names) · A4 client/agent
private keys · A5 journal integrity (evidence trustworthiness) · A6 update
channel (whoever controls it controls A1 eventually) · A7 availability of the
monitoring itself.

## Trust and authorization tiers

| Tier | Contents | Requirement |
| --- | --- | --- |
| T0 unauthenticated | TCP accept + TLS handshake only. No application data — there is deliberately **no anonymous health endpoint**; "is the port up" is all an unauthenticated observer learns. | none |
| T1 telemetry read | snapshot, events, heartbeats, acks | valid client cert with `telemetry:read` |
| T2 diagnostics read | agent logs (redacted), probe internals, diagnostic bundle | cert with `diagnostics:read` (v1 issues T1+T2 together to the MBP; separable later, e.g. an iOS credential gets T1 only) |
| T3 future controlled actions | allowlisted verbs (service restart etc.) | `actions:<verb>` scope **plus** fresh local user confirmation on the client, per invocation |
| T4 future privileged recovery | power operations, agent rollback via protocol | `actions:power` etc. + confirmation + cooldown + audit; last-resort classification |

v1 ships T0–T2 only. **No arbitrary shell endpoint exists at any tier, in any
phase** — future actions are typed verbs with per-verb policy, never
`exec(string)`.

## Authentication design (ADR 0005 summary)

- **Mutual TLS 1.3** on every network transport; P-256 keys both sides
  (Secure-Enclave-backed where E6 proves viable; software-Keychain/0600-file
  fallback). Self-signed certs, **mutual SPKI pinning** — no CA, because a CA
  is machinery for open-ended trust and this system has exactly two parties.
  An endpoint presenting an unpinned key is `auth_failed`; there is no
  "accept once" UI.
- **Pairing ceremony** (the only trust-establishment path): run
  `nigirictl pair` on the MBP; it generates the client key, connects **over
  existing SSH** (already-trusted channel) to invoke `nigirid enroll`; both
  ends display the same 6-word fingerprint phrase (hash of both SPKIs); the
  user confirms visually on both terminals; the agent stores the client
  record `{name, spki, scopes, expiry}` and returns its own SPKI for pinning.
  Compromise of pairing therefore requires prior compromise of SSH (A2) —
  no new bootstrap trust is invented.
- **Rotation**: certs expire at 24 months; both sides surface expiry ≥30 days
  out (self-metric + alert). Rotation = re-pair with overlap (agent holds old
  + new client SPKIs during a grace window; `nigirictl clients list` shows
  both).
- **Revocation**: `nigirid clients revoke <name>` over SSH (or locally);
  takes effect on next handshake (connections are short-lived or re-verified
  on reconnect; SSE streams get dropped on revocation). Stolen-MBP runbook:
  revoke from any SSH session — iPhone included — in minutes.
- **Lost credentials / recovery**: client key lost → re-pair (SSH). Agent key
  lost/rebuilt → clients see `auth_failed` (pinning working as intended);
  recovery is deliberately manual re-pairing, never auto-trust-on-change.
- **Tailscale identity is defense-in-depth only**: tailnet ACLs/grants should
  narrow who can even reach :4747 (Phase 2 hardening), and WireGuard
  encrypts the path — but possession of a tailnet IP is *never* sufficient:
  the application credential is always required. Rationale: principle 5 — a
  compromised tailnet member or coordination account must not gain telemetry
  or (later) actions.

## Threat catalog

| # | Threat | Primary mitigations | Residual risk |
|---|---|---|---|
| T1 | **Compromised MBP** | v1: no action endpoints exist — attacker gets telemetry read (A3), not code exec on Mini (A1). Client key is scoped T1/T2. Revoke from Mini via SSH. Future T3/T4 add per-action local confirmation so a silent MBP process can't invoke them invisibly. | Attacker reads telemetry until revoked; sees topology. Accepted for v1; witness/iOS alert on anomalous access is a later hardening. |
| T2 | **Compromised Mini user account** | Game over for telemetry honesty (agent runs as that uid) — *scope the blast*: agent holds no secrets beyond its own key; no MBP-controlling material exists on the Mini; SSH keys already govern the Mini (pre-existing surface, unchanged). | Fundamental: uid-501 compromise ≈ Mini compromise today too. The project must not *add* escalation paths (no root helper in v1 — see privilege budget). |
| T3 | **Stolen MBP** | FileVault on MBP (assumed), Keychain/SE for client key, revocation runbook, cert expiry backstop. | Window between theft and revocation → telemetry read only. |
| T4 | **Malicious tailnet member** (third device, e.g. compromised iPhone) | mTLS: no client cert ⇒ T0 only. Grants narrowing :4747 to the MBP node. SSH stays key-auth. | Preboot-SSH (if FV enabled) accepts *passwords* on reachable interfaces — E1 must characterize exposure; strong password + dedicated unlock user mitigate. |
| T5 | **Local-LAN attacker** | Same as T4 — LAN confers reachability, never trust. mDNS advertisement (optional) leaks presence only; can be disabled. | Service fingerprinting/DoS visibility; see T15. |
| T6 | **Replay of old telemetry** | TLS 1.3 channel (anti-replay inherent); events carry seq + boot-session; snapshots carry collected_at that the client checks against its own clock ± estimated offset; stale ⇒ shown as stale, never as fresh. | Clock lies within drift tolerance shade freshness only. |
| T6b | **Replay of commands (future)** | Reserved design: action requests carry client nonce + timestamp; agent enforces single-use + freshness window + per-verb cooldown. | n/a in v1. |
| T7 | **MITM on the direct link** (evil device on the cable/port) | Identical mTLS + pinning on Path B — the wire is untrusted like any network. No auth-downgrade on any path. | None beyond endpoint compromise itself. |
| T8 | **Malicious/compromised collector** | v1: compiled-in only, no dynamic loading; CollectorContext restricts process table to allowlisted absolute paths + declared file prefixes; dep pins. Honest statement: in-process code is trusted-by-review, not sandboxed — the *organizational* control is the tiny dependency budget and this repo's review flow. | A malicious commit ships malicious agent — see T11/T12. Process-isolated collectors are the recorded evolution if third-party code ever enters. |
| T9 | **Agent privilege escalation** | Agent is uid 501 with **no** sudoers entry, no SMJobBless helper, no setuid bits, no entitlement-granted powers. There is nothing to escalate *to* within the design; adding privilege later requires a new ADR + explicit helper with its own audit. | OS-level LPEs are out of scope (patch cadence is the control — and is itself monitored). |
| T10 | **Secret leakage via logs/telemetry** | Redaction layer at journal-write and bundle-export: deny-pattern scrub (key material markers, `Authorization:`, tokens), env vars never collected, shell history never read, file *contents* never collected (metadata only), diagnostic bundle assembled from an allowlist not a directory walk. Contract test: seeded canary secrets must not survive export. | Novel secret shapes; mitigated by allowlist-not-blocklist bundle design. |
| T11 | **Supply-chain compromise** (deps) | Dependency budget of ~4 pinned packages (`Package.resolved` committed); build-from-source on the Mini from this repo (ADR 0010) — no third-party binary distribution channel exists for the agent; brew deps only for toolchain. | Upstream source compromise of GRDB/NIO-class packages; monitored ecosystem, pinning gives review window. |
| T12 | **Malicious downgrade / forged update** | Agent updates = git pull of this repo (SSH-signed commits per parent-repo convention, verifiable via `git-allowed-signers`) + local build; no auto-update in v1. Client app: Sparkle-with-EdDSA or same build-from-repo (Q2/ADR 0010); rollback keeps N−1 binary locally (signed at build time). Version-skew guarded by capability negotiation, and a downgraded agent can't silently masquerade: version rides every heartbeat and the client alerts on unexpected regression. | Attacker with push access to the repo = A2-level compromise already. |
| T13 | **Event-database tampering** (Mini-side) | Journal is uid-501-owned like everything else — same-uid attacker can rewrite history (consistent with T2 blast radius). Client keeps its **own** 7-day mirror (independent copy, receipt-timestamped), which is the tamper-evidence baseline; witness adds an off-box seq/boot trail in Phase 4. Optional future: HMAC hash-chaining of events (cheap, noted, not v1). | Sophisticated same-uid tampering before client mirrored — accepted; this is personal infra, not a forensic appliance. |
| T14 | **DoS against the agent** | Pre-auth cost bounded: connection cap (8), per-IP handshake rate limit (4/min), 1 MiB body cap, header/read timeouts, no unauthenticated work beyond handshake. Collector layer immune (server and collectors are separate actors; observation continues under connection flood). Alert on sustained auth-failure/connection-flood rates. | LAN/tailnet flooding degrades API availability, never host telemetry collection; a flooded agent still journals for later replay. |
| T15 | **Reconnaissance** (port 4747 visible) | TLS with no banner beyond cert (self-signed, CN uninformative); tailnet grants narrow reachability; acceptable residual: an on-LAN scanner learns "a TLS service exists." | Accepted. |

## Privilege budget (design principle 10, enforced as a table)

Everything the system needs, and — pointedly — everything it does **not**:

| Component | Runs as | Root? | FDA? | Accessibility? | Automation/AppleEvents? | TCC prompts | Entitlements | Network |
|---|---|---|---|---|---|---|---|---|
| nigirid | `nigiri` (LaunchDaemon UserName) | **No** | **No** (DiagnosticReports readable unprivileged — verified L9) | **No** | **No** | **None** | none beyond default codesigning | listens :4747 + UDS; outbound: NTP, reachability probes, (P4) witness |
| nigirictl | invoking user | No (except `install`/`enroll` writing /Library/LaunchDaemons — explicit sudo, install-time only) | No | No | No | None | none | UDS only |
| Nigiri Control.app | console user (MBP) | No | No | No | No | **UserNotifications only** | Hardened Runtime; (if sandboxed: client network + Keychain groups — sandbox feasibility is a Phase 1 check, non-sandboxed Developer ID acceptable) | outbound to agent endpoints only |
| Collectors (each) | in-process | — | — | — | — | — | see per-collector privilege column in [initial-feature-set.md](initial-feature-set.md) — every collector must justify its access or be rejected | — |

Rejected on privilege grounds (value ∄ burden): screen-contents observation
(Screen Recording TCC), app-UI scraping (Accessibility), Messages/calendar
anything (FDA), keystroke/idle precision beyond public session state,
`softwareupdate` daemon manipulation. The pending-restart indicator is
**deferred** rather than implemented badly: no supported query exists;
revisit if Apple documents one.

## Redaction specification (bundle + logs)

Diagnostic bundle contents are **allowlisted**: config (with a `redact`
transform: witness URLs → host only, any `*_key`/`*_token` field refused at
schema level anyway), self-metrics, collector health, probe history, alert
history, agent log tail post-scrub, journal statistics (not raw samples
unless explicitly included), version/build info. Never included: private
keys, Keychain anything, authorized_keys, shell history, env dumps, arbitrary
file contents, Codex session contents. The export UI shows the exact file
list before writing the archive.

## Standing security invariants (testable)

1. No process of this system ever runs as root after install time.
2. No TCC permission dialogs beyond the client's notification prompt.
3. Every network byte is inside mutually-pinned TLS 1.3 (SSH excepted — it
   has its own trust).
4. A fresh client cannot obtain data without an SSH-anchored pairing
   ceremony.
5. `auth_failed` is never auto-healed, rerouted around, or displayed as a
   connectivity problem.
6. The agent binary contains no code path that executes a caller-supplied
   string as a command. (Enforced by review + a grep-able assertion:
   the process-runner accepts `CommandID` enum values, not strings.)
7. Update/rollback never has a state with zero working access: SSH remains
   functional independent of agent state, and N−1 binary is kept until the
   new version passes self-check.
