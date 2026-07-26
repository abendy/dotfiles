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

`~/.localrc` holds local runtime configuration and is not tracked by this repo. `bootstrap` copies the `localrc` template there for you if the file doesn't already exist, so an existing one is never overwritten. To seed it by hand: `cp localrc ~/.localrc`.

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
| `ctrl + r` | reverse-search history | fzf |
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

## GPG signing

`gitconfig` sets `gpgsign = true`, so commits fail outright if gpg-agent can't
run a usable pinentry. Homebrew's default `pinentry` is the curses build, which
needs a controlling terminal and dies with `Inappropriate ioctl for device`
anywhere it doesn't have one.

`bootstrap` points gpg-agent at `bin/pinentry-auto`, which picks per session:

| Session | pinentry | Why |
| --- | --- | --- |
| Local | `pinentry-mac` (gpg-suite) | GUI prompt, Keychain integration |
| SSH / mosh | `pinentry-curses` | A GUI dialog would open on the *remote* machine's display |

gpg-agent is a daemon and doesn't inherit `SSH_CONNECTION`, so the wrapper can't
detect a remote session itself. `exports` sets `PINENTRY_USER_DATA=USE_CURSES=1`
when `$SSH_CONNECTION` is present, which gpg-agent forwards to the pinentry
process. `exports` also sets `GPG_TTY`, which curses pinentry needs to attach.

The `pinentry-program` line is written into a delimited block in
`~/.gnupg/gpg-agent.conf`, so re-running `bootstrap` won't duplicate it and any
other settings in that file are left alone. To apply changes by hand:

```sh
gpgconf --kill gpg-agent   # agent caches its config at startup
```

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
   [hb]: <http://brew.sh>
   [casks]: <http://caskroom.io>
   [omz]: <https://github.com/robbyrussell/oh-my-zsh>
   [ab]: <https://github.com/mattmc3/antidote>
   [abd]: <https://github.com/mattmc3/antidote?tab=readme-ov-file#usage>
   [zx]: <https://github.com/ajeetdsouza/zoxide>
