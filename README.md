# dotfiles

Includes:

* [Xcode Command Line Tools][xclt]
* [Homebrew][hb]
* Brews and [Casks][casks]
* [Oh My Zsh][omz]

```sh
git clone https://github.com/abendy/dotfiles.git ~/.dotfiles && cd ~/.dotfiles
./bootstrap
./osx
```

On the headless Mini, run `./osx-devbox` instead of `./osx`. It applies the
Mini-specific power and remote-access policy and permanently converges its
ComputerName, LocalHostName, and HostName to `nigiri-san`.

See the [remote workflow](remote-workflow.md) for setup and troubleshooting and
[REMOTE-COMMANDS(1)](remote-commands.md) for the tmux/mosh helper reference.

`~/.localrc` holds local runtime configuration and is not tracked by this repo.
`bootstrap` copies the `localrc` template there if the file doesn't already
exist, then leaves it alone. Editor selection is not prompted on later runs;
edit `EDITOR` (and optionally `VISUAL`) in `~/.localrc` directly. To seed it by
hand: `cp localrc ~/.localrc`.

## ZSH plugins

We're using [antidote][ab] as the plugin manager, across two lists.

**Shared plugins** live in `zsh/plugins.txt` (tracked, applies to every machine). `bootstrap` bundles it automatically. If you edit the list without re-running `bootstrap`, re-bundle by hand:

```sh
antidote bundle < ~/.dotfiles/zsh/plugins.txt > ~/.zsh_plugins.sh
exec zsh
```

**Machine-local plugins** live in a file you create yourself, so they stay off the shared list. Add plugins one per line as per the [antidote documentation][abd].

```sh
touch ~/.zsh_plugins_locals.txt
vi ~/.zsh_plugins_locals.txt
antidote bundle < ~/.zsh_plugins_locals.txt > ~/.zsh_plugins_locals.sh
exec zsh
```

The output filename matters: `zshrc` sources `~/.zsh_plugins.sh` and `~/.zsh_plugins_locals.sh` behind a `[ -f ]` test, so a mistyped name fails silently rather than erroring.

## Key bindings

Defined in `input`, installed to `~/.input` by `bootstrap` and sourced from `zshrc`. Uses emacs mode (`bindkey -e`).

| Key | Action | Provided by |
| --- | --- | --- |
| `alt + left` / `alt + right` | move back / forward one word | `input` |
| `ctrl + x` | insert output of last command | `input` |
| `ctrl + b` | `cd -` — back to previous directory | `input` |
| `ctrl + space` | `tig status` | `input` |
| `ctrl + r` | search shared laptop + Mini history | Atuin |
| `ctrl + t` | search current directory, insert path on the command line | fzf |
| `ctrl + z` | browse zoxide history with fzf | `zsh/fzf-z.plugin.zsh` |
| `ctrl + a` | move to beginning of line | zsh |
| `ctrl + w` | delete word backward | zsh |
| `ctrl + y` | insert last deleted word | zsh |
| `ctrl + u` | clear line | zsh |
| `ctrl + k` | delete to end of line | zsh |
| `ctrl + l` | clear screen | zsh |
| `ctrl + g` | abort | zsh |
| `ctrl + c` | cancel | zsh |
| `fn + left` / `fn + right` | move to beginning / end of line | terminal |

To check what a key is actually bound to: `bindkey "^X"`.

## Shell history

[Atuin][atuin] records contextual shell history locally and, once signed in,
syncs it end-to-end encrypted between the laptop and Mini. `Ctrl-R` searches
global history; the Up arrow keeps its normal shell behavior. Selecting a result
returns it to the prompt for review rather than executing it immediately.

The tracked config contains no account or key material. Atuin keeps its
encryption key and sync session outside this repo. Store the encryption key in
1Password: it is required, along with the account password, to add a new
machine.

One-time setup on the first machine:

```sh
atuin import auto
HISTFILE=/path/to/old/.zsh_history atuin import zsh
atuin register -u USERNAME -e EMAIL
atuin sync
```

Import each source only once: repeated imports create duplicate history.
Omitting password/key flags keeps those values out of the legacy Zsh history
file and prompts for them safely.

On the second machine:

```sh
atuin login -u USERNAME
atuin sync
atuin doctor
```

Prefix any sensitive command with a space to keep it out of both Zsh and Atuin
history. Atuin's built-in secret filter is enabled as an additional safety net,
but it cannot recognize every possible credential.

## Prompt

[Starship][starship] provides the prompt while Oh My Zsh continues to provide
the shell framework and plugins. The tracked prompt is deliberately selective:

- hostname only over SSH (`nigiri-san` on the Mini);
- current directory and read-only state;
- Git branch, worktree counts, ahead/behind counts, and operations such as
  rebases or cherry-picks;
- Node, Python, Go, and Rust versions only in matching projects;
- commands taking at least five seconds, non-zero exit status, and background
  jobs.

Context and command entry share one line so terminal clear commands such as
iTerm2's `Cmd-K` do not erase the useful prompt state above the cursor.

## Directory jumping

We're using [zoxide][zx], which provides a `z` command that jumps to the best match for a partial path, and `zi` to pick from matches interactively.

```sh
z dotfiles      # jump to the highest-ranked directory matching "dotfiles"
zi dotfiles     # choose interactively between matches
```

On a new machine, migrate an existing `z` database if there is one. The old datafile is read on **stdin**:

```sh
zoxide import z < ~/.z
```

## Commit signing

Commits are signed with SSH, not GPG — `gitconfig` sets `commit.gpgsign = true`
with `gpg.format = ssh`.

The signing key is `~/.ssh/git_signing`, **one per machine**, ed25519, with **no
passphrase**. That's the point: it signs unattended on the Mini over SSH, where
GPG falls back to a curses pinentry and prompts, and where 1Password's agent
can't help because it needs the desktop GUI to approve and its Touch ID grant
expires after 24 hours.

The tradeoff is deliberate and scoped. The key is signing-only and must never
appear in any `authorized_keys`, so compromise means forged signatures rather
than server access. GitHub tracks signing keys separately from authentication
keys. Rotation is just generating a new key and updating two places.

`bootstrap` generates the key when it's missing and prints it. Register it:

1. **github.com/settings/keys → New SSH key**, and set the **Key type** dropdown
   to **Signing Key** — it defaults to *Authentication Key*. There's no separate
   signing-key page; that heading only appears once one exists.
2. **`git-allowed-signers`** in this repo, so local verification works. Without
   it `git log --show-signature` reports `No principal matched` even for valid
   signatures. `bootstrap` installs it to `~/.ssh/allowed_signers`.

One key per machine means a retired machine is revoked by deleting its line from
`git-allowed-signers`, rather than rotating a key shared everywhere.

`user.signingkey` is a *path* rather than a key id, so it's identical on every
machine while the key behind it differs.

### What GPG is still for

Only verifying commits made before the switch to SSH signing. Verification needs
no passphrase, so there's no pinentry setup here — `exports` sets `GPG_TTY` and
nothing more, which is what makes gpg usable if you ever decrypt or sign
something by hand.

### SSH authentication

Separate from signing. `~/.ssh/config` sets `IdentityAgent` to the 1Password
agent, and `exports` points `SSH_AUTH_SOCK` at the same socket so `ssh-add`,
`git`, `rsync` and `mosh` see it too. That's skipped under `$SSH_CONNECTION`, so
a forwarded agent isn't clobbered.

## Packages

The `Brewfile` at the repo root is the shared set, installed on every machine by
`bootstrap`. Keep it lean.

Everything else is opt-in, as `Brewfiles/<name>.Brewfile` — language ecosystems
and topic bundles you pull in per machine, so the Mini doesn't get design tools
and the laptop doesn't get things it never needs. Install them with `brewfile`:

```sh
brewfile                    # pick interactively (fzf), then install
brewfile ls                 # list bundles and entry counts
brewfile install node go    # install by name
brewfile check node         # report what's missing
brewfile cat go             # print a bundle
```

### Language ecosystems

One tool per language rather than a polyglot version manager, since each has a
good native story now:

| Language | Bundle | Tool | Version pinning |
| --- | --- | --- | --- |
| Node | `node` | `fnm` | `.node-version`, `.nvmrc` |
| Python | `python` | `uv` | `.python-version`, `pyproject.toml` |
| Rust | `rust` | `rustup` | `rust-toolchain.toml` |
| Go | `go` | stock `go` | `go.mod` — no version manager needed |

Go needs no version manager because since Go 1.21 the default `GOTOOLCHAIN=auto`
makes the `go` command read the `go`/`toolchain` lines in `go.mod` and download
the matching toolchain on demand.

Shell integration for these is guarded on the tool being present, so a machine
that skips a bundle doesn't pay for it or error at startup.

### `Brewfiles/archive/`

Old bundles kept as notes — PHP, MySQL, nginx, WordPress, Ruby, and the previous
Node/Python setups. `brewfile` ignores this directory; use `brew bundle` directly
if you ever want something out of it:

```sh
brew bundle install --verbose --file=Brewfiles/archive/Brewfile.PHP
```

## Upgrade

To update to the latest version:

```sh
cd ~/.dotfiles
./bootstrap
```

   [xclt]: <https://developer.apple.com/downloads>
   [atuin]: <https://docs.atuin.sh/>
   [hb]: <http://brew.sh>
   [casks]: <http://caskroom.io>
   [omz]: <https://github.com/robbyrussell/oh-my-zsh>
   [ab]: <https://github.com/mattmc3/antidote>
   [abd]: <https://github.com/mattmc3/antidote?tab=readme-ov-file#usage>
   [starship]: <https://starship.rs/>
   [zx]: <https://github.com/ajeetdsouza/zoxide>
