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

- Start or reattach in one step: `tmux new-session -A -s main` - creates
  `main` if it doesn't exist yet, attaches to it if it does. This is the
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

## Codex Desktop SSH alongside ChatGPT Remote Control

The MacBook can open Mini-hosted projects through Codex Desktop's SSH
connection without taking the Mini offline in ChatGPT Remote. This was
verified on 2026-07-29, including quitting and relaunching ChatGPT on the
Mini: iOS went offline when the app quit and came back when it relaunched.

The working arrangement deliberately has two app servers with different
jobs:

- Mini ChatGPT owns its bundled, stdio app server and is the only process
  that enables ChatGPT Remote Control.
- A managed standalone app-server daemon owns
  `~/.codex/app-server-control/app-server-control.sock`, with
  `remoteControlEnabled` set to `false`.
- MacBook Codex Desktop connects over SSH, starts `codex app-server proxy`,
  and talks to that Unix socket. A proxy exists only while the SSH
  connection is active.

### What was going wrong

Codex Desktop's SSH bootstrap normally launches a second ad-hoc process:

```
codex -c features.code_mode_host=true app-server --listen unix://
```

That process read the Mini's empty-client Remote enrollment and also tried
to become the Remote app server. The service rejected the loser with HTTP
409 and `Remote app server already online`. ChatGPT translated that into
the misleading UI message `Please ensure only one instance of ChatGPT is
running`; there was only one GUI process.

The same bootstrap could leave its non-interactive SSH channel open for
about a minute because the background app server inherited stdin. That was
the cause of the long `Connecting...` delay seen during this investigation.

`CODEX_SSH_SKIP_APP_SERVER_BOOT=true` skips only that ad-hoc bootstrap.
Desktop still runs `codex app-server proxy`, so the variable is useful only
when the control socket is already owned by a managed daemon. It cannot
attach to ChatGPT's bundled app server because that server uses stdio and
does not expose the SSH control socket.

### Current fix

The daemon was bootstrapped once with Remote disabled:

```
codex app-server daemon bootstrap
```

The SSH-only hook in `zprofile` now starts it idempotently before Codex
Desktop's bootstrap and exports the skip variable:

```
if [[ -n ${SSH_CONNECTION:-} && ${CODEX_REMOTE_PAYLOAD:-} == *"app-server"* ]]; then
  "$HOME/.local/bin/codex" app-server daemon start >/dev/null 2>&1
  export CODEX_SSH_SKIP_APP_SERVER_BOOT=true
fi
```

The `CODEX_REMOTE_PAYLOAD` guard keeps this out of normal SSH, mosh, Git,
and interactive shell sessions. The empty-client enrollment scope was
disabled with a one-row SQLite update after a timestamped backup; the
`Codex Desktop` enrollment remains enabled. The backup is at
`~/.codex/backups/ssh-remote-stabilization-20260729-141310/`.

### Future checks

Check the daemon, socket, process layout, and enrollment scopes without
changing anything:

```
codex app-server daemon version
ls -l ~/.codex/app-server-control/app-server-control.sock
pgrep -alf 'codex.*(app-server|pid-update-loop)'
sqlite3 ~/.codex/state_5.sqlite \
  "SELECT quote(app_server_client_name), remote_control_enabled
   FROM remote_control_enrollments ORDER BY app_server_client_name;"
```

Expected enrollment rows are `''|0` and `'Codex Desktop'|1`. Expected
long-lived processes are ChatGPT's bundled app server, the standalone
`app-server --listen unix://`, and its `pid-update-loop`; `app-server proxy`
appears while the MacBook is connected. There should not be an additional
ad-hoc `codex -c features.code_mode_host=true app-server --listen unix://`.

Useful logs are:

- `~/.codex/app-server-daemon/app-server.stderr.log`
- `~/.codex/app-server-daemon/app-server-updater.stderr.log`
- `~/.codex/app-server-control/app-server.log`
- `~/.codex/logs_2.sqlite` for ChatGPT and Remote Control events

If the desktop SSH path misbehaves, first turn off its SSH connection on
the MacBook and inspect the PIDs. Terminate only an unexpected ad-hoc
socket app server; do not use the old broad `pkill` recipe because the
managed socket daemon is now intentional. `codex app-server daemon restart`
is the narrow recovery for the managed daemon. Leave ChatGPT's bundled
app-server, Remote pairings, installation IDs, and the state database
alone unless fresh evidence identifies one of them as the fault.

### Related upstream issues

No issue found on 2026-07-29 describes this exact two-Mac combination and
the misleading singleton error. These are the closest upstream reports:

- [#23699 — Codex Desktop SSH restart disables mobile remote control](https://github.com/openai/codex/issues/23699)
  covers Desktop SSH replacing a Remote-capable app server with a plain
  socket app server.
- [#20636 — SSH remote bootstrap silently fails on macOS-to-macOS](https://github.com/openai/codex/issues/20636)
  covers the brittle background bootstrap and missing socket readiness
  checks.
- [#23527 — Codex mobile does not show SSH remote projects](https://github.com/openai/codex/issues/23527)
  covers the related distinction between Desktop SSH projects and mobile
  Remote visibility.
- [#28862 — Remote-control 409 stale enrollment needs a repair path](https://github.com/openai/codex/issues/28862)
  is a related 409-conflict report and argues for a supported ownership
  repair mechanism.

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
so their login shells bypass the hook explicitly.
