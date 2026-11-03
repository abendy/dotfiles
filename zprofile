# Homebrew
if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv zsh)"
elif [ -x /usr/local/bin/brew ]; then
  eval "$(/usr/local/bin/brew shellenv zsh)"
fi

# brew shellenv prepends its bin again for login shells. Keep the managed
# Codex launcher selected here as it is in interactive and plain SSH shells.
export PATH="$HOME/bin:$PATH"
