# Product brief — Nigiri Control Plane

Date: 2026-08-01. Status: proposed. Companion evidence:
[../spikes/README.md](../spikes/README.md).

## The problem

`nigiri-san` is a headless Mac mini devbox that the user reaches from a
MacBook Pro (and occasionally iOS) over Tailscale + mosh + tmux. Today the
only way to know the Mini's state is to connect to it — which is exactly the
thing that fails when something is wrong. Recent history in this repo shows
the pattern: mosh PATH breakage, Codex app-server 409s, a `pmset autorestart`
setting that silently reverted, a container-runtime decision in limbo, and a
FileVault decision deferred "before the first remote-only reboot" — which has
not happened yet and will eventually happen unplanned.

The failure that matters most is not "CPU is high." It is: *the Mini stopped
answering and I cannot tell whether the box is dead, asleep, rebooted into a
locked disk, off the network, or fine-but-Tailscale-broke — and I'm not at
home.*

## What this is

A two-part personal-infrastructure system, built as durable software rather
than shell scripts behind a menu:

1. **`nigirid`** — a resident agent on the Mini: collects structured
   telemetry, evaluates health, journals events durably, serves state and
   history to authenticated clients over every viable network path, and
   monitors itself.
2. **Nigiri Control** — a native menu-bar app on the MBP: one glyph that
   answers "is the Mini okay," a popover that answers "what exactly is its
   state and how do I know," local notifications for alerts, and a
   diagnostics view that answers "which path am I on and what failed."

The defining capability is **failure discrimination**, not dashboards. The
client must distinguish: Mini down · agent down while host up · Tailscale
down · LAN down · internet down · MBP-side problem · data merely stale — and
say which one it believes, with what confidence, from which evidence.

## Who it serves

One user, two machines, occasionally an iPhone. This is personal
infrastructure: no multi-tenant concerns, but *higher* durability standards
than a toy — it must keep working across OS updates, network redesigns, and
years of low-touch operation, and it must never make the Mini less secure
than it is today.

## v1 (read-only) in one paragraph

Pair once over SSH. The menu bar shows Healthy / Warning / Critical /
Offline / Stale. The popover shows identity, active connection path, last
heartbeat, freshness, highest active alert, CPU/memory/disk/thermal compact
state, service health (SSH, Screen Sharing, Tailscale, Docker-via-colima,
tmux, configured launchd jobs, HTTP/TCP checks), and recent transitions.
Alerts (unreachable, disk, memory, thermal, unexpected restart, container
unhealthy, stale telemetry, collector failing, and friends) debounce properly,
notify locally, and can be acknowledged. A diagnostics window exposes the
endpoint catalog, per-path probe results, auth state, clock offset, collector
health, and an export bundle with secrets redacted. Event history survives
disconnection on both ends and replays without duplication.

**No remote command execution of any kind ships in v1.** There is no shell
endpoint, no action verbs, no approval relay. Those arrive later behind
separate authorization (see security model); the protocol reserves room so
adding them is additive, not a rewrite.

## Non-goals for v1

- Controlling anything on the Mini (including "convenience" restarts).
- Monitoring the MBP itself (reversed roles are a later-phase provision).
- Cloud dashboards, historical analytics, Grafana-style graphing.
- Replacing SSH/mosh/tmux — this observes; those remain the hands.
- An iOS app (iOS gets alert delivery via the Phase 4 witness's existing
  mobile apps first).

## Success criteria

1. During a real incident (router dead, Tailscale coordination outage, Mini
   power loss), the menu bar tells the truth within 60 s and names the
   failing layer correctly.
2. A month of unattended operation produces zero false "Critical" alerts and
   bounded disk usage on both machines.
3. Losing any one of {Tailscale, home LAN, DNS, MagicDNS, the agent} degrades
   the display but never blanks it; recovery is automatic and unduplicated.
4. A compromised MBP cannot use this system to run code on the Mini (v1 has
   no such endpoint), and a stolen MBP's credential is revocable in under
   five minutes from any SSH session to the Mini.
5. The Mini's privilege posture is unchanged: no new root helpers, no FDA,
   no Accessibility, no TCC prompts on the agent.

## Constraints inherited from the repo

- Doc contract: machine-state changes and their docs land together
  (CLAUDE.md). This plan's later phases will append to `mac-mini-setup.md`
  when they actually touch the machine.
- Decisions/defects become GitHub issues on `abendy/dotfiles`.
- Prefer brew/cask-manageable, SSH-upgradable software on the Mini.
- Swift subproject precedent: disk-prune (SwiftPM, launchd templates,
  install.sh, `~/.config/<tool>/` config).
- Two-clone deployment model (ADR 0001 of the parent repo) — install flows
  must respect the working-repo vs deploy-clone split.
