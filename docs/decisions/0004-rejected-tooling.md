# ADR 0004 — Tooling considered and rejected

- **Status:** accepted (each row carries its own revisit condition)
- **Date:** 2026-07-27 (recorded 2026-08-01)

Decisions from the 2026-07 modernisation survey. Recorded so the same
evaluations don't get re-run from scratch.

| Option | Why not |
|---|---|
| **sheldon / zinit** | antidote already pre-bundles to static zsh at bootstrap — 0.9ms at startup. Identical outcome, migration cost for nothing. |
| **Dropping the plugin manager entirely** | The startup argument assumes the manager is the cost. Here antidote is 0.3% and oh-my-zsh 2.9% of startup. Saves nothing. |
| **age / sops** | Solve "commit encrypted material to the repo". Nothing here needs encrypting into the repo — key material lives outside it entirely (see `.gitignore`'s defence-in-depth block). |
| **`op read` at shell startup** | Latency plus a biometric prompt per shell — backwards for tmux/mosh where shells are cheap and frequent. Per-invocation injection (`op plugin init gh`) is the right shape if needed. |
| **mise** | uv (Python) + rustup (Rust) + fnm (Node) + stock go cover everything, each better than a generalist. Since Go 1.21, `GOTOOLCHAIN=auto` reads `go.mod` and fetches its own toolchain — the last thing a version manager was doing here. **Revisit if:** adopting a language with no good native story (Elixir, Java), or wanting mise's task-runner/env features as a direnv replacement. |
| **chezmoi / yadm / GNU Stow / home-manager** | No pressing driver while the bootstrap script works. chezmoi is the default recommendation if templating/secret integration ever becomes necessary; home-manager is the only real reproducibility option but has the steepest curve. **Revisit if:** per-machine templating outgrows the profile mechanism ([#40](https://github.com/abendy/dotfiles/issues/40)). |
| **nix-darwin + home-manager for convergence** | The real "declared state == machine state" answer, but a rewrite of the whole approach, not an increment. A converge LaunchAgent gets most of the value at a fraction of the cost ([#39](https://github.com/abendy/dotfiles/issues/39)). **Revisit if:** drift keeps happening anyway. |

Related replacements that *were* made, for the record: nvm → fnm, rupa/z →
zoxide, percol/thefuck removed, GPG signing → SSH signing (ADR 0002).
