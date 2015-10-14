#!/usr/bin/env bash

# Install command-line tools using Homebrew.

# Ask for the administrator password upfront.
sudo -v

# Keep-alive: update existing `sudo` time stamp until the script has finished.
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

# Make sure we’re using the latest Homebrew.
update

# Required for brews below
tap homebrew/dupes
tap homebrew/versions
tap homebrew/completions

install autojump
install awscli
install cfv
# Install GNU core utilities (those that come with OS X are outdated)
install coreutils
install cronolog
install curl
install dos2unix
install drush
install fasd
# Install GNU `find`, `locate`, `updatedb`, and `xargs`, `g`-prefixed
install findutils
install foremost
install fpp
install fzf
install gawk
install gist
install git
install git-extras
# Install GNU `sed`, overwriting the built-in `sed`.
install gnu-sed --with-default-names
install gnu-tar
install grc
install grep
install html-xml-utils
install httpie --HEAD
install lynx
# Install some other useful utilities like `sponge`
install moreutils
install newsbeuter
install openssl
install pigz
install progress
install rename
install rsync
install s3cmd
install speedtest_cli
install the_silver_searcher
install ssh-copy-id
install stormssh
install thefuck
install tree
install vagrant-completion
install watch
# Install wget with IRI support
install wget --with-iri
install ykclient
install yubikey-personalization
install z
install zopfli
install zsh
install zsh-completions
install zsh-history-substring-search
install zsh-syntax-highlighting
install zsh-lovers

# Remove outdated versions from the cellar
cleanup
