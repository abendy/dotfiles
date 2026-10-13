# shellcheck shell=bash
#
# Shared helpers for the langs/ scripts. Sourced, not executed:
#
#   LANGS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   . "$LANGS_DIR/lib.sh"
#
# Callers may set LOCALRC before sourcing; it defaults to ~/.localrc.

LOCALRC="${LOCALRC:-$HOME/.localrc}"

function success () {
  echo -e "[ \033[00;32mOK\033[0m ] $1\n"
}

function fail () {
  echo -e "[\033[0;31mFAIL\033[0m] $1\n"
  exit 1
}

# Install a language's plain packages from its sidecar Brewfile.
#
# --no-upgrade because brew bundle otherwise upgrades anything outdated in the
# file (for mas apps, `mas upgrade`), and re-running a langs/ script must not
# upgrade as a side effect. Upgrades stay a deliberate `brew upgrade`/`mas
# upgrade`.
function brew_bundle {
  local brewfile="$1"

  echo "Installing packages from $brewfile..."
  if ! brew bundle install --no-upgrade --verbose --file="$brewfile"; then
    fail "brew bundle failed for $brewfile"
  fi
}

# Replace or append the marker-delimited block named $1 in $LOCALRC, body on
# stdin. Markers follow the localrc template's existing convention
# (`# >>> dotfiles: <name> >>>`), so the editor block bootstrap seeds and the
# blocks these scripts manage look the same. Content between the markers is
# script-owned; everything else in localrc stays machine-owned.
function localrc_put_block {
  local name="$1" body tmp
  local open_m="# >>> dotfiles: ${name} >>>"
  local close_m="# <<< dotfiles: ${name} <<<"
  body="$(cat)"

  # bootstrap seeds ~/.localrc from the repo template; a machine that hasn't
  # run it yet gets a minimal file rather than a failure
  if [ ! -f "$LOCALRC" ]; then
    printf '#!/usr/bin/env zsh\n' > "$LOCALRC"
  fi

  # An opening marker with no closing marker would make the rewrite below
  # swallow everything after it - refuse instead of guessing
  if grep -qxF "$open_m" "$LOCALRC" && ! grep -qxF "$close_m" "$LOCALRC"; then
    fail "$LOCALRC has an unterminated 'dotfiles: ${name}' block - fix it by hand"
  fi

  tmp="$(mktemp)"
  # Body travels via ENVIRON because awk -v mangles backslash escapes
  BLOCK_BODY="$body" awk -v open_m="$open_m" -v close_m="$close_m" '
    $0 == open_m && !replaced {
      print open_m
      print ENVIRON["BLOCK_BODY"]
      print close_m
      replaced = 1
      skipping = 1
      next
    }
    skipping {
      if ($0 == close_m) skipping = 0
      next
    }
    { print }
    END {
      if (!replaced) {
        print ""
        print open_m
        print ENVIRON["BLOCK_BODY"]
        print close_m
      }
    }
  ' "$LOCALRC" > "$tmp" || fail "Could not rewrite $LOCALRC"
  mv -f "$tmp" "$LOCALRC"
}
