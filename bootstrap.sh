#!bin/bash

# Run this script first of all. It will run the others.

source ./shell.sh
if [[ "$OSTYPE" == "darwin"* ]]; then
	source ./brew.sh
fi

stow -v -t ~/ --dotfiles basic
stow -v -t ~/ --dotfiles "config resources"

zinit ice as"command" from"gh-r" bpick"atuin-*.tar.gz" mv"atuin*/atuin -> atuin" \
    atclone"./atuin init zsh > init.zsh; ./atuin gen-completions --shell zsh > _atuin" \
    atpull"%atclone" src"init.zsh"
zinit light atuinsh/atuin

ln -s ~/.config/resources/tokyonight.yml ~/.eza/theme.yml