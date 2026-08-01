# Deployment and updates

Date: 2026-08-01. Prime invariant: **no update state may remove all recovery
access** — SSH functions independently of everything here, and the previous
agent binary survives every upgrade until its successor proves itself.

## Distribution model (ADR 0010 summary)

**Agent (Mini): build-from-repo.** `install.sh` (disk-prune precedent) builds
with SwiftPM on the Mini and installs. There is no third-party distribution
channel to trust or to forge: the supply chain is this git repository
(SSH-signed commits, verifiable against `git-allowed-signers`) plus pinned
SwiftPM dependencies. Respect the two-clone model (parent ADR 0001): builds
run from the deploy clone `~/.dotfiles`; the working repo is never the
install source.

**Client (MBP): built on the MBP** from the same repo. Development signing
suffices for a personal machine *if* Q2 (Developer ID, $99/yr) is declined —
with the tradeoffs below.

## Signing, notarization, hardened runtime

| Choice | Local/dev-signed | Developer ID + notarization (recommended) |
|---|---|---|
| Gatekeeper | manual right-click-open dance once per build | clean |
| TCC identity stability | ad-hoc identities can reset permission grants across rebuilds | stable — the notification grant survives updates |
| Hardened Runtime | on either way | on |
| launchd daemon (Mini) | works — plists don't require notarization for locally-built binaries | works; signing gives BTM a stable identity label |
| Sparkle auto-update | inappropriate (unsigned feeds) | supported (EdDSA-signed appcast) |

Recommendation: **buy Developer ID** (Q2). Durable personal infrastructure
deserves stable code identity; the annual cost is the whole argument against.
Plan works without it (build-from-repo both sides, manual Gatekeeper
approval, re-grant notifications after client rebuilds).

## Install flows

**Mini (agent):**
1. `./install.sh` from the deploy clone: SwiftPM release build → binaries to
   `/usr/local/libexec/nigiri-control-plane/versions/<v>/` with a `current`
   symlink; `nigirictl` linked into `/usr/local/bin`.
2. `sudo ./install.sh --daemon`: writes the LaunchDaemon plist
   (`UserName nigiri`, KeepAlive, UDS + config paths), `launchctl bootstrap
   system`. Only step needing sudo; idempotent. macOS 26 BTM will show a
   background-items notification — expected; E2 validates the headless
   experience.
3. First run mints node identity + agent key, creates
   `~/.config/nigiri-control-plane/agent.toml` from the repo template if
   absent, opens the journal.
4. Doc contract: this step, when real, appends to `mac-mini-setup.md` and
   updates the parent CLAUDE.md table in the same change.

**MBP (client):** build; copy to /Applications; first launch registers
`SMAppService.mainApp` login item (user-visible, per Apple's approval UX) and
requests notification permission. That's the entire TCC/approval surface.

**Pairing** (once, order-independent after installs): `nigirictl pair
--host nigiri` on the MBP → SSH-transported enrollment + 6-word fingerprint
confirmation on both terminals (threat model §pairing). Client writes key to
Keychain, endpoints to `client.toml`.

## Upgrades

**Agent:** manual in v1 — `git pull` in the deploy clone, `./install.sh
--upgrade`: builds new version side-by-side, runs `nigirid --selfcheck`
(config parse, DB open+migrate dry-run, key load, port bind test on an
ephemeral port), flips `current`, `launchctl kickstart -k`. Old version dir
retained (keep 2). Auto-upgrade is *deliberately absent* until the #39
auto-converge machinery exists and the rollback path has been drilled;
version skew is tolerated by protocol design and alerted on
(`agent_version_mismatch`) so drift is visible, not fatal.

**Rollback:** `nigirictl rollback` (or by hand over SSH: flip symlink +
kickstart) → previous version boots against the *newer* DB; GRDB migrations
are therefore **forward-only-compatible by policy**: a migration may add,
never repurpose; a downgraded agent runs with reduced knowledge but runs.
Migration tests enforce this (testing doc). DB backup snapshot
(`journal.pre-<v>.sqlite`, retained 14 d) taken before any migration as the
last-resort restore.

**Client:** Sparkle 2 with EdDSA keys if Q2 yes; otherwise rebuild-from-repo.
Never auto-update agent and client in the same action — one side must always
be a known-good observer of the other's upgrade.

**Failed update recovery, worst case:** new agent won't start → launchd
backoff → client shows agent-down-host-up → SSH in → `nigirictl rollback` →
investigate at leisure. This path must be drilled in Phase 1 (rollout doc)
before any upgrade is performed casually.

## Configuration migration

`config_version` in TOML; the agent migrates old→new in memory and writes
back only on explicit `nigirictl config upgrade` (files are user-owned
artifacts, possibly repo-tracked — silent rewrites would fight the dotfiles
model). Unknown keys warn; missing keys default; invalid values fail the
staged load (last-good keeps running + `config_error` alert).

## Uninstall

`sudo ./install.sh --uninstall`: bootout + remove plist, remove
`/usr/local/libexec/nigiri-control-plane`, leave `~/.config/…` and the
journal **in place by default** (`--purge` removes them after a
plain-language confirmation listing exact paths). Client: remove login item
registration, delete app; Keychain items and cache listed for optional
manual/`--purge` removal. Enrollment revocation on the agent side is part of
the runbook, not automatic (a wiped client shouldn't be able to silently
de-enroll itself — that's an admin act over SSH).

## Log/database preservation policy

Journals and logs are evidence: uninstall preserves them; upgrades never
truncate them; corruption recovery moves files aside rather than deleting;
`--purge` is the only deletion verb and it names its targets before acting.
