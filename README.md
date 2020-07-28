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

We're using [antibody][ab] as the plugin manager. Add plugins (one per line) as per [antibody documentation][abd].

```sh
vi ~/.zshplugins
antibody bundle < ~/.zsh_plugins.txt > ~/.zsh_plugins.sh
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
   [ab]: <https://getantibody.github.io/>
   [abd]: <https://getantibody.github.io/usage/>
