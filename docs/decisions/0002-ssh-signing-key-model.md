# ADR 0002 — SSH commit signing; auth and signing keys always separate

- **Status:** accepted
- **Date:** 2026-07-27 (recorded 2026-08-01)

## Context

GPG signing could not work unattended. `pinentry-mac` needs a GUI session;
over mosh it renders on the remote machine's own display and signing appears
to hang. gpg-agent is a daemon that never sees the shell's `SSH_CONNECTION`,
so a wrapper can't detect remoteness directly. A session-aware pinentry
dispatcher was built and worked — but it existed solely to make the wrong
mechanism survive automation.

The 1Password SSH agent was also ruled out for signing: approval requires the
desktop GUI, and the grant expires after 24 hours — a rebooted headless
machine would silently stop signing.

## Decision

- `gpg.format = ssh`. Git signs with `ssh-keygen -Y sign`.
- **Auth and signing are always separate keys. One signing key per machine**,
  so a machine can be revoked on its own. The `git-allowed-signers` file
  carries one line per machine: the email identifies the person, the key
  identifies the machine.
- **Signing keys never have a passphrase** on any machine: git invokes
  `ssh-keygen -Y sign` directly, which does not read `ssh_config` and
  therefore cannot use the keychain.
- Auth keys *may* carry passphrases on the laptop (`UseKeychain yes` reads
  the unlocked login keychain). A headless machine reached over SSH has no
  GUI login, its keychain stays locked, so its keys carry no passphrase —
  that is a deliberate capability boundary, not an oversight
  ([#43](https://github.com/abendy/dotfiles/issues/43),
  [#45](https://github.com/abendy/dotfiles/issues/45)).
- The 1Password agent is **opt-in per host** only. Never set `IdentityAgent`
  under `Host *`: it overrides `SSH_AUTH_SOCK` and makes every key outside
  the vault unreachable. `SSH_AUTH_SOCK` itself is left alone — launchd
  points it at the macOS system agent, the only agent that works unattended.
- Never put a signing key into `authorized_keys`.

## Consequences

- Signing works with no agent, no `DISPLAY`, and `SSH_CONNECTION` set —
  verified unattended.
- A passphrase-less key is readable by every process running as that user;
  scoping what such keys can reach is the subject of #43.

## Gotchas worth keeping

- Neither GitHub nor GitLab has a separate signing-key page — both reuse the
  "add SSH key" form with a type selector defaulting to Authentication.
- GPG Suite rewrites `~/.gitconfig` to `gpg.format = openpgp` when importing
  keys. If commits suddenly fail to sign, check that first.
