# James's dotfiles
(a work in progress based on [Mathias's dotfiles](https://github.com/mathiasbynens/dotfiles))

## New Mac Setup
1. `xcode-select --install` (make sure Xcode CLI tools are installed)
1. `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"` (install Homebrew)
2. `brew install gh` github tools
3. `mkdir ~/dev` place for these and other projects
4. `gh auth login` go through auth process
5. `gh repo clone jamesbeldock/dotfiles`
6. `source dotfiles/brew.sh`
7. `source dotfiles/shells.sh` (authorizes and points user shell to `/usr/local/bin/zsh` copy from Homebrew)
8. `source dotfiles/gems.sh` (requires `sudo` privileges)
9. `source dotfiles/bootstrap.sh`

## Linux Setup
1. `cd ~ && mkdir Dev && cd Dev`
2. `git clone https://github.com/jamesbeldock/dotfiles.git && cd dotfiles && source bootstrap.sh`
