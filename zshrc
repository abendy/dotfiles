# Path to your oh-my-zsh configuration.
ZSH=$HOME/.oh-my-zsh

# Set name of the theme to load.
# Look in ~/.oh-my-zsh/themes/
# Optionally, if you set this to "random", it'll load a random theme each
# time that oh-my-zsh is loaded.
ZSH_THEME="sunaku"

# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
plugins=(docker per-directory-history sudo vagrant)

source $ZSH/oh-my-zsh.sh

# thefuck
if hash fuck &> /dev/null; then
  eval "$(thefuck --alias)"
fi

#grc
if hash grc &> /dev/null; then
  source "`brew --prefix`/etc/grc.bashrc"
fi

# z
if hash z &> /dev/null; then
. `brew --prefix`/etc/profile.d/z.sh
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
source /usr/local/Cellar/zsh-history-substring-search/1.0.0/zsh-history-substring-search.zsh

# Load the shell dotfiles, and then some:
for file in ~/.{aliases,exports,functions,inputrc,localrc}; do
  [ -r "$file" ] && [ -f "$file" ] && source "$file"
done
unset file
