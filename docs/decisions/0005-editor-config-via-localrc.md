# ADR 0005 — Editor choice lives in machine-owned `~/.localrc`

- **Status:** accepted
- **Date:** 2026-07-27 (recorded 2026-08-01)

## Context

The editor is a machine/user preference, not repo policy: a GUI editor makes
sense at the laptop's console, while a box driven over SSH+tmux needs a
terminal editor. Bootstrap used to prompt for this on every run and could
overwrite the choice.

## Decision

- `EDITOR` is set in `~/.localrc`, which bootstrap seeds from a template
  **once** and never prompts about or overwrites again — the file is
  machine-owned and manually edited.
- Git's editors are deliberately independent of the shell default:
  `core.editor = vim`, `sequence.editor = interactive-rebase-tool`.

## Alternatives rejected

- **Tracked in `zshrc`/`zshenv`** — turns a per-machine preference into
  shared repo policy and makes local-vs-SSH variation noisier.
- **Wrapper command** (`EDITOR=~/bin/editor` selecting at runtime) —
  needless indirection for a two-branch check.
- **direnv** — right for a genuine project requirement, surprising as the
  global mechanism.
- **`launchctl setenv`** — stateful, invisible, hard to reproduce; no
  current consumer justifies it.
- `VISUAL` alongside `EDITOR` is complementary, not an alternative; set both
  in `localrc` if a distinction ever becomes useful.

## Consequences

- Selection should be by what exists (is the GUI editor installed, is this
  an SSH session), not assumption — the current template got this wrong on
  the headless box ([#9](https://github.com/abendy/dotfiles/issues/9)).
- Machine-owned files are invisible to the repo, so they drift silently —
  the general answer is the drift detector in
  [#20](https://github.com/abendy/dotfiles/issues/20).
