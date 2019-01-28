# Path to your oh-my-zsh configuration.
ZSH=$HOME/.oh-my-zsh

# Set name of the theme to load.
# Look in ~/.oh-my-zsh/themes/
# Optionally, if you set this to "random", it'll load a random theme each
# time that oh-my-zsh is loaded.
ZSH_THEME="sunaku"

# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
plugins=(
  brew        # https://github.com/robbyrussell/oh-my-zsh/wiki/Plugins#brew
  copyfile    # https://github.com/robbyrussell/oh-my-zsh/wiki/Plugins#copyfile
  dircycle    # https://github.com/robbyrussell/oh-my-zsh/wiki/Plugins#dircycle
  # dirhistory  # https://github.com/robbyrussell/oh-my-zsh/wiki/Plugins#dirhistory
  dirpersist  # https://github.com/robbyrussell/oh-my-zsh/wiki/Plugins#dirpersist
  docker      # https://github.com/robbyrussell/oh-my-zsh/wiki/Plugins#docker
  extract     # https://github.com/robbyrussell/oh-my-zsh/wiki/Plugins#extract
  gitfast     # https://github.com/robbyrussell/oh-my-zsh/wiki/Plugins#gitfast
  history     # https://github.com/robbyrussell/oh-my-zsh/wiki/Plugins#history
  npm         # https://github.com/robbyrussell/oh-my-zsh/wiki/Plugins#npm
  pip         # https://github.com/robbyrussell/oh-my-zsh/wiki/Plugins#pip
  pyenv       # https://github.com/robbyrussell/oh-my-zsh/wiki/Plugins#pyenv
  pylint      # https://github.com/robbyrussell/oh-my-zsh/wiki/Plugins#pylint
  python      # https://github.com/robbyrussell/oh-my-zsh/wiki/Plugins#python
  sudo        # https://github.com/robbyrussell/oh-my-zsh/wiki/Plugins#sudo
  vscode      # https://github.com/robbyrussell/oh-my-zsh/wiki/Plugins#vscode
  yarn        # https://github.com/robbyrussell/oh-my-zsh/wiki/Plugins#yarn
)

source $ZSH/oh-my-zsh.sh

# thefuck
if hash fuck &> /dev/null; then
  eval "$(thefuck --alias)"
fi

# grc
if hash grc &> /dev/null; then
  source "`brew --prefix`/etc/grc.bashrc"
fi

# iterm2 shell integration
if [ -f "${HOME}/.iterm2_shell_integration.zsh" ]; then
  test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"
fi

# zsh-completions
fpath=(/usr/local/share/zsh-completions $fpath)
fpath=(/usr/local/share/zsh/site-functions $fpath)
fpath=(~/.zsh/completion $fpath)

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
