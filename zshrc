# Path to your oh-my-zsh configuration.
ZSH=$HOME/.oh-my-zsh

# Set name of the theme to load.
# Look in ~/.oh-my-zsh/themes/
# Optionally, if you set this to "random", it'll load a random theme each
# time that oh-my-zsh is loaded.
ZSH_THEME="sunaku"

# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# https://github.com/robbyrussell/oh-my-zsh/wiki/Plugins
plugins=(
  brew        # `brews`
  copyfile    # `copyfile <file>`
  dircycle    # Cycle directory history with Ctrl+Shift+Left/Right
  dirpersist
  docker
  extract     # `extract`
  gitfast
  history     # `h`
  npm
  pip
  pyenv
  pylint
  python
  sudo        # ESC x2 for sudo!
  vscode      # https://github.com/robbyrussell/oh-my-zsh/wiki/Plugins#vscode
  yarn
)

source $ZSH/oh-my-zsh.sh

# thefuck
if hash fuck &> /dev/null; then
  eval "$(thefuck --alias)"
fi

# fzf
[ -f $HOME/.fzf.zsh ] && source ~/.fzf.zsh

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
