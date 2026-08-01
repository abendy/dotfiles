# ADR 0002 — Client implementation architecture: SwiftUI MenuBarExtra app

- **Status:** proposed (accept after E9)
- **Date:** 2026-08-01

## Context

The MBP client is a menu-bar presence with a dense popover, a settings
scene, a diagnostics window, notifications, Keychain-held credentials, an
SQLite mirror, and a connection manager — resident whenever the user is
logged in.

## Decision drivers

Native look/behavior; macOS 26 deployment target on both machines (no
back-compat tax); minimal TCC surface; testable core logic independent of
UI; longevity across macOS releases (supported APIs only).

## Considered alternatives

- **AppKit NSStatusItem + NSPopover throughout** — maximum control, more
  boilerplate; kept as the *fallback presentation layer* (E9) behind the
  same view models rather than a competing architecture.
- **Electron/Tauri/web-anything** — rejected: heavyweight residents, weak
  Keychain/UN integration, aesthetic mismatch with "durable personal
  infrastructure."
- **Catalyst/cross-platform-first** — no iOS client exists yet; designing
  the *model* layer platform-neutral (it is — NCPModel has no UI imports)
  buys the future without paying Catalyst's costs now.

## Decision

SwiftUI app: `MenuBarExtra` (`.window` style) + `Settings` scene + a
Diagnostics `Window`; `LSUIElement`; `SMAppService.mainApp` login item
(macOS 13+ API, verified L10); UserNotifications for alerts; AppKit
interop where SwiftUI is thin. Strict separation: `SituationEngine`,
`ConnectionManager`, and stores are UI-free and unit-tested; views render
their published state.

## Consequences

One TCC prompt total (notifications); login-item registration is
user-visible and revocable per Apple UX; MenuBarExtra styling limits are a
known risk fenced by E9's fallback plan; no Dock icon means the app must be
discoverable via the glyph alone (acceptable — single user).

## Security implications

Client key in Keychain (SE-backed if E6-equivalent works app-side);
Hardened Runtime; sandbox attempted in Phase 1, droppable (open-questions
§parked); no URL handlers or IPC surface beyond its own UDS-free client
role in v1.

## Validation required

E9 popover-density spike; SMAppService registration/unregistration drill;
notification-grant persistence across dev-signed rebuilds (informs Q2
urgency).

## Revisit conditions

MenuBarExtra regressions across macOS updates (swap presentation to
NSStatusItem per E9 plan); iOS companion work begins (extract shared UI
patterns then, not before).
