export PATH="/opt/homebrew/bin:$PATH" # use homebrew-installed binaries first
export HOMEBREW_NO_ENV_HINTS=1


# start in tmux if it's installed, in interactive terminal, and not already inside tmux
if command -v tmux &> /dev/null && [ -n "$PS1" ] && [[ ! "$TERM" =~ screen ]] && [[ ! "$TERM" =~ tmux ]] && [ -z "$TMUX" ]; then
  exec tmux
fi

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"


# zstyle ':omz:update' mode disabled  # disable automatic updates
zstyle ':omz:update' mode auto      # update automatically without asking

zstyle ':omz:update' frequency 7

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

ENABLE_CORRECTION="true".

plugins=(z git docker docker-compose extract sudo colored-man-pages fzf)

source $ZSH/oh-my-zsh.sh

# User configuration

export LANG=en_US.UTF-8

# Compilation flags
# export ARCHFLAGS="-arch $(uname -m)"


### Added by Zinit's installer
if [[ ! -f $HOME/.local/share/zinit/zinit.git/zinit.zsh ]]; then
    print -P "%F{33} %F{220}Installing %F{33}ZDHARMA-CONTINUUM%F{220} Initiative Plugin Manager (%F{33}zdharma-continuum/zinit%F{220})…%f"
    command mkdir -p "$HOME/.local/share/zinit" && command chmod g-rwX "$HOME/.local/share/zinit"
    command git clone https://github.com/zdharma-continuum/zinit "$HOME/.local/share/zinit/zinit.git" && \
        print -P "%F{33} %F{34}Installation successful.%f%b" || \
        print -P "%F{160} The clone has failed.%f%b"
fi

source "$HOME/.local/share/zinit/zinit.git/zinit.zsh"
autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit
### End of Zinit's installer chunk
zinit ice depth"1"
zinit light zsh-users/zsh-autosuggestions
zinit light zsh-users/zsh-syntax-highlighting
zinit ice depth"1"
zinit light agpenton/1password-zsh-plugin
zinit ice depth"1"
zinit light junegunn/fzf
zinit ice blockf
zinit light zsh-users/zsh-completions


export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
export PATH="$(brew --prefix coreutils)/libexec/gnubin:$PATH"
export PATH="$PATH:/opt/homebrew/sbin"

source "$HOME/.aliases"
source "$HOME/.exports"
source "$HOME/.functions"

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

export PATH="/opt/homebrew/bin:/opt/homebrew/bin/bash:/opt/homebrew/opt/ruby/bin:$PATH"

# atuin
eval "$(atuin init zsh)"

# iterm2 shell integration, with tmux support (see https://gitlab.com/gnachman/iterm2/-/wikis/tmux-Integration-Best-Practices)
export ITERM_ENABLE_SHELL_INTEGRATION_WITH_TMUX=YES
test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"

eval "$(starship init zsh)"

fastfetch

# Added by Antigravity
export PATH="/Users/j/.antigravity/antigravity/bin:$PATH"
