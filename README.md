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

### Handling a `Brewfile`

Check if all dependencies are installed in a Brewfile.

```sh
brew bundle check --verbose --file=Brewfiles/<file>
```

Install or upgrade all dependencies in a Brewfile.

```sh
brew bundle install --verbose --file=Brewfiles/<file>
```

List all dependencies present in a Brewfile, optionally limiting by types. You can do this if you do not want to install all dependencies, then copy a dependency and install it manually.

```sh
brew bundle list [--all|--brews|--casks|--taps|--mas] --file=Brewfiles/
```


### Upgrade

To update to the latest version:

```sh
cd ~/.dotfiles
./bootstrap
```

   [xclt]: <https://developer.apple.com/downloads>
   [hb]: <http://brew.sh>
   [casks]: <http://caskroom.io>
   [omz]: <https://github.com/robbyrussell/oh-my-zsh>
