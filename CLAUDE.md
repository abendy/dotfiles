# CLAUDE.md

## What this repo is

Declarative setup for two machines:

- **nigiri** (`nigiri-san`) — a headless 256 GB Mac mini devbox, reached via
  Tailscale + mosh + tmux. Agent sessions usually run *on* this machine.
- The **MacBook** — the user's laptop. Separate machine, separate installs;
  don't assume its state from what's visible here (e.g. Docker Desktop is
  daily-driven on the laptop but unused on the mini).

## Docs and their contract

| Doc | Covers |
| --- | --- |
| [README.md](README.md) | what's installed, bootstrap, shell setup |
| [mac-mini-setup.md](mac-mini-setup.md) | provisioning the mini — a running log; machine-state changes append here |
| [remote-workflow.md](remote-workflow.md) | day-to-day remote use (Tailscale/mosh/tmux, Codex SSH) |
| [remote-commands.md](remote-commands.md) | tmux/mosh helper reference |
| [disk-prune/README.md](disk-prune/README.md) | scheduled cache pruning tool |

**The rule this file exists for:** any change to machine state — Brewfile
edits, new LaunchAgents, `defaults` writes, new steps in `bootstrap` /
`osx` / `osx-devbox`, installed or removed apps — must update the matching
doc *in the same change*. This file and all documentation move with the
repo: a change and its doc update land together, and a doc (including this
one) that says something the machine no longer does is a bug.

## Conventions

- Work is tracked in Linear — workspace `lone-space`, project "dotfiles",
  `LON-nn` ids. GitHub issues on `abendy/dotfiles` are a closed, read-only
  archive with "Migrated → LON-nn" pointers; don't file new ones. PRs and
  code stay on GitHub. Issue numbers cited elsewhere in this file (#38, #39)
  refer to that archive.
- Apps on the mini should be brew-cask-managed wherever possible — GUI
  update prompts don't get clicked on a headless machine; `brew upgrade`
  over SSH does. Google Chrome is kept on the mini for Computer Use —
  don't propose removing it to save space.
- The interactive shell aliases `du` to `du -h -d 2` (`aliases:24`), which
  breaks `du -s`. Scripts must call `/usr/bin/du` or `command du` (#38).
  *Temporary note: #38's fix includes deleting this bullet.*
- An agent-facing summary of the shell environment (interactive `rm`/`cp`/`mv`,
  `cat`→bat, `diff`→icdiff, eza, `find -L`, GNU-first PATH) lives in
  `abendy/skills` → `global/CLAUDE.md` (Shell section). When `aliases`,
  `functions`, or the gnubin PATH exports change semantics of standard tools,
  update that summary in the same change.
- Two clones live on the mini: `~/projects/dotfiles` (working repo — commit
  here) and `~/.dotfiles` (deployed clone that `bootstrap` runs from). After
  pushing changes, pull in `~/.dotfiles` and re-run `./bootstrap` there —
  automating this is [#39](https://github.com/abendy/dotfiles/issues/39).
- Commits are SSH-signed with a per-machine no-passphrase key; see README
  before touching signing config.
