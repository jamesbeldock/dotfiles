#! /bin/bash

if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]] || [[ -z "$1" ]]; then
	echo "Usage: stow-packages.sh [--help|-h] server|workstation|iot|lxc"
	echo "This script uses GNU Stow to symlink dotfiles from the stow-packages directory to the home directory."
	echo "Each subdirectory in stow-packages represents a package of dotfiles to be managed."
	echo "server, workstation, and iot are predefined sets of packages."
	exit 0
elif [[ "$1" == "workstation" ]]; then
	MODE="workstation"
	PACKAGE=(
		"basic"
		"config resources"
		"fastfetch"
		"git"
		"iterm2"
		"nvim"
		"oh-my-zsh"
		"starship"
		"tmux"
		"wezterm"
		"zsh"
	)
elif [[ "$1" == "server" ]]; then
	MODE="server"
	PACKAGE=(
		"basic"
		"config resources"
		"fastfetch"
		"git"
		"nvim"
		"tmux"
		"starship"
		"zsh"
	)
elif [[ "$1" == "iot" ]]; then
	MODE="iot"
	PACKAGE=(
		"basic"
		"config resources"
		"fastfetch"
		"nvim"
		"tmux"
		"zsh"
	)
elif [[ "$1" == "lxc" ]]; then
	MODE="lxc"
	PACKAGE=(
		"basic"
		"config resources"
		"fastfetch"
		"nvim"
		"tmux"
		"zsh"
	)
else
	exit 1
fi

# Detect privilege level
if [ "$(id -u)" -eq 0 ]; then
	PRIV_MODE="root (no sudo required)"
else
	PRIV_MODE="non-root (sudo will be used where required)"
fi

echo "Privilege mode: $PRIV_MODE"
echo "Stowing packages in $MODE mode..."

for package in "${PACKAGE[@]}"; do
	echo "Stowing package: $package"
	stow -v -t ~/ --dotfiles "$package"
done
echo "All packages stowed successfully."

exit 0
