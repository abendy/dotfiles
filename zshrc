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

# tmux auto-attach on interactive remote logins to the Mini
# Server-side replacement for a Termius startup snippet: an interactive SSH/mosh
# login to the devbox lands straight in the `phone` session, separate from the
# MacBook helper's `laptop` session. Scoped to the Mini
# by hostname (osx-devbox enforces it to `nigiri-san`), so the behavior lives in
# this tracked file and reproduces on a rebuild with no untracked ~/.localrc
# state. Other
# guards: interactive shell with terminal stdin, inside an SSH/mosh session,
# not already in tmux, and not the Codex Desktop SSH app-server path
# (CODEX_REMOTE_PAYLOAD). The raw transport helpers set
# DOTFILES_SKIP_TMUX_AUTOATTACH in the server environment.
# The Claude desktop app's Terminal panel also logs in over SSH but sets
# TERM_PROGRAM=claude-desktop and starts in the session's project directory;
# those shells get a session named after that directory instead of sharing
# `phone` (tmux rejects `.` and `:` in names, so they become `-`). The app sets
# no per-tab id, so a tab reuses a detached session started in the same
# directory (`dotfiles`, `dotfiles-2`, ...) and otherwise creates the next free
# name; two tabs never share one by default.
if [[ ${HOST%%.*} == nigiri-san && -o interactive \
      && -t 0 \
      && -n ${SSH_CONNECTION:-} && -z ${TMUX:-} \
      && -z ${CODEX_REMOTE_PAYLOAD:-} \
      && -z ${DOTFILES_SKIP_TMUX_AUTOATTACH:-} ]] \
      && command -v tmux &>/dev/null; then
  () {
    local session=phone
    if [[ $TERM_PROGRAM == claude-desktop ]]; then
      local base=${${PWD:t}//[.:]/-} attached name dir n=2
      local -A taken
      session=
      while IFS=: read -r attached name dir; do
        taken[$name]=1
        if [[ -z $session && $attached == 0 && $dir == $PWD \
              && ( $name == "$base" || $name == "$base"-<2-> ) ]]; then
          session=$name
        fi
      done < <(tmux list-sessions \
        -F '#{session_attached}:#{session_name}:#{session_path}' 2>/dev/null)
      if [[ -z $session ]]; then
        session=$base
        while (( ${+taken[$session]} )); do session=$base-$((n++)); done
      fi
    fi
    tmux new-session -A -s "${session:-phone}"
  }
fi

# Inside tmux on the Mini, warn when the server isn't the one the login agent
# (com.abendy.tmux-server) started. Such a server lives in an SSH security
# session, so its panes can't use the login keychain (codesign fails with
# errSecInternalComponent). The agent puts DOTFILES_TMUX_AQUA in the server's
# environment, so this check costs a variable test, not a subprocess.
if [[ ${HOST%%.*} == nigiri-san && -o interactive && -n ${TMUX:-} \
      && -z ${DOTFILES_TMUX_AQUA:-} ]]; then
  print -u2 "tmux: this server wasn't started from the GUI login, so the" \
    "login keychain is locked here. Fix: tmux-aqua migrate"
fi

# Outside tmux on the Mini, an SSH or mosh login can't use the login keychain
# either. Claude Code then falls back to ~/.claude/.credentials.json, and a
# /login there splits the login across two stores. Offer to unlock it once
# per login: security asks for the Mac password and nothing is stored. Agent
# and app shells have no tty, so they never see the prompt.
# DOTFILES_NO_KEYCHAIN_UNLOCK=1 turns it off.
if [[ ${HOST%%.*} == nigiri-san && -o interactive && -t 0 && -z ${TMUX:-} \
      && -z ${DOTFILES_NO_KEYCHAIN_UNLOCK:-} ]] \
   && ! security show-keychain-info > /dev/null 2>&1; then
  if read -q "?login keychain is locked in this shell. Unlock it for Claude Code and codesign? [y/N] "; then
    print
    security unlock-keychain "$HOME/Library/Keychains/login.keychain-db"
  else
    print
  fi
fi
