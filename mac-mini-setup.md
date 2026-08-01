# Mac Mini setup (headless dev box)

Running log of setting up the Mac Mini as a second, always-on dev machine —
headless, accessed remotely from the MacBook Pro ~99% of the time. The
MacBook keeps the shared display; the Mini never has one attached.

## Decisions made

- **iCloud**: sign in with the same Apple ID as the MacBook (not a new
  account) - Handoff/Universal Clipboard need the same account. Then
  `System Settings → [name] → iCloud → iCloud Drive` and turn off
  **"Desktop & Documents Folders"** so nothing gets synced to/from the
  Mini. Also turn off iCloud Photos there unless you want the full photo
  library duplicated onto it.
- **Display sharing / KVM**: not needed. The Mini runs headless; the
  MacBook stays on the shared display. Access is remote (SSH/Tailscale),
  not local-display switching.
- **FileVault + automatic login**: NOT automated, and can't be. If
  FileVault is on, any reboot (OS update, power blip, crash) requires
  someone physically at the keyboard to unlock the disk before networking
  or SSH exist at all - that's inherent to full-disk encryption's pre-boot
  authentication, not a settings toggle. Decide one of:
  - Keep FileVault on and accept that a reboot needs physical presence, or
  - Weigh disabling FileVault for full remote reliability (tradeoff:
    disk contents aren't encrypted at rest).
  *(Decision pending - fill in once chosen.)*
- **Ethernet vs. Wi-Fi**: want Ethernet prioritized for reliability, but
  current networking gear placement doesn't allow running a cable to the
  Mini yet. Deferred - see TODO below.
- **Personal-data services**: kept off the Mini. Signed out of iMessage and
  cleared the local Messages store (3.3 GB, 2026-07-31) - note that
  disabling "Messages in iCloud" alone does *not* stop delivery; a
  signed-in device keeps accumulating messages, so sign-out is the real
  switch. Desktop & Documents and Photos sync already off per the iCloud
  decision above.
- **Container runtime**: colima installed (2026-07) alongside a Docker
  Desktop install that has no data on this machine (the `docker` CLI comes
  from the brew formula, not the app bundle). Which one survives is
  [#37](https://github.com/abendy/dotfiles/issues/37); disk-prune's
  `docker` target stays off until that lands.
- **Power-failure recovery**: run in "Start up when power is connected:
  Always" mode (`autorestartatconnect 1`), decided 2026-08-01. macOS 26.5
  made it and the classic `autorestart` mutually exclusive on 2024+
  minis - each write zeroes the other, and the OS re-asserts
  atconnect-mode unprompted
  ([#24](https://github.com/abendy/dotfiles/issues/24)). Start-on-connect
  boots the headless box on any mains restore, even from powered-off,
  retiring the old restart-after-power-failure model here.

## Setup steps

1. ✅ Complete macOS setup / update.
2. ✅ Sign into iCloud per the decision above; disable Desktop & Documents
   Folders sync and iCloud Photos.
3. ⬜ Decide the FileVault/auto-login tradeoff above before it matters
   (i.e. before the first remote-only reboot).
4. ✅ Run `./osx-devbox` from this repo (while still physically at the
   Mini) - disables sleep, enables wake-on-network and auto-restart after
   power failure, turns on Remote Login (SSH) and Screen Sharing.
   *(2026-08-01: the auto-restart part did not survive on macOS 26.5.2 -
   see step 13 and [#24](https://github.com/abendy/dotfiles/issues/24).)*
5. ✅ Clone this repo to `~/.dotfiles` and run `./bootstrap` to install
   Brewfile packages and copy dotfiles into place. Hit two upstream
   Homebrew breakages along the way (both fixed in the Brewfile, so a
   future machine won't hit them): `yubico-yubikey-personalization-gui`
   was removed from Homebrew entirely, and `yubico-yubikey-manager` was
   disabled/discontinued and replaced with the `yubico-authenticator`
   cask. Also corrected `Brewfile.devbox`'s cask name (`tailscale-app`,
   not `tailscale`).
6. ✅ SSH from the MacBook to the Mini over the LAN, before Tailscale:
   - Confirmed the Mini is reachable at `Nigiri-san.local` (mDNS/Bonjour
     - no manual hostname config needed) and that port 22 was already
     open from step 4.
   - Generated a dedicated key on the MacBook rather than reusing an
     existing one: `ssh-keygen -t ed25519 -f ~/.ssh/nigiri -N ""`.
   - Authorized it on the Mini (one-time, needs the account password
     interactively): `ssh-copy-id -i ~/.ssh/nigiri.pub nigiri@Nigiri-san.local`.
   - From then on: `ssh -i ~/.ssh/nigiri nigiri@Nigiri-san.local` works
     passwordless. Note for non-interactive/scripted use: a bare
     `ssh host 'cmd'` doesn't source `.zprofile`, so `brew` isn't on
     PATH unless the command exports it itself
     (`export PATH="/opt/homebrew/bin:$PATH"`).
7. ✅ Set up Tailscale and sign into the same tailnet on both machines.
   - Sign-up flow was rough (email sign-up redirected to Apple ID,
     passkey save didn't actually work for login, had to fall back to
     Apple ID sign-in; the web admin console errored a few times too) -
     but both machines ended up correctly enrolled in the same tailnet
     under one account.
   - Installed the `tailscale-app` cask on the MacBook too (it was
     mistakenly devbox-only before - moved it, and `mosh`, into the
     shared `Brewfile` instead of `other-brews/devbox.Brewfile`, since both
     need a client-side + server-side presence on *every* machine, not
     just the Mini; only `tmux` is genuinely Mini-only).
   - MagicDNS is enabled tailnet-wide, giving a stable hostname
     (`nigiri-san.taila71bd7.ts.net`) that works whether or not you're on
     the home LAN - confirmed SSH works over the LAN address, the raw
     Tailscale IP, and the MagicDNS name.
   - Updated `~/.ssh/config`'s existing `Host nigiri` entry to point at
     the MagicDNS hostname instead of `Nigiri-san.local`, so `ssh nigiri`
     / `mosh nigiri` work from anywhere, not just the home network.
8. ✅ Ran `./osx-devbox` on the Mini (needs sudo interactively, so this
   has to be run by hand) - Remote Login was already on, Screen Sharing/
   ARD activated cleanly.
9. ✅ Added `~/.zshenv` (new dotfile, copied by `bootstrap` alongside the
   others) - `.zprofile`/`.zshrc` are never sourced for non-interactive,
   non-login shell invocations, which broke two things until this was in
   place: a bare `ssh host 'cmd'` couldn't find `brew`-installed tools,
   and mosh's remote `mosh-server` launch failed the same way. `.zshenv`
   is the one zsh startup file sourced unconditionally, so it's now the
   only place Homebrew's PATH setup *has* to work.
10. ✅ Added `tmux.conf` (mouse on, 256-color, vi copy-mode, hostname in
    the status bar, large scrollback) - copied by `bootstrap` the same
    way as the Hammerspoon/iTerm2 configs.
11. ✅ Adopted GUI apps into brew cask management (2026-07-31):
    `brew install --cask --adopt claude chatgpt`, both added to the
    `Brewfile`. Rationale: Squirrel/Sparkle updaters download in the
    background but wait for a click to install, and nobody clicks on a
    headless box - updates now ride `brew upgrade --greedy` over SSH.
    Google Chrome followed on 2026-08-01 (`google-chrome` cask, adopted) -
    kept on the Mini for Computer Use.
12. ✅ Installed [disk-prune](disk-prune/README.md) (2026-07-31): monthly
    scheduled cache pruning (Homebrew, npm, Brave, Codex) with a menu bar
    app and dry-run CLI. Built and installed by `bootstrap`; targets
    toggle in `~/.config/disk-prune/config.json`.
13. ⬜ Power-failure recovery, macOS 26.5 edition (2026-08-01,
    [#24](https://github.com/abendy/dotfiles/issues/24)): `pmset -g`
    showed `autorestart 0` despite step 4, with `./osx-devbox` having
    run twice *on* 26.5.2 (Jul 25 22:39, Jul 28 22:20). Live re-testing
    explained it: on 26.5.2 the classic `autorestart` and the new
    `autorestartatconnect` ("Start up when power is connected", Energy
    pane, 2024+ Mac minis) are *mutually exclusive* - setting
    `autorestart 1` by hand flipped `autorestartatconnect` 1→0 on this
    box, and the unexplained Jul 29 14:17 "revert" was the same
    mechanism in the other direction, the OS re-asserting
    atconnect-mode. Decision above: run in atconnect mode ("Always");
    `osx-devbox` now asserts that and no longer touches `autorestart`
    (it reading 0 is expected). Remaining, needs interactive sudo,
    then a restart:
    - `sudo pmset autorestartatconnect 1` (no profile flag; expect
      `autorestart` to drop to 0 - that's the exclusivity), confirm
      with `pmset -g custom`
    - after the next deliberate restart (doubles as
      [#45](https://github.com/abendy/dotfiles/issues/45)'s recovery
      test), confirm `autorestartatconnect` still reads `1`, then
      close out #24's autorestart item

## TODO

- Prioritize Ethernet over Wi-Fi on the Mini once networking gear can be
  physically repositioned (`System Settings → Network → ••• → Set Service
  Order…`).
- Decide and record the FileVault/auto-login tradeoff above.
- Apply atconnect mode and verify it survives a reboot (step 13,
  [#24](https://github.com/abendy/dotfiles/issues/24)); the restart
  doubles as the remote-recovery test for
  [#45](https://github.com/abendy/dotfiles/issues/45).
- Consider enabling Tailscale SSH (`tailscale set --ssh`) and/or writing
  Tailscale ACLs to formally gate which devices can reach the Mini,
  rather than relying on OpenSSH key possession alone.
- Auto-converge the deployed clone (`~/.dotfiles` lags the working repo)
  and schedule `brew upgrade --greedy` -
  [#39](https://github.com/abendy/dotfiles/issues/39).
- Resolve [#37](https://github.com/abendy/dotfiles/issues/37) (Docker
  Desktop vs colima), remove the loser, and flip disk-prune's `docker`
  target to `"prune"`.
