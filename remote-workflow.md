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

## Putting it together

The actual day-to-day command, combining all three - roams across network
changes (mosh) into a session that survives disconnects entirely (tmux),
reachable from anywhere (Tailscale):

```
mosh nigiri -- tmux new-session -A -s main
```

Worth adding as an alias (e.g. `alias mini='mosh nigiri -- tmux new-session -A -s main'`
in `aliases`) if this ends up being the 99%-of-the-time entry point - not
added yet, just flagging it as the natural next step.
