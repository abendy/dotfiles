# ADR 0007 — Language toolchains are `langs/` scripts, with a Brewfile only for plain packages

- **Status:** accepted — Swift is migrated; Node, Python, Rust and Go are
  still `other-brews/` bundles
- **Date:** 2026-10-13

## Context

A Brewfile can install a language's toolchain manager, but not the rest of
the setup: installing a toolchain, setting the global default, and wiring
the shell. That wiring ended up in two bad places. nvm's lived as hand edits
in the untracked `~/.localrc`, so it didn't reproduce on a new machine.
fnm's moved into tracked `zshrc` as a guard, so every machine carries every
language's guard. Some managers also edit shell profiles themselves (swiftly
appends to `~/.zprofile`), outside anything the repo tracks.

## Decision

- Each language gets `langs/<lang>`: an executable, idempotent script that
  is the one entry point for that language.
- Plain packages go in `langs/<lang>.Brewfile` beside it, and the script
  runs `brew bundle install --no-upgrade` on it. The Brewfile says what to
  install; the script does what a Brewfile can't.
- Shell wiring goes in a marked block (`# >>> dotfiles: <lang> >>>`) in
  `~/.localrc`, which the script rewrites in place on every run. Outside
  the markers, `~/.localrc` stays machine-owned (ADR 0005).
- Managers are told not to edit profiles themselves (swiftly's
  `--no-modify-profile`, rustup's and uv's `--no-modify-path`).
- Scripts never upgrade or pin as a side effect. `--no-upgrade` keeps the
  MacBook on Xcode 26.x, and defaults are set with global options, never
  per-directory ones: `swiftly install --use` wrote a `.swift-version` into
  whatever folder the script ran from.

## Alternatives rejected

- **Brew for everything, manager included** — Homebrew's swiftly (1.1.4)
  lags swift.org's (1.2.0), and swiftly updates itself, so brew and swiftly
  would both own one binary.
- **Script for everything** (`brew install` / `mas install` calls) —
  rewrites the checks `brew bundle` already does, and the packages drop out
  of `brew bundle check`.
- **Keep the bundle plus a tracked `zshrc` guard** (the fnm pattern) — the
  bundle still can't install a toolchain, and every machine pays for every
  language's guard.
- **Skills instead of scripts** — a skill needs an agent to run it; a fresh
  machine and `bootstrap` need a plain executable. A skill can wrap this
  pattern later.
- **Let the manager edit the profile** — the line lands outside anything
  the repo can rewrite, and re-runs can duplicate it.

## Consequences

- One command per language reproduces the install and the wiring, and
  re-running it converges instead of piling up edits.
- `~/.localrc` now has script-owned sections inside a machine-owned file.
  Hand edits inside the markers are lost on the next run.
- There are two install paths until the other languages move:
  `brewfile` for topic bundles, `langs/` for languages.
- As with bundles (ADR 0006), nothing records which languages a machine
  chose.
- Xcode comes through `mas`, which needs an App Store sign-in. On the
  headless mini that's a one-time Screen Sharing step.

## Revisit when

Machine profiles land ([#40](https://github.com/abendy/dotfiles/issues/40)):
a profile may decide which `langs/` scripts a machine runs.

## References

- `langs/swift` (`localrc_put_block`, `install_toolchain`), `langs/swift.Brewfile`
- The fnm block in `zshrc`
- ADR 0005 (machine-owned `~/.localrc`), ADR 0006 (opt-in bundles)
