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
  default. Releasing the drag copies the text and clears the highlight;
  don't press Cmd-C after it, which copies the terminal's own (empty)
  selection over it.
- Copies reach the Mac's clipboard two ways: OSC 52 through the terminal,
  and SSH to the laptop's `pbcopy` (see
  [Clipboard: copy to the laptop](#clipboard-copy-to-the-laptop)).
- Install the configured TPM plugins with `prefix I` after the first
  bootstrap. Continuum checks for a save every 15 minutes while an attached
  client's status line is refreshing. With every client detached, the last
  completed snapshot stays unchanged; use `prefix Ctrl-s` before a planned
  restart or long detached period. Resurrect captures pane contents, includes
  vi and Vim by default, and uses contains-matches for Codex and Claude so
  commands launched with flags remain eligible for restoration.

On the laptop, continuum's automatic-start LaunchAgent opens iTerm2 after GUI
login. On the Mini it is off; a LaunchAgent of this repo starts the server
instead (next section).

**Resurrect needs a UTF-8 locale.** Without one, tmux prints tabs in `-F`
output as `_`, and resurrect splits its records on tabs. Its save then holds no
panes, and the next restore brings nothing back. continuum's autosave runs in
the server's environment, so the server needs `LANG`/`LC_ALL`. Shells get them
from `exports`, and the Mini's login agent sets them for its server. A server
started from a shell with no locale (launchd, cron) saves nothing.

Shorthands live in `functions` (so they work identically over SSH/mosh, which
is the point for iOS Termius): `t [name]` creates or attaches an exact named
session, while bare `t` attaches the most recently active session outside tmux
or toggles to the last session inside it. `tl` lists, `ta` attaches or
fzf-picks, `tt` uses a session per repository, `tb` uses one per branch, `td`
detaches, `tn` renames, and `tk` kills with confirmation. See
[REMOTE-COMMANDS(1)](remote-commands.md) for complete syntax and behavior.

### Keychain: start the server from the GUI login

macOS ties the login keychain to the security session a process starts in. The
tmux server and every pane it spawns keep the session of whatever started the
server, whoever attaches later. A server started by an SSH or mosh login can't
use the keychain: `security show-keychain-info` exits 36 and Xcode codesign
fails with `errSecInternalComponent`.

On the Mini, the `com.abendy.tmux-server` LaunchAgent (installed by
`bootstrap`) runs [`tmux-aqua start`](bin/tmux-aqua) at GUI login. The server
then exists before an SSH or mosh login needs one, so those logins attach to it
and their panes can use the keychain. The agent also turns `exit-empty` off, so
killing the last session doesn't hand the next login a new server.

- `tmux-aqua status` checks the running server. A shell inside a server the
  agent didn't start prints a one-line warning.
- `tmux-aqua migrate` moves a wrong server: save, stop, start from the GUI
  login, restore. See [REMOTE-COMMANDS(1)](remote-commands.md#tmux-aqua-migrate---discard).
- After a reboot there's no GUI session until someone logs in on the screen.
  An SSH login before that creates its own server, and the keychain stays
  locked whatever tmux does. Log in over Screen Sharing, then run
  `tmux-aqua migrate`.
- `launchctl managername` in a pane says `Background` even in the agent's
  server. Trust `tmux-aqua status`, which runs the keychain check itself.

### Idle terminals and sessions

The Claude desktop app runs every Terminal tab over one SSH connection, and
each tab gets a tmux session named after its folder. Tabs stay attached after
the app closes their session, and sshd allows only so many sessions per
connection. `osx-devbox` raises that to 50 (`MaxSessions`, in
`/etc/ssh/sshd_config.d/030-max-sessions.conf`), and the
`com.abendy.tmux-reap` LaunchAgent runs [`tmux-reap`](bin/tmux-reap) every 15
minutes:

| | Temporary folder | Any other folder |
| --- | --- | --- |
| Attached terminal, no typing | closed after 4 hours | closed after 24 hours |
| Session with nothing attached, idle | removed after 1 day | removed after 7 days |
| Session whose folder is gone | removed at once | — |

- Temporary folders are worktrees (`.claude/worktrees/`, `.codex/worktrees/`)
  and `/tmp`.
- Closing a terminal hangs up its login shell, which frees its SSH slot. The
  session stays, and reopening the tab reattaches.
- A session is removed only when every pane sits at a shell prompt. One
  running `claude`, a server, or anything else stays. `phone` always stays.
- `tmux-reap --dry-run` prints what it would do, and for everything it keeps,
  why and when it would go. Actions are logged to
  `~/Library/Logs/tmux-reap.log`. The timeouts are at the top of the script.

### Clipboard: copy to the laptop

A copy in tmux (mouse drag, `Enter` or `Y` in copy mode) takes two routes to
the laptop's clipboard:

1. **OSC 52**, an escape code asking the terminal to set its clipboard.
   iTerm2 accepts it when "Applications in terminal may access clipboard" is
   on (Settings → General → Selection). mosh passes it from 1.4.0 on both
   ends. Claude Code's terminal panel ignores it.
2. **SSH.** `copy-command` runs [`bin/tmux-copy`](bin/tmux-copy), which pipes
   the text to `pbcopy` on the laptop. Universal Clipboard can't stand in:
   it doesn't carry copies tmux makes.

The laptop accepts one key, only from the Mini's Tailscale address, and that
key can only run `pbcopy`. One-time setup, after `bootstrap` on both machines:

1. **Laptop:** turn on System Settings → General → Sharing → Remote Login.
   Under its ⓘ, allow only your user, and leave full disk access off.
2. **Mini:** `tmux-copy setup <laptop-user>@<laptop-tailscale-name>`. It
   creates `~/.ssh/tmux-clipboard`, records the destination in
   `~/.config/tmux-copy/destination`, and prints a `tmux-copy authorize`
   command.
3. **Laptop:** run that command. It writes
   `/etc/ssh/sshd_config.d/010-tmux-copy.conf` (keys only; this user only, from
   the Mini) and adds the key to `~/.ssh/authorized_keys` as
   `restrict,from="<Mini IP>",command="… pbcopy"`. Re-running replaces the old
   key.
4. **Mini:** `echo hello | tmux-copy`, then paste on the laptop.

Limits:

- The laptop must be awake and on Tailscale. A failed copy logs to
  `~/Library/Logs/tmux-copy.log` on the Mini; OSC 52 still works in iTerm2.
- `AllowUsers` also refuses every other SSH login to the laptop. Widen it
  there if you ever need one.
- Without the destination file (the laptop itself), `tmux-copy` runs
  `pbcopy` locally.

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
