# .zshenv is sourced for every zsh invocation, interactive or not - unlike
# .zprofile/.zshrc, which non-interactive/non-login contexts (a bare
# `ssh host 'cmd'`, mosh launching mosh-server on the remote end) never
# source. Without this, those contexts can't find any Homebrew-installed
# binary at all.
if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv zsh)"
elif [ -x /usr/local/bin/brew ]; then
  eval "$(/usr/local/bin/brew shellenv zsh)"
fi
