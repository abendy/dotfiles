# Path to your oh-my-zsh configuration.
ZSH=$HOME/.oh-my-zsh

# Set name of the theme to load.
ZSH_THEME="sunaku"

# antidote
[ -f /usr/local/opt/antidote/share/antidote/antidote.zsh ] && source /usr/local/opt/antidote/share/antidote/antidote.zsh
[ -f $HOME/.zsh_plugins.sh ] && antidote load $HOME/.zsh_plugins.sh
[ -f $HOME/.zsh_plugins_locals.sh ] && antidote load $HOME/.zsh_plugins_locals.sh

source $ZSH/oh-my-zsh.sh

# fzf-z
[ -f $HOME/.dotfiles/zsh/fzf-z.plugin.zsh ] && source $HOME/.dotfiles/zsh/fzf-z.plugin.zsh

# grc
if hash grc &> /dev/null; then
  source "`brew --prefix`/etc/grc.bashrc"
fi

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

# iterm2 shell integration
if [ -f "${HOME}/.iterm2_shell_integration.zsh" ]; then
  test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"
fi

# z
if [ -d "$(brew --prefix)/opt/z" ]; then
  . `brew --prefix`/etc/profile.d/z.sh
fi

# zsh-completions
fpath=(/usr/local/share/zsh-completions $fpath)
fpath=(/usr/local/share/zsh/site-functions $fpath)
fpath=(~/.zsh/completion $fpath)

# https://docs.brew.sh/Shell-Completion#configuring-completions-in-zsh
if type brew &>/dev/null; then
  FPATH=$(brew --prefix)/share/zsh/site-functions:$FPATH

  autoload -Uz compinit
  compinit
fi

# zsh-syntax-highlighting
source /usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# zsh-history-substring-search
# must be behind `zsh-syntax-highlighting`
# https://github.com/zsh-users/zsh-history-substring-search
source /usr/local/opt/zsh-history-substring-search/share/zsh-history-substring-search/zsh-history-substring-search.zsh

# Load the shell dotfiles, and then some:
for file in ~/.{exports,aliases,functions,input,localrc}; do
  [ -r "$file" ] && [ -f "$file" ] && source "$file"
done
unset file
