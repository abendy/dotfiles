# REMOTE-COMMANDS(1)

## NAME

`t`, `tl`, `ta`, `tt`, `tb`, `td`, `tn`, `tk`, `mini`, `mini-ssh`,
`mini-mosh` — manage tmux sessions and connect to the Mini

## SYNOPSIS

```text
t [session]
tl
ta [session]
tt
tb
td [tmux-option ...]
tn name
tk [session]

mini [session]
mini-ssh [ssh-argument ...]
mini-mosh [mosh-argument ...]
```

## DESCRIPTION

These zsh functions provide the short path into persistent tmux work on the
Mini. The tmux helpers work on the current host. The connection helpers assume
that `nigiri` is the Mini's host entry in `~/.ssh/config`.

The functions are defined in [`functions`](functions), copied to `~/.functions`
by `bootstrap`, and loaded by interactive shells from [`zshrc`](zshrc).

Explicit session names are matched exactly. A name such as `api` never resolves
to a different session named `api-old`.

## TMUX COMMANDS

### `t [session]`

With `session`, create or attach to that exact session. Outside tmux this uses
`tmux new-session -A`; inside tmux it creates the session if necessary and
switches the current client to it.

With no session outside tmux, attach to the most recently active session. If no
sessions exist, print `t: no sessions; use: t <name>` and return an error rather
than creating an implicit default. Other session-discovery or attachment
failures preserve tmux's diagnostic and exit status.

With no session inside tmux, switch to the last session, like `cd -`. If there
is no last session, keep the current session, print `t: no last session`, and
return success.

### `tl`

List sessions. Print `no tmux sessions` when tmux has no reachable server.

### `ta [session]`

Attach to an existing exact session, or switch the current tmux client to it.

With no name, select from existing sessions using `fzf`. If `fzf` is
unavailable, list the sessions and return without attaching.

### `tt`

Create or switch to a session named after the current Git repository. Outside a
Git repository, use the current directory name.

Periods, colons, and spaces in the generated name become hyphens.

### `tb`

Create or switch to a session named after the current Git branch. In detached
HEAD state, use the short commit ID. Return an error outside a Git repository.

Slashes, periods, colons, and spaces in the generated name become hyphens.

### `td [tmux-option ...]`

Detach the current tmux client. Pass all arguments through to
`tmux detach-client`.

### `tn name`

Rename the current tmux session to `name`.

### `tk [session]`

Ask for confirmation, then kill the exact session. With no name, target the
current session. Print `tk: no session` and return an error when no current
session can be determined.

## CONNECTION COMMANDS

### `mini [session]`

Connect to the Mini with mosh and create or attach to `session` immediately.
The default is `laptop`, kept separate from the phone's automatic session.

This runs tmux as mosh's remote command. Detaching from tmux therefore ends the
mosh connection.

### `mini-ssh [ssh-argument ...]`

With no arguments, open an interactive SSH login shell without automatically
attaching tmux.

With arguments, run `ssh nigiri` and pass the arguments through unchanged. Use
this form for non-interactive commands and tunnels:

```sh
mini-ssh uptime
mini-ssh -N -L 8080:localhost:8080
```

### `mini-mosh [mosh-argument ...]`

Open a roaming mosh login shell without automatically attaching tmux. Arguments
are forwarded after the `nigiri` host argument and interpreted by `mosh(1)`.

The helper wraps `mosh-server` with
`DOTFILES_SKIP_TMUX_AUTOATTACH=1`, so the opt-out survives the SSH bootstrap
into mosh's login shell.

## AUTO-ATTACH

A plain interactive `ssh nigiri` or `mosh nigiri` login automatically opens the
Mini's `phone` session when all of these conditions are true:

- the short hostname is `nigiri-san`;
- the shell is interactive;
- standard output is a terminal;
- `SSH_CONNECTION` is set;
- `TMUX` is empty or unset;
- `CODEX_REMOTE_PAYLOAD` is empty or unset;
- `DOTFILES_SKIP_TMUX_AUTOATTACH` is empty or unset; and
- `tmux` is available.

The hook lives in [`zshrc`](zshrc). It does not replace the login shell, so
detaching from this automatically attached session returns to the underlying
remote shell.

`mini-ssh` with no arguments and `mini-mosh` set the explicit opt-out.
`mini` bypasses the hook by running tmux directly.

## ENVIRONMENT

- **`HOST`** — restricts automatic attachment to the Mini's `nigiri-san`
  hostname.
- **`SSH_CONNECTION`** — identifies an SSH- or mosh-originated login.
- **`TMUX`** — prevents automatic attachment when already inside tmux.
- **`CODEX_REMOTE_PAYLOAD`** — prevents the interactive helper from
  interfering with the Codex Desktop SSH path.
- **`DOTFILES_SKIP_TMUX_AUTOATTACH`** — explicitly disables automatic
  attachment for raw transport helpers.

## EXIT STATUS

Unless described otherwise, each helper returns the status of its final
underlying `tmux`, `ssh`, `mosh`, `git`, or `fzf` command.

`t` without a name returns `1` outside tmux when no sessions exist, but returns
success inside tmux when there is no last session to select. `tl` treats an
unavailable tmux server as an empty session list and returns success after
printing its fallback message. `tk` returns `1` when it cannot determine a
session; declining its confirmation returns success.

## FILES

- [`functions`](functions) — function implementations.
- [`zshrc`](zshrc) — interactive loading and Mini auto-attach guard.
- [`tmux.conf`](tmux.conf) — shared tmux behavior and key bindings.
- [`remote-workflow.md`](remote-workflow.md) — Tailscale, mosh, tmux, and Codex
  Desktop topology and troubleshooting.

## EXAMPLES

```sh
# Reattach the most recently active session
t

# Create or switch to an exact named session
t api

# Session for the current repository or branch
tt
tb

# Pick an existing session, then safely remove an exact old session
ta
tk old-api

# Roaming connection directly into the laptop session
mini
mini api

# Raw shells without automatic tmux attachment
mini-ssh
mini-mosh
```

## SEE ALSO

`tmux(1)`, `mosh(1)`, `ssh(1)`, `fzf(1)`, `git(1)`,
[`remote-workflow.md`](remote-workflow.md)
