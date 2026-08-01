# Failure-mode matrix

Date: 2026-08-01. One row per scenario, answering the seven required
questions. Recovery layers (R1–R7) are defined in
[connectivity-and-recovery.md](connectivity-and-recovery.md#recovery-boundary-taxonomy).

**Abbreviations.**
Paths: **TB** direct Thunderbolt link (requires cable attached) · **LAN**
home-LAN address · **TS** Tailscale · **C** secondary WAN (Phase 4) · **W**
witness (Phase 4, evidence only) · **SSH** break-glass over any live path.
Detection: **CM** client connection manager · **SE** client situation engine ·
**AG** agent collector/health engine · **HB** heartbeat absence · **BS**
boot-session change. "Phys?" = physical presence required for recovery.
Rows assume current hardware reality (Wi-Fi primary; wired `en0` and Phase 4
gear noted where they change the answer).

## Network layer

| Scenario | Detected by | Telemetry available | Paths available | Auto-recovery | User action | Phys? | Evidence retained |
|---|---|---|---|---|---|---|---|
| Mini Wi-Fi fails (today: only LAN uplink) | CM: LAN+TS unreachable; SE: internet-egress from MBP OK ⇒ Mini-side | None live; journal buffers on Mini | TB (attach cable); C later | No (Wi-Fi is the uplink) | Attach TB cable, diagnose via SSH over TB; or physically re-seat network | Often | Journal: interface-collector transitions before loss; client: probe timeline |
| Mini Ethernet fails (once wired; Wi-Fi as standby) | AG: interface/route collector sees en0 down, route flips to en1; CM may not notice | All (via Wi-Fi) | LAN(Wi-Fi), TS, TB | Yes — macOS service order fails over to Wi-Fi | Fix cable/switch at leisure | For cable | `state_transition {net.iface.en0}` + route-change event |
| Home router fails | CM: LAN+TS both die; SE: MBP loses internet too (if home) or keeps it (if away) ⇒ names router/ISP | None live; journal buffers | TB; C later (LTE bypasses router) | No | Power-cycle router (or smart-PDU later); TB for immediate work | Usually | Client probe timeline distinguishing LAN-dead vs TS-dead simultaneity; W history |
| DHCP fails (lease expires, server sick) | CM: LAN endpoint dies while TS lives (TS IP is DHCP-independent once up); AG: interface collector logs address loss | All (via TS) | TS, TB; LAN dead | Partial — TS masks it | Fix router DHCP; consider static/reservation (Q4) | No | Address-change events with timestamps |
| DNS fails (resolver or MagicDNS) | CM: name endpoints fail, **raw-IP endpoints still work**; AG: reachability collector separates DNS-fail from IP-fail | All (via IP endpoints) | TS(ip), LAN(ip), TB | Yes — catalog carries literal addresses by design | None urgent; fix resolver | No | Probe results per endpoint class; agent DNS-probe samples |
| ISP outage (home) | SE: LAN works (if MBP home), TS/DERP dead from outside, agent reports egress fail; W stops seeing Mini but MBP-at-home still does | All if MBP on LAN; none if away (until C) | LAN, TB; C later restores TS | When ISP returns | Wait / tether temporarily; C automates around it | No | Agent `net.egress` samples; W gap window |
| Tailscale coordination outage (vendor) | CM: established TS session may persist; new handshakes fail; MBP's own `tailscale status` unhealthy; LAN fine | All (LAN if home; existing TS session while it lasts) | LAN, TB; TS degraded | Yes when vendor recovers | None; pin LAN path if home | No | Client TS-health observations; probe continuity |
| DERP relay outage | CM: TS works direct at home, fails when roaming+NATed | All at home; none away (until C+direct) | LAN, TB; TS(direct) | When relay recovers or direct path possible | Wait or move MBP to network allowing direct | No | TS status (relay field) from both ends |
| Mini Tailscale daemon/app unhealthy | AG: tailscale collector (`BackendState`, `Health[]`); CM: TS path dead, LAN alive ⇒ SE names Tailscale | All (via LAN/TB) | LAN, TB | Sometimes (extension restart) | SSH in: restart app / `launchctl kickstart`; reboot worst-case | No | Collector samples incl. Health strings; svc transition events |

## Host / OS layer

| Scenario | Detected by | Telemetry available | Paths available | Auto-recovery | User action | Phys? | Evidence retained |
|---|---|---|---|---|---|---|---|
| Mini agent (nigirid) fails/crashloops | CM: `agent_unavailable` on all paths while **SSH port still answers** ⇒ SE says agent-down-host-up | None from agent; MBP-side probes only | All (for SSH); none for protocol | launchd KeepAlive restarts; crashloop → backoff | SSH: `nigirictl status`, logs, rollback binary (R1) | No | Crash reports (unprivileged read), launchd exit history, journal `agent_restart` on recovery |
| MBP client app fails | User notices missing menu item; on relaunch, SE backfills via replay | Agent journals everything meanwhile | n/a (client-side) | Login-item relaunch at next login; user relaunch | Relaunch app; diagnostics if recurrent | No | Client crash report; journal replay covers the gap |
| Mini user logged out | AG: console-user collector (daemon survives — that's the point); GUI-variant TS dies ⇒ TS path drops, LAN stays | All host telemetry; session-scoped collectors (colima/docker, tmux under today's LaunchAgents) report down | LAN, TB (TS gone until login or tailscaled migration) | Auto-login on next boot; not on plain logout | SSH in, `login`/reboot, or accept degraded set | No | `session.console_user` transition; per-collector health showing session scope |
| Mini locked / screensaver | AG: session collector (lock state best-effort, low confidence flagged) | All | All | n/a (not a failure — display state only) | None | No | Lock/unlock transitions where detectable |
| Mini asleep (policy says never; drift or manual) | HB stops cleanly, then womp wake attempts; SE: "host asleep?" hypothesis when all paths die *after* clean heartbeats + pmset drift alert earlier | None while asleep | None until wake (womp magic packet from MBP-on-LAN can wake) | Client sends WoL as a *probe* (read-only-ish; documented exception), womp 1 | Fix pmset drift (alert exists for it) | No | Last samples incl. pmset policy drift alert; wake/boot events |
| Mini restarted (clean, expected) | BS: new boot-session in first heartbeat; uptime reset | Full after boot; gap during | All after boot | Yes — daemon starts at boot pre-login | None; confirm auto-login+agents came up via popover | No | `boot_session_changed {clean: true}` + last-shutdown evidence (E5) |
| Mini restarted into FileVault preboot (if FV enabled later) | CM: all protocol+SSH-on-data-volume dead but **preboot sshd answers password auth** — distinctive signature SE learns to name (R4) | None | Preboot SSH on LAN/TB only (no TS at preboot) | No — needs credential entry | Preboot SSH unlock drill (runbook, E1-validated) or physical unlock | If network preboot unproven | Client timeline; post-unlock journal shows boot session + gap |
| OS hung (kernel alive, userspace wedged) | HB stops; SSH connects but stalls or refuses; TCP may SYN-ACK with nothing above it ⇒ `agent_unavailable` everywhere incl. SSH weirdness | None | None usable | Sometimes watchdog reboots | Force power-cycle (hold button; smart-PDU later) — R3/R6 | **Yes (today)** | Pre-hang samples (thermal? memory?) in journal; panic report if watchdog fired |
| Kernel panic / reboot loop | BS churn if it boots far enough (repeated `boot_session_changed` + `unexpected_restart`); else silence; W sees flapping | Fragmentary | Intermittent | autorestart-after-panic (OS default) may stabilize | Physical: safe mode / DFU / revive (R7 territory) | **Yes** | `.panic` files in DiagnosticReports (readable unprivileged, L9); journal boot-session history |

## Power layer

| Scenario | Detected by | Telemetry available | Paths available | Auto-recovery | User action | Phys? | Evidence retained |
|---|---|---|---|---|---|---|---|
| Power loss (no UPS — today) | Everything dies at once: HB + all paths + (later) W simultaneously; SE: "site power?" when router also gone | None | None | **Only if `autorestart` fixed** (drift task in flight) — then full self-recovery on restore | Restore power; verify boot | Sometimes | Journal's last seconds (WAL-safe); BS change with `unexpected_restart` |
| Power loss (with UPS, Phase 3+) | AG: `ups_on_battery` alert immediately; countdown telemetry; clean shutdown at threshold | All while on battery | All while network gear also on UPS | UPS bridges short outages; clean shutdown + autorestart on restore | Watch countdown; nothing if designed right | No | Full power-event trail: on-battery, runtime samples, `clean_shutdown {reason: ups}`, boot after restore |
| UPS exhaustion mid-outage | AG: runtime-low alert → shutdown event → silence; W corroborates timeline | Until shutdown | Until shutdown | Autorestart when power returns (verify UPS passes power state through) | Size UPS properly; nothing live | No | Shutdown-initiated event as final journal entry |
| Secondary (LTE) router failure — Phase 4 | AG: interface collector on the LTE-facing interface; C-path probes fail while A fine; periodic C-path canary | All | TB, LAN, TS | No | Power-cycle LTE gear (it's on the UPS/PDU) | Sometimes | C-path probe history; canary gap |

## Software / data / credential layer

| Scenario | Detected by | Telemetry available | Paths available | Auto-recovery | User action | Phys? | Evidence retained |
|---|---|---|---|---|---|---|---|
| Corrupt/failed agent update | New binary crashloops → launchd backoff; CM: `agent_unavailable`, SSH fine; version in last heartbeat ≠ expected | None from agent | All for SSH | No (deliberate — fail closed) | SSH: `nigirictl rollback` to kept N−1 binary (ADR 0010); investigate | No | Crash reports; install log; journal `agent_version` events bracketing the update |
| Expired client credential | CM: `auth_failed` on every path (distinct state, never mis-shown as network) | Agent fine, journaling | All transports up; protocol refuses | No — by design | Re-pair over SSH (5-minute runbook); rotation reminders exist (cert-expiry self-metric on both ends) | No | Agent auth-failure events (rate-limited); client `auth_failed` timeline |
| Revoked client credential (stolen-MBP response) | Same `auth_failed` signature on the revoked device | n/a for that client | n/a | n/a — revocation is the *success* | New device pairs via SSH | No | Revocation event (attributable, admin-initiated) in journal |
| Clock drift (either machine) | AG: SNTP-offset collector; protocol: heartbeat carries agent clock, client compares (RTT-compensated) | All | All | chronyd/timed usually self-heals | If sustained: check timed, network to NTP | No | `time.offset_ms` samples; alert at >2 s sustained; TLS failures at extreme drift are pre-explained by the alert |
| Disk full on Mini | AG: disk collector trend + threshold alerts long before; at 100%: journal writes fail → journal-error mode (serve live state, drop history) | Live state yes; history frozen | All | Retention enforcement + disk-prune's monthly cadence help pre-empt | Free space (disk-prune run, big-file hunt) | No | Trend samples leading in; `journal_error {disk_full}` event on client cache |
| Event DB corruption (Mini journal) | AG: `quick_check` at open / write errors at runtime | Live state unaffected; replay history lost | All | Yes: move corrupt file aside, new epoch, keep running (degrade-for-observation rule) | Inspect moved-aside file if curious; ack the gap | No | `journal_epoch_changed` + `journal_gap` events; corrupt file preserved aside |
| Event DB corruption (MBP cache) | Client GRDB errors at open | Agent journal intact — full replay repairs client | n/a | Yes: rebuild cache from snapshot + replay window | None | No | Client log entry; replay refills |
| MBP stolen (credential threat) | Human event, not telemetry | n/a | n/a | No | Runbook: SSH to Mini from anywhere (iPhone Termius/Tailscale SSH), `nigirictl clients revoke mbp`; rotate SSH keys per parent-repo model | No | Revocation audit event; subsequent `auth_failed` attempts logged with source path |

## Reading the matrix

Three signatures the situation engine must learn to name precisely, because
each demands a different human response:

1. **Everything died at once** (HB + all paths + router) → site power or site
   uplink; check W when it exists; nothing to do remotely today (R5/R6).
2. **Protocol dead, SSH alive** → agent-layer problem (R1); fastest fix is
   `nigirictl` over SSH; never confuse with host-down.
3. **`auth_failed` anywhere** → security state, surfaced loudly, excluded
   from silent retry/failover; the fix is a pairing ceremony, not a network
   change.

Gaps this matrix leaves honestly open: OS-hung and no-UPS power loss both
end in physical presence today; Phase 4 (PDU with safeguards, UPS) shrinks
but does not eliminate R3/R7 physical visits. FileVault preboot rows activate
only if/when Q3 flips FileVault on after E1.
