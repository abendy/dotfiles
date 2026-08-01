# ADR 0003 — GPG is verification-only; archived keys are retained

- **Status:** accepted
- **Date:** 2026-07-27 (recorded 2026-08-01)

## Context

Signing moved to SSH (ADR 0002). GPG's only remaining job here is *verifying*
the 45 historical commits signed with the old keys — and verification needs no
passphrase, so no pinentry at all.

## Decision

- Keep `gnupg` installed, `[gpg] program = gpg` in gitconfig, and `GPG_TTY`
  in the environment. Everything else — the pinentry dispatcher,
  `configure_gpg_agent`, `PINENTRY_USER_DATA` — was removed.
- Four old GPG keys (short IDs `936EEEA37E0DD3FE`, `B5E5A26DD2011E51`,
  `0D1F77E508961181`, `58A32B7419CBA797`) are archived: public keys imported
  locally so old commits verify; secret keys deliberately **not** imported,
  backed up offline with revocation certificates and ownertrust.
- **The archived keys are retained until proven unnecessary.** Retention
  isn't about current use: a GPG key is the only thing that can ever decrypt
  data encrypted to it. Whether anything was encrypted to these keys is
  unverified — the old Borg/`pass` chain is the prime suspect
  ([#49](https://github.com/abendy/dotfiles/issues/49)). Until that is
  resolved, treat the backups as permanent.

## Consequences

- Non-interactive commits can never again fail on a pinentry prompt.
- An expired GPG key may still be listed on a forge; removing it only makes
  previously-verified commits show as unverified, so it can stay.

## Lesson recorded

The effort that went into making gpg sign unattended was effort spent on the
wrong mechanism. The constraint that ruled out the 1Password agent for
signing (GUI approval, 24h expiry) was also the cue to ask "should gpg be
signing at all?" — earlier.
