# disk-prune

Scheduled cache pruning for a small-disk (256 GB) Mac. A disk audit (2026-07-31) found
~10 GB of recurring accumulation in caches and package-manager artifacts;
this reclaims it monthly instead of by hand.

One Swift package, two executables sharing `DiskPruneCore`, so the number the
menu bar shows and the number the scheduled run frees always agree:

- `disk-prune` - CLI. `dry-run` measures and prints what a run would free;
  `run` prunes, logs, and posts a notification. This is what launchd runs.
- `disk-prune-menubar` - menu bar app (internal-drive icon). Shows prunable
  space per target, refreshes every 6 h, and has a Prune Now item.

## Usage

```
disk-prune            # dry run: per-target reclaimable space, deletes nothing
disk-prune run        # prune enabled targets, log, notify
disk-prune help
```

## Targets

| id             | what                                                        | default  |
| -------------- | ----------------------------------------------------------- | -------- |
| `brew`         | `~/Library/Caches/Homebrew` via `brew cleanup --prune=all -s` | prune  |
| `npm`          | `~/.npm` via `npm cache clean --force`                      | prune    |
| `brave`        | `~/Library/Caches/{com.brave.Browser,BraveSoftware}`        | prune    |
| `codex`        | `~/Library/Caches/com.openai.codex` + `~/.cache/codex-runtimes` | prune |
| `docker`       | `docker system prune -af` in whichever runtime survives     | **off**  |
| `chrome_ai`    | Chrome's on-device AI model dirs under App Support, size only | report |
| `trash`        | `~/.Trash` size only                                        | report   |
| `node_modules` | `node_modules` dirs under `~/projects`, size only           | report   |

`docker` stays **off** until [issue #37][37] (Docker Desktop vs colima) is
resolved - flip it to `"prune"` in the config once a runtime is chosen; the
target talks to plain `docker`, so it follows whichever daemon answers. (On
the mini, the 2026-07-31 audit points at colima: Docker Desktop holds 404 KB
there and the CLI is the brew formula.)

`chrome_ai`, `trash`, and `node_modules` are report-only *in code* - setting
them to `"prune"` in the config downgrades back to report. The Trash is user
data (Finder's own "Remove items after 30 days" does the emptying - enabled
by the `osx` script); node_modules belongs to its project and deleting it
just forces a reinstall; Chrome's model dirs (4 GB on the audit, cleared by
hand that day) sit under `Application Support`, outside the deletion
allowlist, so the tool watches for Chrome re-downloading them and leaves any
deleting to a human.

## Config

`~/.config/disk-prune/config.json`, installed from [config/config.json](config/config.json)
on first install and never overwritten after that:

```json
{
  "notify": true,
  "targets": { "brew": "prune", "docker": "off", "trash": "report", ... }
}
```

Modes: `"prune"` | `"report"` | `"off"`. Targets missing from the file keep
their shipped defaults; a malformed file falls back to defaults entirely (and
says so in the log) rather than guessing.

## Schedule, logs, reports

- LaunchAgent `com.abendy.disk-prune` runs `disk-prune run` at 12:00 on the
  1st of each month. Missed while asleep → runs on wake; missed while powered
  off → skipped until next month.
- LaunchAgent `com.abendy.disk-prune-menubar` starts the menu bar app at
  login (quitting it keeps it quit until next login).
- Run reports append to `~/Library/Logs/disk-prune.log`; launchd stdout/stderr
  goes to `~/Library/Logs/disk-prune*.launchd.log`. A macOS notification with
  the freed total posts after each run (`"notify": false` disables it).

## Safety

Deletion goes through one chokepoint (`Disk.clearContents`) that refuses any
path not under `~/Library/Caches/`, `~/.cache/`, or `~/.npm/` after symlink
resolution, and deletes directory *contents*, never the directory itself.
Documents, Messages, Photos, and project sources are structurally out of
reach, not just unconfigured. External commands (`brew`, `npm`, `docker`)
only ever run their own cleanup subcommands.

Sizing uses `/usr/bin/du` by absolute path - the interactive `du` alias that
breaks `du -s` ([issue #38][38]) can't leak into `Process` anyway, but the
absolute path makes it explicit.

## Install

```
./install.sh
```

Builds release binaries into `~/bin`, installs the config if missing, and
(re)loads both LaunchAgents. `bootstrap` calls this during dotfiles install.
Needs the Xcode Command Line Tools (Swift 6).

## Out of scope, on purpose

Known space consumers this tool deliberately ignores:

- **Aerial wallpaper downloads** (`~/Library/Application Support/com.apple.wallpaper`,
  ~2.2 GB on the audit) - managed by the OS; prune via System Settings >
  Wallpaper, not scriptable in any supported way.
- **Messages** (~3.3 GB) - a live message store, i.e. user data; structurally
  unreachable behind the deletion allowlist by design.
- **Electron updater caches** (`*.ShipIt`) - checked on the audit, 0 B; not
  worth a target unless that changes.

## Phase 2 ideas: a smarter Trash story

Chosen for now: Finder's built-in 30-day auto-empty
(`defaults write com.apple.finder FXRemoveOldTrashItems -bool true`, in the
`osx` script) plus report-only visibility here. Ideas considered and parked:

- **`rm` alias that trashes instead.** Alias/function `rm` to move arguments
  into the Trash (e.g. the `trash` CLI, `brew install trash`, which uses the
  proper Finder API so Put Back works) instead of unlinking. Safety win, but
  it retrains muscle memory on a lie - `rm` on any other machine is still
  `rm` - and scripts calling `rm -rf` must not inherit it, so it needs an
  interactive-only guard.
- **Custom Trash emptier.** A `trash` target that deletes only items trashed
  more than 30 days ago, reading per-item dates from `kMDItemDateAdded`
  (`mdls -name kMDItemDateAdded ~/.Trash/*`). More control than Finder's
  all-or-nothing setting (e.g. "keep anything over 1 GB for 90 days"), but
  it deletes user data on a timer, wants Full Disk Access from launchd, and
  duplicates something the OS already does - so it waits until the built-in
  behavior actually falls short.

[37]: https://github.com/abendy/dotfiles/issues/37
[38]: https://github.com/abendy/dotfiles/issues/38
