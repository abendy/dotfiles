#!/usr/bin/env bash

# Build and install disk-prune:
#   - release binaries (CLI + menu bar app) into ~/bin
#   - default config into ~/.config/disk-prune (kept if already present)
#   - LaunchAgents: monthly prune + menu bar app at login (started now)
#
# Idempotent - safe to re-run from bootstrap or by hand after editing the
# Swift sources.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v swift > /dev/null; then
  echo "disk-prune: swift not found - install the Xcode Command Line Tools first" >&2
  exit 1
fi

echo "Building disk-prune (release)..."
(cd "$here" && swift build -c release)
build_dir="$(cd "$here" && swift build -c release --show-bin-path)"

mkdir -p "$HOME/bin"
install -m 755 "$build_dir/disk-prune" "$HOME/bin/disk-prune"
install -m 755 "$build_dir/disk-prune-menubar" "$HOME/bin/disk-prune-menubar"
echo "Installed disk-prune and disk-prune-menubar to ~/bin"

config_dir="$HOME/.config/disk-prune"
mkdir -p "$config_dir"
if [ ! -f "$config_dir/config.json" ]; then
  cp "$here/config/config.json" "$config_dir/config.json"
  echo "Installed default config to $config_dir/config.json"
else
  echo "Keeping existing config at $config_dir/config.json"
fi

agents_dir="$HOME/Library/LaunchAgents"
mkdir -p "$agents_dir"
uid="$(id -u)"
for label in com.abendy.disk-prune com.abendy.disk-prune-menubar; do
  plist="$agents_dir/$label.plist"
  sed "s|__HOME__|$HOME|g" "$here/launchd/$label.plist.template" > "$plist"
  # bootout first so re-installs pick up plist changes; ignore "not loaded"
  launchctl bootout "gui/$uid/$label" 2> /dev/null || true
  # bootstrap races the teardown of an instance that was just booted out and
  # fails with EIO ("Bootstrap failed: 5"), so give launchd a few tries
  loaded=""
  for _ in 1 2 3 4 5; do
    if launchctl bootstrap "gui/$uid" "$plist" 2> /dev/null; then
      loaded=1
      break
    fi
    sleep 1
  done
  if [ -z "$loaded" ]; then
    echo "disk-prune: failed to load $label" >&2
    exit 1
  fi
done
echo "Loaded LaunchAgents: monthly prune (1st, 12:00) and menu bar app"

echo "disk-prune installed. Try: disk-prune dry-run"
