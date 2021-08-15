# James's dotfiles
(a working in progress based on [Mathias's dotfiles](https://github.com/mathiasbynens/dotfiles))

## New Mac Setup
1. `xcode-select --install` (make sure Xcode CLI tools are installed)
1. `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"` (install Homebrew)
1. `source brew.sh`
1. `source shells.sh` (authorizes and points user shell to `/usr/local/bin/zsh` copy from Homebrew)
1. `source gems.sh` (requires `sudo` privileges)
1. `source bootstrap.sh`

## Linux Setup
1. `cd ~ && mkdir Dev && cd Dev`
2. `git clone https://github.com/jamesbeldock/dotfiles.git && cd dotfiles && source bootstrap.sh`
