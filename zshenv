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

# Keep fnm's default Node available to non-interactive consumers such as MCP
# servers. Interactive shells still use `fnm env --use-on-cd` from zshrc for
# per-project .node-version and .nvmrc switching.
if [ -d "$HOME/.local/share/fnm/aliases/default/bin" ]; then
  export PATH="$HOME/.local/share/fnm/aliases/default/bin:$PATH"
fi
