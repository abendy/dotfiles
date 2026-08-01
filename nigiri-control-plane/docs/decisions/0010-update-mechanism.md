# ADR 0010 — Update mechanism: build-from-repo agent with kept-N−1 rollback; signed client updates

- **Status:** proposed
- **Date:** 2026-08-01

## Context

Updates are the highest-leverage attack channel (threats T11/T12) and the
most likely self-inflicted outage. The parent repo already runs a
git-anchored deployment culture (two-clone model, SSH-signed commits,
`brew upgrade` over SSH) and issue #39 tracks auto-convergence.

## Decision drivers

An update must never be able to remove all recovery access; forged/
downgraded artifacts must be detectable; the mechanism must fit
SSH-administered headless reality; version skew must be survivable
(protocol already guarantees this); rollback must be a rehearsed one-liner.

## Considered alternatives

- **Homebrew personal tap** — rides the existing `brew upgrade` habit
  (attractive, matches conventions) but inserts a third-party distribution
  surface (tap repo + bottles) whose compromise story is worse than
  building from the already-trusted repo; revisit post-extraction (Q1) when
  CI exists to build bottles reproducibly.
- **Sparkle for the agent** — Sparkle is an app-update framework; daemons
  need orchestrated restart/selfcheck/rollback that Sparkle doesn't model.
  Client-side only.
- **Full auto-update from day one** — rejected: the rollback path must be
  drilled before automation is allowed to exercise it unattended (Phase 1
  exit criterion), and #39's converge machinery is the natural future home.

## Decision

**Agent:** versioned side-by-side installs
(`/usr/local/libexec/nigiri-control-plane/versions/<v>/` + `current`
symlink) built by `install.sh` from the deploy clone; `--upgrade` runs the
new binary's `--selfcheck` (config parse, DB migrate dry-run, key load,
bind test) before flipping the symlink and kickstarting; previous version
retained (keep 2); `nigirictl rollback` (or manual symlink flip over SSH)
reverses it; DB snapshot before migrations (14-day retention);
forward-only-compatible migration policy so N−1 opens N's DB.
**Client:** Sparkle 2 with EdDSA-signed appcast if Q2 (Developer ID) is
approved; otherwise rebuild-from-repo. **Never both sides in one action.**
Trust anchor for both: this repo's SSH-signed commits verified against
`git-allowed-signers`.

## Consequences

No update server to run or compromise; upgrade requires an SSH session (a
feature until #39 lands — every upgrade has an operator watching); skew
between agent and client is normal, visible (`agent_version_mismatch`
alert), and tested; build-on-the-M4 keeps working because CLT-only builds
are proven (L1).

## Security implications

Supply chain = git remote (GitHub over SSH/TLS + signature verification) +
pinned SwiftPM deps; no binary artifacts transit any channel for the
agent; a malicious update requires signing-key or repo-push compromise —
which is already game-over-adjacent under the parent repo's model, so no
*new* trust is created. Downgrade attacks reduce to git history rewrites —
detectable by signature + reflog hygiene.

## Validation required

Phase 1 drill: intentional bad build → selfcheck refusal; intentional
crashloop build → rollback under 5 minutes from a cold SSH session;
migration snapshot/restore exercise.

## Revisit conditions

Q1 extraction + CI maturity (tap/bottle distribution reconsidered); #39
machinery lands (supervised auto-upgrade with the same selfcheck gate);
fleet grows beyond hand-SSH scale.
