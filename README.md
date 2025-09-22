# James's dotfiles

(a work in progress based on [Mathias's dotfiles](https://github.com/mathiasbynens/dotfiles))

## New Mac Setup

1. `xcode-select --install` (make sure Xcode CLI tools are installed)
1. `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"` (install Homebrew)
1. `brew install gh` github tools
1. `mkdir ~/dev` place for these and other projects
1. `gh auth login` go through auth process
1. `gh repo clone jamesbeldock/dotfiles`
1. `source dotfiles/brew.sh`
1. `source dotfiles/shells.sh` (authorizes and points user shell to `/usr/local/bin/zsh` copy from Homebrew)
1. `source dotfiles/gems.sh` (requires `sudo` privileges)
1. `source dotfiles/bootstrap.sh`

## Linux Setup

1. `cd ~ && mkdir code && cd code`
1. install Git and command line: `sudo apt install git gh`
1. grab the repo: `git clone https://github.com/jamesbeldock/dotfiles.git`
1. start it up: `cd dotfiles && source bootstrap.sh
