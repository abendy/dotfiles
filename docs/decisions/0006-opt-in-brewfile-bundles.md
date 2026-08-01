# ADR 0006 — Lean root Brewfile plus opt-in bundles

- **Status:** accepted — expected to evolve into machine profiles
- **Date:** 2026-07-27 (recorded 2026-08-01)

## Context

A single Brewfile accretes: aspirational packages, one machine's tools on
every machine, and entries that quietly fall out of the Homebrew catalog.
Several old topic bundles were uninstallable as written.

## Decision

- The root `Brewfile` stays lean: the genuinely shared foundation only.
- Everything else lives in `Brewfiles/<name>.Brewfile` as per-machine
  **opt-ins**, installed interactively via `bin/brewfile` (fzf multi-select
  picker). Stale bundles move to `Brewfiles/archive/` rather than being
  deleted.
- Language tooling gets focused bundles (node, python, …) instead of
  kitchen-sink ones; language *versions* are pinned per project, not here.

## Consequences

- Opt-in installs are not yet reproducible: `bootstrap` only installs the
  root Brewfile, and nothing records which bundles a machine chose —
  [#21](https://github.com/abendy/dotfiles/issues/21).
- Old bundles still carry dead entries —
  [#46](https://github.com/abendy/dotfiles/issues/46).
- The natural evolution is explicit machine profiles
  ([#40](https://github.com/abendy/dotfiles/issues/40)); this ADR is
  superseded in part when that lands.
