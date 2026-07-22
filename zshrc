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

# oh my zsh
ZSH=$HOME/.oh-my-zsh
ZSH_THEME="sunaku"
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

# z
if [ -d "$(brew --prefix)/opt/z" ]; then
  . "$(brew --prefix)/etc/profile.d/z.sh"
fi

# zsh-completions
if type brew &>/dev/null; then
  FPATH=$(brew --prefix)/share/zsh-completions:$FPATH
  autoload -Uz compinit
  compinit
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
