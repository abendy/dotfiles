# Connectivity and recovery

Date: 2026-08-01. Connectivity is a first-class subsystem, not a socket. The
governing idea: **one Mini identity, many endpoints, one trust model.** The
client authenticates the agent's key, never an address, so every path below is
interchangeable at the security layer and merely different at the routing
layer. Live-state receipts: [../spikes/README.md](../spikes/README.md).

## Current reality (verified 2026-08-01)

The Mini reaches the world through **Wi-Fi only** (`en1`, 192.168.1.196/24,
gateway 192.168.1.1). Built-in Ethernet `en0` is unplugged (cable-run
blocked, an existing TODO). Thunderbolt ports en2–en4 are free. Tailscale
(standalone GUI variant 1.98.10) provides 100.87.216.112 /
`nigiri-san.taila71bd7.ts.net`; the MBP peers *direct* on the LAN. Auto-login
is on, and the GUI-variant Tailscale runs only inside that session (L5, L6).
That stack of dependencies — Wi-Fi → router → user session → system
extension — is exactly what this design de-layers.

## Path A — Tailscale (primary remote path)

Normal operation for a roaming MBP: MagicDNS name → direct WireGuard when
NAT allows (currently does, LAN-direct), DERP relay otherwise.

- **Endpoint entries:** `nigiri-san.taila71bd7.ts.net:4747` *and* the raw
  `100.87.216.112:4747`. The raw-IP entry is deliberate: Tailscale IPs are
  stable per node, so agent reachability survives MagicDNS failure (MagicDNS
  inserts 100.100.100.100 as resolver — L4 — and DNS is a named failure mode,
  not an assumption).
- **Coordination outage:** established WireGuard sessions generally keep
  working (keys are cached); new connections and key renewals stall. Client
  behavior: existing path keeps its `available` state on live probes; the
  *client-side* `tailscale status --json` (also available on the MBP) is an
  auxiliary signal distinguishing "coordination unreachable" from "peer
  gone."
- **Mini's Tailscale unhealthy:** the agent's Tailscale collector reports
  `BackendState`, `Health[]` warnings, and self-peer info from the bundled
  CLI (`--json`, the supported surface — L5). Client cross-checks: if Path A
  probes fail but Path B/LAN succeeds and the agent reports Tailscale
  unhealthy, the situation engine names Tailscale, not the Mini.
- **ACL/grants posture:** today the tailnet runs default-open among the
  user's three devices. Recommended (Phase 2, needs user action in the admin
  console): grants restricting `tcp:4747` to the MBP's node identity, SSH 22
  to MBP + iPhone, and everything else deny — plus enabling
  [Tailnet lock](https://tailscale.com/kb/1226/tailnet-lock) is worth
  evaluating to remove the coordination server from the node-key trust path
  (open question Q9; not assumption-verified, needs a docs pass at
  implementation time).
- **Logout gap (structural, today):** GUI-variant Tailscale dies with the
  user session. With auto-login on, in practice it's up whenever the Mini is
  booted and unlocked — but "user logged out" maps to "Path A gone" until/
  unless the Mini migrates to open-source `tailscaled` (headless-recommended
  per Tailscale KB — L5). That migration is a recorded option, not assumed
  (parent-repo conventions prefer the cask; revisit in ADR 0007).

## Path B — Direct management link (Thunderbolt Bridge)

A cable from the MBP to a Mini Thunderbolt port, with **static addressing on
a dedicated management subnet**:

- Mini `bridge0`: 10.99.0.1/30 · MBP Thunderbolt Bridge service: 10.99.0.2/30.
- **No DHCP, no DNS, no router, no Tailscale** in the path. The client's
  endpoint entry is the literal `10.99.0.1:4747`; name resolution is never
  consulted. No gateway is configured on either side, so the link can never
  become a default route or leak internet traffic (macOS routes only the /30
  on-link prefix).
- Same mTLS as every path — a wire does not confer trust (a stolen/evil
  device on the cable still has to present the paired client cert; see threat
  M7).
- **Cable-attachment boundary, stated plainly:** Path B exists only while the
  MBP is physically plugged into the Mini. It is a *recovery and maintenance*
  path — "walk over with the laptop and a TB4 cable" — plus a high-bandwidth
  convenience when working adjacent. The plan assumes the cable is **not**
  normally connected; every runbook step that uses Path B begins "attach the
  cable." If the machines turn out to live desk-adjacent (open question Q5),
  leave it permanently cabled and Path B silently becomes the fastest
  everyday path — the design works either way.
- Alternative considered: two USB-C/Thunderbolt **Ethernet adapters + cable**.
  Kept as fallback if TB-bridge proves flaky (E3 validates) or if the TB
  ports are needed for storage; it costs hardware but behaves identically at
  L3. Running *both* TB bridge and Ethernet adapters adds nothing — one
  physically-independent link is the requirement.
- **Bonjour is a convenience only.** The client may listen for
  `_nigirid._tcp` advertisements to *hint* endpoint discovery (e.g., the
  Mini's current DHCP address after a lease change), but no path depends on
  it: Path B is static-addressed, Path A is Tailscale-addressed, and the LAN
  entry keeps a last-known-good address. mDNS being multicast-filtered or
  disabled must cost nothing but convenience.

Also in the catalog, between A and B: the plain **LAN path**
(`192.168.1.196:4747` — DHCP-reservation recommended, open question Q4, or
the wired `en0` address once the cable run lands). It shares fate with the
home router but not with Tailscale, and it's how the client distinguishes
"Tailscale broke" from "LAN broke."

## Path C — Independent remote WAN (Phase 4, designed now)

Purpose: reach the Mini when the home ISP or router is dead, or confirm
*which* of them is dead from afar. Tailscale DERP is **not** this — DERP
relays around NAT, not around a dead uplink; if the Mini's only uplink is
down, no relay reaches it.

Recommended design (ADR 0009):

- A small **LTE/5G router** (GL.iNet Spitz-class or Peplink; needs its own
  evaluation at purchase time) on the network shelf, on the UPS, with a
  data-capped SIM.
- The Mini attaches to it via a **separate interface** — a USB-C Ethernet
  adapter (en0 stays on the primary LAN once wired). The LTE router runs its
  own DHCP on an isolated subnet (e.g. 192.168.207.0/24) and **advertises no
  competing default route weight**: on macOS the primary service order keeps
  en0/en1 preferred; the LTE interface carries traffic only when Tailscale
  binds it or the primary default route is gone. Failover must never
  destabilize the primary network — no shared L2 with the main LAN, no NAT
  double-hop surprises for the household.
- **Tailscale rides both uplinks.** tailscaled/the app binds all interfaces;
  when the home ISP dies, the coordination server + DERP become reachable
  via LTE, and the MBP (wherever it is) reaches the Mini over Path A *through*
  Path C. This composition — Tailscale for identity/encryption, LTE for
  transport independence — avoids inventing a second remote-access system.
- **Always-connected** (recommended) vs activate-on-failure: an idle
  Tailscale keepalive over LTE is a few MB/day; a fallback that has to be
  activated by the thing that just failed is not a fallback. Data-usage
  alerting comes from the LTE router's own metrics (most expose them) plus a
  witness-style canary; hard cap on the SIM as backstop.
- Security: the LTE subnet is untrusted like any WAN; nothing listens on it
  except Tailscale and (deliberately) SSH+4747 with their own auth. UPS
  coverage for modem/router/LTE gear is part of the power plan below.

## Path D — External witness (Phase 4, interface reserved now)

A dead-man switch, not a channel: the agent POSTs a heartbeat
(seq, boot-session hash, agent version — nothing sensitive) every 60 s to a
hosted check (healthchecks.io-class, or self-hosted later; open question Q8).
The MBP reads the check's status via a read-only API key.

What it disambiguates (the one thing no internal path can): **"the Mini
stopped reporting" vs "I can't reach anything."** If the witness saw the Mini
recently but the MBP can't reach it → MBP-side or inter-network problem. If
the witness also lost it → the Mini or its home connectivity is actually
down, and the "alert occurred while MBP was offline" case is covered because
the witness's history persists. Boot-session changes appearing in the
heartbeat also tell the client "the Mini restarted while you were away."

Non-negotiables: outbound-only from the agent, no inbound control semantics,
no secrets in payloads, and client trust in witness data is *advisory* (it
feeds the situation engine as one more evidence source, never as a command).
Not in v1: it's the right Phase 4 item once local truth-telling works — but
the `WitnessReporter` null implementation ships in v1 so adding it is config,
not surgery.

## Connection manager (client subsystem)

**Catalog.** Per node: ordered endpoint entries
`{path_class: direct|lan|tailscale|tailscale_ip|wan2, address, port,
priority, static: bool}` — from `client.toml`, editable in Settings, hints
from Bonjour allowed. All entries resolve to the *same* pinned agent
identity; an endpoint answering with the wrong key is `auth_failed`, full
stop.

**Probing.** `GET /v1/ping` (tiny, authenticated, returns node_id + seq +
boot_session + time) — active path every 10 s; standby paths every 60 s with
jitter; every probe records RTT + outcome to the diagnostics store. Probes
are safe by construction (read-only, rate-limited server-side). TCP-connect
success with protocol failure is distinguished from no-connect — that's what
separates `agent_unavailable` from `unreachable`.

**Path states.** `available` · `degraded` (probes succeed but RTT > 4× the
path's baseline or ≥25% recent loss) · `unreachable` · `auth_failed`
(reachable, TLS/pinning/cert rejected — a security event, alerts
immediately, never silently retried onto another path) · `agent_unavailable`
(TCP accepts, protocol layer fails — port squatting or half-dead agent) ·
`stale` (last good probe > 3× interval) · `unknown` (not yet probed).

**Selection.** Prefer highest-priority `available` path; default priority
direct > lan > tailscale(name) > tailscale(ip). Hysteresis against flapping:
switch to a *better* path only after it wins 3 consecutive probes **and** the
current path has held < `min_dwell` (60 s) violations; switch *away*
immediately on hard failure (2 consecutive probe failures or one
`auth_failed`). Every change writes a `path_changed` client-observation event
(old, new, reason, evidence).

**No duplicate events on failover.** Event identity is the journal `seq`;
the SSE subscription resumes with `Last-Event-ID` on the new path, so replay
is idempotent by design (protocol doc §replay). Snapshot re-fetch after
failover reconciles freshness.

**Manual control.** Diagnostics view offers "pin to path" (with a visible
badge and auto-expiry after 1 h) for debugging — e.g., force-DERP to test
relay behavior, or force-direct-link during a maintenance visit.

**Reachability ≠ health.** The manager reports transport truth; the
**situation engine** combines it with agent-reported facts, heartbeat
absence, MBP-side probes (internet-egress check, MBP's own `tailscale
status`), and (later) witness data to emit exactly one top-level situation:
`healthy | degraded(reason) | agent_down_host_up | mini_unreachable |
network_partition(layer) | stale(age) | unknown` — the user-facing statement
of principle 3, rendered without raw logs.

## Recovery-boundary taxonomy

What an in-OS agent can and cannot fix, stated as layers. The failure-mode
matrix maps every scenario to one of these:

| Layer | Examples | Who recovers | Agent's role |
| --- | --- | --- | --- |
| R1 Application | nigirid crash, collector wedge, journal corruption | launchd + agent self-healing | detect, restart, evidence |
| R2 User session | logout kills GUI-variant Tailscale/colima agents | auto-login at boot; user via SSH (`launchctl kickstart`, login) | detect + name the layer |
| R3 Operating system | OS hang, kernel panic, reboot loop | watchdog reboot / autorestart; user via SSH if half-up | evidence after the fact (boot session, panic reports) |
| R4 Preboot / FileVault | FileVault-locked disk after restart | **user, via preboot SSH unlock (macOS 26) or physical presence** | none while locked — by design nothing of ours runs |
| R5 Network equipment | router, modem, switch, LTE box | power-cycle (human or smart-PDU later), ISP | client-side discrimination; Path C rides around it |
| R6 Power | outage, UPS exhaustion | UPS bridges; autorestart after restore | UPS telemetry, clean-shutdown evidence, boot-session change |
| R7 Firmware/hardware | SSD death, PSU failure, TB port damage | Apple service / spare hardware | last evidence retained on client + witness |

The honest boundary: R4 and R7, and full R3 (true hang), require either
physical presence or preboot facilities. The design's job there is *fast,
confident diagnosis and a rehearsed runbook*, not magic remote hands.

## FileVault + SSH on macOS 26 (researched 2026-08-01)

Primary source, verified on the Mini itself: `apple_ssh_and_filevault(7)`
(shipped in 26.5.2): with Remote Login on, **password auth over SSH works
while the data volume is locked and unlocks FileVault**; sshd drops the
session while the data volume mounts, then normal service resumes. New in
macOS 26 Tahoe. Additionally `fdesetup supportsauthrestart` returns **true**
on this M4 (L2), enabling `sudo fdesetup authrestart` for *planned* reboots
(key cached in memory/SMC for one boot — documented FileVault-weakening
tradeoff, acceptable for maintenance windows, `pmset destroyfvkeyonstandby`
noted).

Prerequisites and limits for the runbook:

1. Remote Login enabled (it is — osx-devbox).
2. **Preboot networking**: secondary sources report wired Ethernet or
   previously-joined open/WPA2-PSK Wi-Fi. The Mini is Wi-Fi-only today —
   **experiment E1 must prove preboot reachability before FileVault is
   enabled**; the wired-Ethernet TODO materially strengthens this path.
3. Password auth at preboot is inherent (keys live on the locked volume).
   Threat implication: at preboot, the account password alone unlocks the
   disk from the network — so the password must be strong, and secondary
   sources suggest a dedicated unlock-only user (`fdesetup add -usertoadd`)
   so the unlock credential isn't the daily admin password. LAN/tailnet
   exposure of preboot sshd needs the E1 drill to characterize (does it
   listen on Wi-Fi? which interfaces?).
4. Tailscale is **not available at preboot** (any variant — data volume
   locked): preboot SSH is LAN/direct-link only, or via Path C's router
   port-forward if deliberately configured (default: no).

**Recommendation** (feeds the parent repo's pending FileVault decision):
enable FileVault *after* (a) wired Ethernet or validated Wi-Fi preboot per
E1, (b) a rehearsed unlock drill documented in the runbook, (c) the
autorestart drift is fixed. Until then, FileVault stays off — the current,
deliberate availability-first posture. This is user decision Q3.

## Power and physical resilience

Current state (L2): **no UPS**, `womp 1`, `autorestart 0` (drift — fix
in flight as a spawned task), auto-login on.

Plan:

- **UPS for the Mini** with a USB data port (CyberPower/APC class; purchase =
  open question Q7). macOS natively manages UPS shutdown thresholds
  (Energy settings appear once a UPS is attached); the agent's UPS collector
  reads `IOPSCopyPowerSourcesInfo` (supported IOKit surface) for
  on-battery / runtime-remaining / charge, feeding `ups_on_battery` and
  `ups_runtime_low` alerts. Controlled shutdown remains the OS's job
  (configured thresholds), the agent *observes and journals* it
  (`power_event {source: ups}`), so post-incident evidence exists.
- **Network shelf on UPS outlets**: modem, router, switch, and future LTE
  router on battery-backed outlets — otherwise the Mini outlives its own
  reachability and every remote path dies while the host is healthy. UPS
  sizing should target ~15 min for the Mini and longer for the (lower-draw)
  network gear.
- **Boot forensics**: boot-session UUID + uptime + (E5) shutdown-cause query
  + DiagnosticReports scan give the `unexpected_restart` alert and the
  "last clean shutdown" fact where obtainable.
- **Wake**: `womp` stays on; sleep is disabled by policy anyway (osx-devbox).
- **Future managed power path**: a network PDU or UPS with switchable
  outlets (APC NMC-class), explicitly **not a consumer smart plug** (no
  auth, no audit, cloud-dependent, and a Wi-Fi plug dies with the Wi-Fi it
  would be needed to fix). If/when remote power-cycling is built:
  last-resort classification; `actions:power` scope + fresh local
  confirmation on the client; typed confirmation naming the node; 10-minute
  cooldown; refusal while UPS reports on-battery; audit event to journal
  *and* witness before the cut; filesystem-damage warning in the flow;
  `autorestart` verified on as a precondition. Design only — far beyond v1.

## Recovery runbooks (deliverable shape)

Each scenario class in the failure-mode matrix gets a runbook entry with:
trigger signature (what the client will actually display), fastest remote
step, fallback steps in order (Path B visit → physical), and the evidence to
capture. Phase 3 turns the matrix rows into `docs/runbooks/` files; the drill
requirement (test twice a year, after OS majors) lives in the testing
strategy.
