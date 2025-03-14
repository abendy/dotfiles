# dotfiles

Includes:

* [Xcode Command Line Tools][xclt]
* [Homebrew][hb]
* Brews and [Casks][casks]
* [Oh My Zsh][omz]

```sh
git clone https://github.com/abendy/dotfiles.git ~/.dotfiles && cd ~/.dotfiles
./bootstrap
./osx
```

You can create a `~/.localrc` file for additional local runtime configuration. This repo provides a template: `cp localrc ~/.localrc`.

## Adding ZSH plugins

We're using [antidote][ab] as the plugin manager. Add plugins (one per line) as per [antidote documentation][abd].

```sh
touch ~/.zsh_plugins_local.txt
vi ~/.zsh_plugins_local.txt
antidote bundle < ~/.zsh_plugins_local.txt > ~/.zsh_plugin_locals.sh
exec zsh
```

## Handling a `Brewfile`

Check if all dependencies are installed in a Brewfile.

```sh
brew bundle check --verbose --file=Brewfiles/<Brewfile>
```

Install or upgrade all dependencies in a Brewfile.

```sh
brew bundle install --verbose --file=Brewfiles/<Brewfile>
```

List all dependencies present in a Brewfile, optionally limiting by types. You can do this if you do not want to install all dependencies, then copy a dependency and install it manually.

```sh
brew bundle list [--all|--brews|--casks|--taps|--mas] --file=Brewfiles/<Brewfile>
```

## Upgrade

To update to the latest version:

```sh
cd ~/.dotfiles
./bootstrap
```

   [xclt]: <https://developer.apple.com/downloads>
   [hb]: <http://brew.sh>
   [casks]: <http://caskroom.io>
   [omz]: <https://github.com/robbyrussell/oh-my-zsh>
   [ab]: <https://github.com/mattmc3/antidote>
   [abd]: <https://github.com/mattmc3/antidote?tab=readme-ov-file#usage>
