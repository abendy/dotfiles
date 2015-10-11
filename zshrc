# Path to your oh-my-zsh configuration.
ZSH=$HOME/.oh-my-zsh

# Set name of the theme to load.
# Look in ~/.oh-my-zsh/themes/
# Optionally, if you set this to "random", it'll load a random theme each
# time that oh-my-zsh is loaded.
ZSH_THEME="sunaku"

# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
plugins=(autojump fasd gem httpie history osx pyenv sudo )

source $ZSH/oh-my-zsh.sh

#grc
source "`brew --prefix`/etc/grc.bashrc"

# nvm
source $(brew --prefix nvm)/nvm.sh
[[ -r $NVM_DIR/bash_completion ]] && . $NVM_DIR/bash_completion

# pyenv
if which pyenv > /dev/null; then eval "$(pyenv init -)"; fi
if which pyenv-virtualenv-init > /dev/null; then eval "$(pyenv virtualenv-init -)"; fi

# rbenv
if which rbenv > /dev/null; then eval "$(rbenv init -)"; fi

# z
. `brew --prefix`/etc/profile.d/z.sh

# zsh-completions
fpath=(/usr/local/share/zsh-completions $fpath)
fpath=(/usr/local/share/zsh/site-functions $fpath)
fpath=(~/.zsh/completion $fpath)

# zsh-syntax-highlighting
source /usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# zsh-history-substring-search
# must be behind `zsh-syntax-highlighting`
# https://github.com/zsh-users/zsh-history-substring-search
source /usr/local/Cellar/zsh-history-substring-search/1.0.0/zsh-history-substring-search.zsh

# Load the shell dotfiles, and then some:
for file in ~/.{aliases,exports,functions,inputrc,localrc}; do
  [ -r "$file" ] && [ -f "$file" ] && source "$file"
done
unset file
