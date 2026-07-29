# Homebrew
if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv zsh)"
elif [ -x /usr/local/bin/brew ]; then
  eval "$(/usr/local/bin/brew shellenv zsh)"
fi

# Codex Desktop SSH attaches to the managed app-server daemon on this host.
# Start it idempotently so the first connection after a reboot also works.
if [[ -n ${SSH_CONNECTION:-} && ${CODEX_REMOTE_PAYLOAD:-} == *"app-server"* ]]; then
  "$HOME/.local/bin/codex" app-server daemon start >/dev/null 2>&1
  export CODEX_SSH_SKIP_APP_SERVER_BOOT=true
fi
