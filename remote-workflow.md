# Working with the Mini remotely: Tailscale, mosh, tmux

Quick reference for actually using the pieces set up in `mac-mini-setup.md`,
not how they got installed.

## Tailscale — the network

Tailscale is what makes the Mini reachable at all when you're not on the
home LAN. It runs as a background daemon/menu bar app on both machines;
day to day you shouldn't need to touch it.

- Check it's connected: `tailscale status` (or the menu bar icon - green
  means connected).
- The Mini's stable address is `nigiri-san.taila71bd7.ts.net` (MagicDNS),
  works identically at home or away. `~/.ssh/config`'s `Host nigiri` entry
  already points at it.
- If the Mini drops off `tailscale status`, it's almost always the Mini
  itself asleep/off, not Tailscale - check `osx-devbox`'s sleep-prevention
  settings actually took (`pmset -g`) before assuming a Tailscale problem.
- `tailscale ping nigiri-san` is a quicker connectivity check than a full
  SSH attempt when troubleshooting.

## mosh — the resilient connection

Plain SSH drops the instant your laptop sleeps, changes wifi networks, or
loses signal for a few seconds - you'd have to reconnect and lose scrollback
of whatever wasn't in tmux. mosh keeps the *client-side* connection alive
across all of that (it's UDP-based and resyncs automatically), so closing
the laptop lid mid-session and reopening it later just picks back up.

- Connect: `mosh nigiri` (uses the same `~/.ssh/config` entry as `ssh
  nigiri` for the initial handshake, then hands off to its own UDP port).
- It's a drop-in replacement for `ssh nigiri` for interactive use - same
  shell, same environment. It is *not* a replacement for scp/rsync/tunnels;
  use plain `ssh`/`scp` for those.
- If it ever fails with "Did not find mosh server startup message," that's
  almost always the remote `mosh-server` binary not being found - already
  fixed once this session via `.zshenv` (see `mac-mini-setup.md`), but
  worth knowing if it ever resurfaces after some other PATH change.

## tmux — the persistent session

mosh keeps the *connection* alive, but if the remote shell process itself
exits (you close the terminal, the SSH/mosh session ends some other way),
whatever was running is gone. tmux keeps a session running on the Mini
itself, independent of whether anything is currently attached to it - the
actual persistence layer.

Basic loop, using this repo's `tmux.conf` (mouse on, vi copy-mode, hostname
shown in the status bar so it's obvious which machine you're in):

- Start or reattach in one step: `tmux new-session -A -s api` - creates
  `api` if it doesn't exist yet, attaches to it if it does. This is the
  one command worth actually remembering.
- Detach without killing anything: `prefix d` (prefix is tmux's default,
  `Ctrl-b`, unchanged in this config).
- List sessions from outside tmux: `tmux ls`.
- Reload `tmux.conf` without restarting the session: `prefix r` (bound in
  this config specifically).
- Scroll/select with the mouse - this config turns that on, unlike tmux's
  default.
- Install the configured TPM plugins with `prefix I` after the first
  bootstrap. Continuum checks for a save every 15 minutes while an attached
  client's status line is refreshing. With every client detached, the last
  completed snapshot stays unchanged; use `prefix Ctrl-s` before a planned
  restart or long detached period. Resurrect captures pane contents, includes
  vi and Vim by default, and uses contains-matches for Codex and Claude so
  commands launched with flags remain eligible for restoration.

On macOS, continuum's automatic-start LaunchAgent runs after GUI login and is
configured here to open iTerm2. It does not provide pre-login boot recovery. If
the first post-reboot touch is SSH or mosh, that connection can create the
`phone` or `laptop` session while continuum's asynchronous restore is starting;
resurrect will not replace a pane that already exists. Do not assume those
first-session contents were restored: check `tmux ls` and the snapshot linked
by `~/.tmux/resurrect/last`. A real Mini reboot test is still required before
treating this path as verified recovery.

Shorthands live in `functions` (so they work identically over SSH/mosh, which
is the point for iOS Termius): `t [name]` creates or attaches an exact named
session, while bare `t` attaches the most recently active session outside tmux
or toggles to the last session inside it. `tl` lists, `ta` attaches or
fzf-picks, `tt` uses a session per repository, `tb` uses one per branch, `td`
detaches, `tn` renames, and `tk` kills with confirmation. See
[REMOTE-COMMANDS(1)](remote-commands.md) for complete syntax and behavior.

## Codex Desktop SSH

Codex Desktop starts its remote app server over SSH and connects through
`codex app-server proxy`. Keep `codex` available in the remote login shell's
PATH. No manual daemon start or shell startup override is required.

The July 29 shell workaround was removed on September 18. It called a
missing `~/.local/bin/codex`, hid the failure, and still disabled normal
startup with `CODEX_SSH_SKIP_APP_SERVER_BOOT=true`. That left the connection
proxy with no server after a reboot.

Do not restore that override or start Codex servers from shell profiles.
For connection failures, inspect the MacBook's SSH startup logs and the
Mini's `~/.codex/app-server-control/app-server.log` before changing startup
behavior. A missing socket alone does not explain why startup failed.

The override removal passed shell syntax and SSH-environment checks.
MacBook reconnection and current iOS Remote Control behavior still need
end-to-end verification.

## Putting it together

The actual day-to-day command, combining all three - roams across network
changes (mosh) into a session that survives disconnects entirely (tmux),
reachable from anywhere (Tailscale):

```
mosh nigiri -- tmux new-session -A -s laptop
```

This is now wired up as `mini` (in `functions`): `mini` or `mini <session>`
does exactly the above, defaulting to the dedicated `laptop` session.
`mini-ssh` with no arguments and `mini-mosh` (also in
`functions`) open tmux-free shells. Arguments to `mini-ssh` retain plain SSH
pass-through for non-interactive commands and `-N` tunnels.

To skip typing anything at all from iOS Termius (no startup snippets on the
free tier), the Mini auto-attaches `phone` on any interactive SSH/mosh login.
It's wired in `zshrc` and scoped to the Mini by hostname (`nigiri-san`), so it
needs no per-machine setup and survives a rebuild. Guarded to fire only on
remote logins, never on the MacBook, and never for the Codex Desktop SSH path.
The raw helpers set `DOTFILES_SKIP_TMUX_AUTOATTACH` in the server environment
so their login shells bypass the hook explicitly. The Claude desktop app's Terminal
panel is the one exception to `phone`: each tab gets its own session named after
its project directory, numbered when a project has several (see
[remote-commands.md](remote-commands.md#auto-attach)).
