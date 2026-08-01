# Open questions

Date: 2026-08-01. Split into: decisions needing the user, uncertainties
needing experiments, and design questions parked with a default. Nothing
here hides behind "best practices" — each has a recommendation and what
would change it.

## Needs the user (blocking or shaping)

- **Q1 — Repo home.** Stay a dotfiles subproject (disk-prune precedent,
  doc-contract adjacency) or extract to `abendy/nigiri-control-plane` at
  Phase 1 (CI, releases, issues namespace of its own)?
  *Recommendation:* plan here, **extract at Phase 1 start** — an app with CI,
  signing, and release artifacts outgrows a dotfiles repo fast, and parent
  conventions (issues on abendy/dotfiles) already strain at the seams.
  Changes if: user prefers the monorepo's single-pane history.
- **Q2 — Developer ID ($99/yr).** *Recommendation:* yes — stable TCC
  identity, notarization, Sparkle. Changes if: cost aversion wins; plan
  degrades gracefully to build-from-repo + manual approvals.
- **Q3 — FileVault on the Mini.** Newly viable (macOS 26 preboot SSH unlock,
  verified L3) but gated on E1 (Wi-Fi preboot unproven; wired Ethernet
  materially helps). *Recommendation:* enable only after E1 passes + wired
  link + rehearsed runbook; until then remain off (current posture). This
  feeds the pending decision recorded in `mac-mini-setup.md`.
- **Q4 — Router DHCP reservation** for the Mini (and eventually wired en0).
  Small router-admin task; *recommendation:* yes, it upgrades the LAN
  endpoint from "last-known" to "static".
- **Q5 — Physical adjacency.** Are MBP and Mini ever desk-adjacent for a
  permanently-attached TB cable, or is Path B strictly walk-over recovery?
  Determines whether Path B is an everyday fast path. No wrong answer;
  changes path-priority defaults and E3 logistics.
- **Q7 — UPS purchase** (model with USB data + enough outlets for network
  shelf; ~$150–250). *Recommendation:* yes at Phase 3; power rows of the
  failure matrix stay red until then. Include whether network gear
  (modem/router/switch) shares it or gets a second small UPS.
- **Q8 — Witness hosting.** healthchecks.io-class SaaS (free tier, mature
  mobile push) vs self-hosted (another thing to monitor). *Recommendation:*
  SaaS for Phase 4; self-host only if a personal server exists by then.
- **Q10 — Secondary WAN budget/carrier** (LTE router + data SIM, ongoing
  cost). Phase 4; *recommendation:* decide after Phases 1–3 prove value.

## Needs an experiment (owner: Phase 0 unless noted)

- E1 FileVault preboot networking on Wi-Fi (WPA2/3?) vs wired; preboot sshd
  interface exposure. Gates Q3.
- E2 headless BTM/LaunchDaemon UX on macOS 26 (notification? approval toggle
  state? survives OS update?).
- E3 TB-bridge static-link behavior incl. sleep/hotplug edge; RTT.
- E4 Hummingbird mTLS client-cert verification + SSE under URLSession —
  including whether URLSession's client-identity handling and custom trust
  evaluation compose cleanly (the known-risky corner of the client
  transport).
- E5 shutdown-cause query cost/reliability (`log show --last boot`).
- E6 SE-backed keys from a LaunchDaemon (no GUI session) — falls back to
  0600 files without drama if not.
- E7 identify en5/en6/en7 phantom interfaces.
- E8 `launchctl print` fixture drift across OS updates.
- **E9 (new)** MenuBarExtra `.window` adequacy for the popover density —
  else NSStatusItem+NSPopover fallback (both wrap the same view model; a
  day's spike, client-side).

## Parked with a default

- **Tailscale variant migration** (GUI app → open-source `tailscaled` for
  pre-login/logout-surviving VPN): default *no* for now (repo convention:
  cask-managed; auto-login makes the gap mostly theoretical). Revisit when:
  logout-survival matters in practice, or Tailscale SSH (`tailscale set
  --ssh`, already a mac-mini-setup TODO) becomes wanted — it requires
  tailscaled.
- **Tailnet lock**: attractive against coordination-plane compromise;
  parked to Phase 2 hardening with a docs pass.
- **HMAC hash-chaining of journal events**: cheap tamper-evidence; parked —
  client mirror + witness cover the realistic threat.
- **Client sandboxing**: try App Sandbox in Phase 1; drop without guilt if
  Keychain/UDS/Sparkle friction appears (Developer ID non-sandboxed is
  fine outside the App Store).
- **Bonjour advertisement** (`_nigirid._tcp`): ship disabled-by-default;
  enable if Q4 is declined and LAN addresses churn.
- **Q6 — Config-setting placement** (the required split): defaults as
  proposed — *repo-tracked TOML templates* for anything an incident might
  need versioned (endpoints, thresholds, collectors); *MBP UI* writes only
  presentation prefs + manual pins (UserDefaults); *Mini-local* runtime
  state (node identity, keys) outside the repo; *Keychain* for every
  private key; *future shared config service*: none — two machines don't
  need a control plane for their control plane. Open only in the sense
  that lived experience may promote UI-editable thresholds later.
