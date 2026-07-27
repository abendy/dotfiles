# homebrew
if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv zsh)"
elif [ -x /usr/local/bin/brew ]; then
  eval "$(/usr/local/bin/brew shellenv zsh)"
fi

# antidote
# .zsh_plugins.sh and .zsh_plugins_locals.sh are pre-bundled by `antidote
# bundle` (see bootstrap / README) into plain source-able zsh, not a
# plugin list, so they're sourced directly rather than passed to `antidote
# load` (which expects the author/repo list format instead)
source "$(brew --prefix)/opt/antidote/share/antidote/antidote.zsh"
[ -f $HOME/.zsh_plugins.sh ] && source $HOME/.zsh_plugins.sh
[ -f $HOME/.zsh_plugins_locals.sh ] && source $HOME/.zsh_plugins_locals.sh

# zsh-completions
# FPATH has to be extended *before* oh-my-zsh is sourced, because oh-my-zsh
# runs the one and only `compinit` for this shell - anything added to FPATH
# after that point is invisible to the completion system
if type brew &>/dev/null; then
  FPATH=$(brew --prefix)/share/zsh-completions:$FPATH
fi

# oh my zsh
# oh-my-zsh.sh runs `autoload -Uz compinit` + `compinit` itself, so nothing
# else in this file may run a second one. It used to (below the `z` block),
# which made `compinit` run twice and `compaudit` four times on every shell
# for no benefit - the second run only existed to pick up the FPATH entry
# now set above it
ZSH=$HOME/.oh-my-zsh
# Starship owns the prompt; Oh My Zsh remains for its shell framework and
# plugins, but must not install a competing theme.
ZSH_THEME=""
source $ZSH/oh-my-zsh.sh

# fzf-z
[ -f $HOME/.dotfiles/zsh/fzf-z.plugin.zsh ] && source $HOME/.dotfiles/zsh/fzf-z.plugin.zsh

# history
HISTSIZE=1000000   # Number of commands to keep in memory
SAVEHIST=1000000   # Number of commands to save in history file

setopt APPEND_HISTORY         # Append to history instead of overwriting
setopt INC_APPEND_HISTORY     # Add commands as they're typed, not at shell exit
setopt EXTENDED_HISTORY       # Save timestamp and duration information
setopt HIST_IGNORE_DUPS       # Don't save immediate duplicates
setopt HIST_IGNORE_SPACE      # Don't save commands that start with space
setopt HIST_VERIFY            # Don't execute expanded history immediately
setopt SHARE_HISTORY          # Share history between sessions

# zoxide (replaces `z`)
# Still provides a `z` command, plus `zi` for interactive selection, so the
# muscle memory carries over. Must stay below oh-my-zsh: `zoxide init` calls
# `compdef`, which only exists once oh-my-zsh has run `compinit`.
if type zoxide &>/dev/null; then
  eval "$(zoxide init zsh)"
fi

# fnm (replaces nvm)
# Guarded on the binary being present, because Node is an opt-in bundle
# (`brewfile install node`) rather than part of the shared Brewfile - a machine
# that skips it should not error at startup.
#
# This lives here, tracked, rather than in the untracked ~/.localrc where the
# nvm equivalent used to sit - that made the Node setup unreproducible on any
# new machine. --use-on-cd installs a chpwd hook that reads .node-version and
# .nvmrc, which is the part nvm was spending ~300ms per shell doing eagerly.
if type fnm &>/dev/null; then
  eval "$(fnm env --use-on-cd --shell zsh)"
fi

# zsh-syntax-highlighting
source "$(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"

# zsh-history-substring-search
# must be behind `zsh-syntax-highlighting`
# https://github.com/zsh-users/zsh-history-substring-search
source "$(brew --prefix)/share/zsh-history-substring-search/zsh-history-substring-search.zsh"

# Load the shell dotfiles, and then some:
for file in ~/.{exports,aliases,functions,input,localrc}; do
  [ -r "$file" ] && [ -f "$file" ] && source "$file"
done
unset file

# atuin
# Keep this after every other shell integration: fzf's startup hooks also bind
# Ctrl-R and would otherwise replace Atuin's global-history search. Preserve the
# normal Up-arrow behavior, and leave Atuin AI out of the shell integration.
# Account/session/key material lives outside this repo under Atuin's data dir.
if type atuin &>/dev/null; then
  eval "$(atuin init zsh --disable-up-arrow --disable-ai)"
fi

# starship
# Initialize after every other shell integration so it owns the final prompt
# without replacing Oh My Zsh or any of its plugins.
if type starship &>/dev/null; then
  eval "$(starship init zsh)"
fi
