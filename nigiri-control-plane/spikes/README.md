# Validation log — spikes and verified assumptions

**Everything in this directory is experimental evidence, not production
architecture.** Production design lives in [`../docs/`](../docs/). Each entry
records what was checked, how, on what date, and what it decides or leaves
open. When a doc in `../docs/` asserts a platform fact, this file is where the
receipt lives.

Conventions: "live" means executed on `nigiri-san` (the actual Mac mini,
macOS 26.5.2 / build 25F84) during the planning session of **2026-08-01**.
"vendor" means read from primary vendor documentation on that date.

## L1 — Host identity and OS (live, 2026-08-01)

`sw_vers`, `sysctl hw.model machdep.cpu.brand_string hw.memsize`:
macOS 26.5.2 (25F84), `Mac16,10`, Apple M4, 24 GiB. `scutil` names converged
to `nigiri-san` (osx-devbox did its job). Swift toolchain 6.3.3 via Command
Line Tools only — **no full Xcode on the Mini** (`xcodebuild` errors). SwiftPM
builds work (disk-prune precedent). SQLite CLI 3.51.0.

→ Decides: agent must build with SwiftPM + CLT alone; anything needing
`xcodebuild` happens on the MBP.

## L2 — Boot, power, FileVault (live, 2026-08-01)

- `kern.bootsessionuuid` = `0FFC5AA7-…` and `kern.boottime` = Jul 31 14:22 —
  boot-session identity is one sysctl away, no privileges. Confirms the
  boot-session/uptime collector design.
- `pmset -g`: `sleep 0`, `disksleep 0`, `womp 1`, `displaysleep 10` — as
  osx-devbox intends. **`autorestart 0` — drift.** osx-devbox sets it to 1 and
  mac-mini-setup.md records it as done. Filed as a background-task chip during
  this session (fix + GH issue per repo conventions). Until fixed, a power
  failure leaves the Mini off.
- `pmset -g batt`: "AC Power", no battery/UPS enumerated — **no UPS attached
  today.** The UPS collector (IOKit power sources) stays inert until hardware
  exists.
- `pmset -g therm`: no thermal/CPU-power warnings recorded; command works
  unprivileged.
- `fdesetup status` → **FileVault is Off** (the pending decision in
  mac-mini-setup.md currently rests at off).
- `fdesetup supportsauthrestart` → **true** on this M4. `man fdesetup`
  documents the tradeoff: authrestart stashes an FDE unlock key in memory/SMC
  for one reboot.

## L3 — FileVault unlock over SSH (vendor via local man page, 2026-08-01)

`man apple_ssh_and_filevault` (page dated 1 July 2025, shipped in macOS
26.5.2): with Remote Login enabled, **password authentication over SSH works
while the data volume is still locked and unlocks FileVault**; SSH then
disconnects briefly while the data volume mounts and services start.
"The capability … appeared in macOS 26 Tahoe."

Secondary sources (Der Flounder 2025-10-11, Jeff Geerling 2025) add unverified
detail: preboot networking requires wired Ethernet or a previously-joined
open/WPA2-PSK Wi-Fi network, and suggest a dedicated unlock-only user via
`fdesetup add -usertoadd`.

→ Decides: FileVault-on is now *compatible* with a headless Mini in principle.
→ Open (experiment E1): the Mini is currently **Wi-Fi-only** (WPA2/3 home
network); whether its preboot environment gets a network at all is unproven.
Do not enable FileVault until E1 passes. Note the preboot sshd accepts
*password* auth by design — account password strength becomes a remote-attack
surface at preboot.

## L4 — Network interfaces (live, 2026-08-01)

`networksetup -listallhardwareports` / `ifconfig`:

- `en0` built-in Ethernet — **no cable, no IP** (matches the mac-mini-setup
  TODO; gear placement blocks a cable run today).
- `en1` Wi-Fi — 192.168.1.196/24, gateway 192.168.1.1. This is the only LAN
  path today.
- `en2/en3/en4` Thunderbolt 1/2/4 + `bridge0` Thunderbolt Bridge — present,
  unconfigured. The direct-link plan has real ports to land on.
- `en5/en6/en7` "Ethernet Adapter" with locally-administered sequential MACs —
  origin unidentified (dock? virtualization残?). Harmless but unexplained;
  identify during Phase 0 (experiment E7) so the interface collector can label
  them.
- `utun6` — Tailscale, 100.87.216.112.
- DNS resolver order: 100.100.100.100 (MagicDNS) first.

## L5 — Tailscale (live + vendor, 2026-08-01)

Live: version 1.98.10; CLI at `/usr/local/bin/tailscale` (symlink installed by
the standalone app, `tailscale-app` cask); `tailscale status --json` parses
cleanly (`BackendState: "Running"`, `Health: []`, Self/Peer objects,
MagicDNS suffix `taila71bd7.ts.net`); **no `/var/run/tailscaled.socket`** —
this is the GUI/system-extension variant, not `tailscaled`. Peers: the MBP
(direct, LAN 192.168.1.88) and an iPhone.

Vendor (tailscale.com/kb/1065 "Variants of Tailscale on macOS"): the
standalone GUI variant **runs after login only**; the open-source `tailscaled`
variant can run before login, supports Tailscale SSH, and is the variant
recommended for headless/unattended machines.

→ Decides: the Tailscale collector's supported interface is the bundled CLI's
`--json` output (the KB treats the CLI as the interface; LocalAPI is not a
stable public surface on the GUI variant).
→ Consequence: today, Tailscale on the Mini depends on auto-login + the user
session. That is a modeled failure mode, and migrating to `tailscaled`
(formula) is a recorded option (ADR 0007 revisit condition).

## L6 — Session, login, launchd inventory (live, 2026-08-01)

- Auto-login is **enabled** (`autoLoginUser = nigiri`); console user `nigiri`
  since boot. Today's availability model: everything rides the auto-logged-in
  GUI session.
- `/Library/LaunchDaemons` is **empty** — nothing on this machine survives
  logout today. User LaunchAgents: disk-prune ×2, `homebrew.mxcl.colima`,
  GPGTools, Google updaters.
- SSH (22) and Screen Sharing (5900) both accept connections (localhost
  probes).

→ Decides: a LaunchDaemon agent is a strict availability upgrade over
everything currently on the machine; it must not assume a GUI session exists.

## L7 — Container runtime (live, 2026-08-01)

colima runs Docker via Virtualization.framework; Docker Engine **29.5.2**
answers on `~/.colima/default/docker.sock` (symlink `~/.colima/docker.sock`,
mode 0600, owner nigiri). Docker Desktop is installed but dataless (issue
#37 decides the survivor). `/var/run/docker.sock` does not exist.

→ Decides: the Docker collector speaks the Docker Engine HTTP API over a
config-specified Unix socket path — that contract survives either #37
outcome. A daemon running as uid 501 can read the socket without privilege
changes.

## L8 — Codex observability surface (live + vendor, 2026-08-01)

Live: codex-cli 0.146.0; the managed standalone app-server daemon from
remote-workflow.md is running (`app-server --listen unix://`, plus ChatGPT's
bundled server and active Desktop-SSH proxies); `~/.codex/` holds
`sessions/`, `session_index.jsonl`, sqlite state/logs.

Vendor (learn.chatgpt.com/docs/hooks, redirected from
developers.openai.com/codex/hooks): hooks engine stable since v0.124.0.
Events include `SessionStart`, `SessionEnd`, `PermissionRequest`, `Stop`,
etc.; hooks receive JSON on stdin (`session_id`, `cwd`, `hook_event_name`,
…); configured via `~/.codex/hooks.json` or `[hooks]` in `config.toml`.

→ Decides: the future Codex adapter is **hook-driven** (Codex pushes events to
the agent's local ingest socket) — a supported interface, no scraping of
internal sqlite. `PermissionRequest` is the documented seam for the eventual
approval-handoff feature. Nothing in v1 touches Codex.

## L9 — Diagnostics access without Full Disk Access (live, 2026-08-01)

`ls /Library/Logs/DiagnosticReports` succeeds as `nigiri` (admin) — panic and
crash reports are enumerable **without FDA**. No `*.panic` files exist (clean
history). Disk: 137 GB free of 229 GB (41% used).

→ Decides: the unexpected-restart/panic collector can run unprivileged.
→ Open (experiment E5): shutdown-cause retrieval via `log show --last boot`
predicate — cost and reliability unmeasured.

## L10 — Client-side APIs (vendor, 2026-08-01)

Apple documentation (SMAppService JSON data endpoint): `SMAppService`
requires macOS 13+; provides `.mainApp` login-item registration,
`agent(plistName:)`, `daemon(plistName:)` (bundle-embedded plists, user
approval via Login Items & Extensions, `status` query). Both machines run
macOS 26, so `MenuBarExtra` (macOS 13+) and `SMAppService` are safely below
deployment target.

## Planned Phase 0 experiments (not yet run)

| # | Experiment | Validates | Method |
|---|-----------|-----------|--------|
| E1 | FileVault preboot-SSH drill | L3 Wi-Fi constraint; unlock runbook | Enable FileVault on a **test volume/spare Mac or scheduled maintenance window**; reboot; attempt preboot SSH over Wi-Fi, then over wired/TB link; time the window; document `fdesetup add -usertoadd` unlock-user flow. Do not run casually — it reboots the Mini. |
| E2 | Classic LaunchDaemon on macOS 26 headless | Agent process model (ADR 0003) | Install a stub plist in `/Library/LaunchDaemons` over SSH; verify BTM notification behavior, start-at-boot pre-login, survival of logout, `UserName nigiri` semantics. |
| E3 | Thunderbolt Bridge static link | Direct link (ADR 0008) | Cable MBP↔Mini; static 10.99.0.1/30 ↔ 10.99.0.2/30 on the bridge service; confirm no DHCP/DNS/route leakage; measure RTT; confirm reachability with Wi-Fi disabled on both ends. Requires physical adjacency. |
| E4 | mTLS + SSE end-to-end | Transport (ADR 0004), auth (ADR 0005) | ~200-line Hummingbird spike: pinned self-signed P-256 certs both ways, `GET /v1/ping`, SSE stream with Last-Event-ID resume; URLSession client on MBP. Lives in `spikes/` when written; throwaway. |
| E5 | Shutdown-cause + panic detection cost | Restart collector | Time `log show --last boot` predicate queries; enumerate DiagnosticReports after a forced restart; decide collector confidence labels. |
| E6 | Secure Enclave key from daemon context | Keychain/identity storage | Attempt SE-backed P-256 key create/sign from a LaunchDaemon (no GUI session) vs file-based key fallback. |
| E7 | Identify en5/en6/en7 | Interface collector labeling | Correlate MACs against docks/virtualization; unplug/replug test. |
| E8 | launchctl print output stability | launchd service collector | Capture `launchctl print` output on 26.5; write the minimal-field parser against fixtures; re-capture after next OS update to detect drift. |

Experiment code, when written, goes in subdirectories here (`spikes/e4-mtls/`
etc.) and must never be imported by production targets.
