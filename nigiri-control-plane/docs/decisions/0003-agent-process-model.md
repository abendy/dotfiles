# ADR 0003 — Agent process model: classic LaunchDaemon as user `nigiri`

- **Status:** proposed (accept after E2)
- **Date:** 2026-08-01

## Context

The agent must start at boot before login, survive logout, restart on
crash, and read uid-501 artifacts (colima's 0600 docker.sock — L7, tmux's
per-user socket, Codex files — L8) *without* privilege escalation. Current
machine reality: `/Library/LaunchDaemons` is empty; everything rides the
auto-logged-in GUI session (L6) — the agent should be the first thing on
this machine that doesn't.

## Decision drivers

Boot-time start independent of login; logout survival; zero root; zero TCC;
headless installability over SSH (no GUI approval ceremony); collector
access to user-owned interfaces; repo precedent of launchd templates +
install script.

## Considered alternatives

- **LaunchAgent (user)** — dies at logout, starts only at login; exactly the
  fragility being removed. Rejected for the core; remains the model for the
  *future session helper* (GUI-scoped collectors, none in v1).
- **SMAppService.daemon** — modern registration, but requires an app-bundle
  context and Login-Items approval UX designed for attended Macs; wrong
  ergonomics for SSH-only administration. Rejected for the Mini agent
  (used on the MBP for the client's login item instead).
- **Root LaunchDaemon + privilege-separated workers** — classical, but v1
  needs nothing root can do that uid 501 cannot (verified collector-by-
  collector in initial-feature-set), so root would be pure liability
  (principle 10).
- **Dedicated service user (`_ncp`)** — cleaner isolation on paper;
  in practice it re-introduces access machinery (groups/ACLs for docker
  sock, tmux, Codex paths) whose failure modes are worse than the isolation
  gain on a single-human machine. Revisit when actions/privileges arrive.

## Decision

One binary `nigirid`, installed at
`/Library/LaunchDaemons/com.abendy.nigiri-control-plane.agent.plist` with
`UserName nigiri`, `KeepAlive true`, `ProcessType Background`,
`AbandonProcessGroup false`; managed by `install.sh` over SSH with a single
sudo step. Future session-scoped collection arrives as a separate
LaunchAgent posting to the daemon's UDS ingest — the boundary exists in v1,
unused.

## Consequences

Strict availability upgrade over the status quo; daemon context means no
GUI APIs ever (enforced by review — collectors needing them belong in the
future helper); BTM shows a background-item entry (E2 characterizes the
headless notification experience); home-directory paths are valid because
the daemon runs as nigiri (data volume unlocked — FileVault interaction
noted in connectivity doc §R4).

## Security implications

Compromise of the agent ≈ compromise of uid 501 — the pre-existing blast
radius of every process on this box; no escalation vector added (no sudo,
no helper, no setuid). Plist and binaries root-owned (0644/0755) so uid 501
cannot silently swap what launchd runs — the write path goes through the
sudo-gated installer.

## Validation required

E2: pre-login start, logout survival, BTM behavior over SSH-only install,
KeepAlive backoff behavior under crashloop, `launchctl kickstart -k`
upgrade flow.

## Revisit conditions

Actions/privileged operations arrive (dedicated user + helper with its own
ADR); Apple restricts plist-based daemons in a future macOS (SMAppService
path becomes forced — the app-bundle packaging cost gets paid then).
