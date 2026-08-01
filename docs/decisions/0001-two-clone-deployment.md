# ADR 0001 — Two-clone deployment: deploy copy is disposable, working tree is protected

- **Status:** accepted
- **Date:** 2026-07-27 (recorded 2026-08-01)

## Context

`bootstrap` self-updates by hard-resetting its repository to `origin/master`.
Originally it ran git against `$PWD`, not its own directory — so running
`~/.dotfiles/bootstrap` from inside any repo with a `master` branch would
hard-reset *that* repo. It once came one prompt away from destroying this
working copy.

## Decision

Two clones with different contracts:

- **`~/.dotfiles`** — the deploy clone. Disposable. `auto_update` may
  `reset --hard` it at any time; nothing hand-edited lives there.
- **`~/projects/dotfiles`** — the working tree. Never targeted by automation.

`auto_update` now `cd`s to `$DOTFILES_DIR` and returns early if it isn't a
repo. The reset behaviour itself is intentional and kept.

Dotfiles are **copied** into `$HOME`, not symlinked — the deploy-clone model
depends on copies surviving a clone reset.

## Consequences

- Edits made directly to `~/.zshrc` etc. are write-only: they never flow back
  and the next bootstrap run destroys them. This has already caused real
  drift; a drift detector is tracked in
  [#20](https://github.com/abendy/dotfiles/issues/20) and surfaces via
  `doctor` ([#42](https://github.com/abendy/dotfiles/issues/42)).
- The README long described a workflow contradicting this model; fixing the
  docs is part of [#48](https://github.com/abendy/dotfiles/issues/48).
