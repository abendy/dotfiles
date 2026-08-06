# disk-prune

Scheduled cleaning for a small-disk (256 GB) Mac. A disk audit (2026-07-31)
found ~10 GB of recurring cache accumulation; this reclaims it monthly
instead of by hand.

The cleaning engine is **[mole][mole]** (`brew "mole"`, in the Brewfile) -
actively maintained, community-curated target list, and it already does the
right things (`brew cleanup --prune=30`, `npm cache clean --force`, an
app-protection layer, per-operation timeouts, its own logs and JSON history).
disk-prune deliberately owns **no deletion logic**; it layers on what mole
doesn't have:

- **Scheduling** - a LaunchAgent runs `disk-prune run` monthly (1st, 12:00)
- **Run report + notification** - a summary line per run in
  `~/Library/Logs/disk-prune.log` and a macOS notification with the freed
  total (mole's own detailed logs live in `~/Library/Logs/mole/`)
- **Policy** - mole's whitelist is tracked here
  ([config/mole-whitelist.template](config/mole-whitelist.template)) and
  installed to `~/.config/mole/whitelist`; it keeps `mo clean` away from the
  Trash
- **The docker gate** - mole only *reports* Docker storage; pruning it is
  ours, off until [issue #37][37]
- **A watch list** - paths reported but never pruned
- **A menu bar app** - at-a-glance prunable space and a Prune Now item

One Swift package, two executables sharing `DiskPruneCore`, so the number
the menu bar shows and the number the scheduled run frees always agree:

- `disk-prune` - CLI; what launchd runs
- `disk-prune-menubar` - menu bar frontend (internal-drive icon), refreshes
  every 6 h

## Usage

```
disk-prune            # mole's cleanup preview + watch list; deletes nothing
disk-prune run        # mo clean (and docker, if enabled), log, notify
disk-prune help
```

## Config

`~/.config/disk-prune/config.json` - two knobs; everything else is mole's
whitelist:

```json
{
  "notify": true,
  "docker": "off"
}
```

`docker` stays `"off"` until [issue #37][37] (Docker Desktop vs colima) is
resolved - flip it to `"prune"` once a runtime is chosen; the target talks
to plain `docker`, so it follows whichever daemon answers. (On the mini the
audit points at colima: Docker Desktop holds 404 KB there and the CLI is the
brew formula.)

## The whitelist is the policy file

`mo clean` cleans everything it knows about *except* whitelisted paths, so
protection - not target selection - is where decisions live. The tracked
template currently protects:

- **`~/.Trash`** - user data. mole would otherwise empty it entirely;
  Finder's "Remove items after 30 days" owns it instead (enabled in the
  `osx` script), and disk-prune reports its size.

`install.sh` overwrites `~/.config/mole/whitelist` from the template: edit
policy in the repo, not in place.

## Watch list (reported, never pruned)

- **Chrome on-device AI models** (`OptGuideOnDeviceModel` +
  `optimization_guide_model_store` under App Support) - 4 GB on the audit,
  cleared by hand; this surfaces a re-download
- **Trash** - see above
- **node_modules under `~/projects`** - project-owned; genuinely abandoned
  artifacts are `mo purge` territory

## Safety

disk-prune's own code deletes nothing - every removal happens inside mole
(whitelist-guarded, app-protection layer, sudo-gated system paths skipped
when unattended) or, once enabled, `docker system prune`. Sizing for the
watch list uses `/usr/bin/du` by absolute path - the interactive `du` alias
that breaks `du -s` ([issue #38][38]) can't leak into `Process` anyway, but
the absolute path makes it explicit.

Unattended runs are user-level only: mole asks for sudo for system caches
and there is none under launchd, so those are skipped rather than prompted
for.

## Install

```
./install.sh
```

Builds release binaries into `~/bin`, installs the config if missing
(migrating the pre-mole schema if found), installs the mole whitelist, and
(re)loads both LaunchAgents. `bootstrap` calls this during dotfiles install.
Needs the Xcode Command Line Tools (Swift 6) and `mole` (Brewfile).

`launchctl bootstrap` right after a `bootout` of a running agent can race
launchd's teardown and fail with EIO; the installer retries a few times
rather than failing the whole install.

## Out of scope, on purpose

Known space consumers this tool deliberately ignores:

- **Aerial wallpaper downloads** (`~/Library/Application Support/com.apple.wallpaper`,
  ~2.2 GB on the audit) - managed by the OS; prune via System Settings >
  Wallpaper, not scriptable in any supported way. (mole cleans the wallpaper
  *agent cache*, which is separate.)
- **Messages** (~3.3 GB) - a live message store, i.e. user data.
- **Electron updater caches** (`*.ShipIt`) - checked on the audit, 0 B.

## Phase 2 ideas: a smarter Trash story

Chosen for now: Finder's built-in 30-day auto-empty plus the whitelist entry
keeping mole out. Ideas considered and parked:

- **`rm` alias that trashes instead.** Alias/function `rm` to move arguments
  into the Trash (e.g. the `trash` CLI, `brew install trash`, which uses the
  proper Finder API so Put Back works) instead of unlinking. Safety win, but
  it retrains muscle memory on a lie - `rm` on any other machine is still
  `rm` - and scripts calling `rm -rf` must not inherit it, so it needs an
  interactive-only guard.
- **Custom Trash emptier.** Delete only items trashed more than 30 days ago,
  reading per-item dates from `kMDItemDateAdded`
  (`mdls -name kMDItemDateAdded ~/.Trash/*`). More control than Finder's
  all-or-nothing setting (e.g. "keep anything over 1 GB for 90 days"), but
  it deletes user data on a timer, wants Full Disk Access from launchd, and
  duplicates something the OS already does - so it waits until the built-in
  behavior actually falls short.

[mole]: https://github.com/tw93/Mole
[37]: https://github.com/abendy/dotfiles/issues/37
[38]: https://github.com/abendy/dotfiles/issues/38
