# Path to your oh-my-zsh configuration.
ZSH=$HOME/.oh-my-zsh

# Set name of the theme to load.
ZSH_THEME="sunaku"

[ -f $HOME/.zsh_plugins.sh ] && source $HOME/.zsh_plugins.sh
source $ZSH/oh-my-zsh.sh

# fzf-z
[ -f $HOME/.dotfiles/zsh/fzf-z.plugin.zsh ] && source $HOME/.dotfiles/zsh/fzf-z.plugin.zsh

# grc
if hash grc &> /dev/null; then
  source "`brew --prefix`/etc/grc.bashrc"
fi

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
for file in ~/.{exports,aliases,functions,inputrc,localrc}; do
  [ -r "$file" ] && [ -f "$file" ] && source "$file"
done
unset file
