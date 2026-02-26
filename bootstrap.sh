#! /bin/bash

# set -x	# debugging on
# pwd

# Run this script first of all. It will run the others.

# parse_args: sets MODE. Returns 0 on success, 1 for help, 2 for invalid arg.
parse_args() {
	if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]] || [[ -z "$1" ]]; then
		echo "Usage: bootstrap.sh [--help|-h] server|workstation|iot"
		echo "This script bootstraps a new machine by installing packages and stowing dotfiles."
		echo "server, workstation, and iot are predefined sets of packages."
		return 1
	elif [[ "$1" = "server" ]] || [[ "$1" == "workstation" ]] || [[ "$1" == "iot" ]]; then
		MODE="$1"
		return 0
	else
		echo "Invalid option: $1"
		echo "Usage: bootstrap.sh [--help|-h] server|workstation|iot"
		return 2
	fi
}

# detect_os: sets OS_TYPE to "darwin" or "linux". Returns 1 if unknown.
detect_os() {
	if [[ "$OSTYPE" == "darwin"* ]]; then
		OS_TYPE="darwin"
	elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
		OS_TYPE="linux"
	else
		echo "Unsupported OS: $OSTYPE"
		return 1
	fi
	return 0
}

# execute_bootstrap: runs child scripts and post-install tasks.
execute_bootstrap() {
	# source ./shell.sh #TODO: fix this for Linux
	if [[ "$OS_TYPE" == "darwin" ]]; then
		bash ./osx-package-install.sh "$MODE"
	elif [[ "$OS_TYPE" == "linux" ]]; then
		bash ./linux-apt-package-install.sh "$MODE"
	fi

	bash ./stow-packages.sh "$MODE"

	#atuin installation and stow package
	zinit ice as"command" from"gh-r" bpick"atuin-*.tar.gz" mv"atuin*/atuin -> atuin" \
		atclone"./atuin init zsh > init.zsh; ./atuin gen-completions --shell zsh > _atuin" \
		atpull"%atclone" src"init.zsh"
	zinit light atuinsh/atuin
	stow -v -t ~/ --dotfiles atuin

	# install eza theme
	ln -s ~/.config/resources/tokyonight.yml ~/.eza/theme.yml

	# set up TPM (tmux plugin manager)
	git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
	git clone https://github.com/2KAbhishek/tmux2k.git ~/.tmux/plugins/tmux2k
}

main() {
	parse_args "$@"
	local rc=$?
	if [ $rc -eq 1 ]; then exit 0; fi
	if [ $rc -eq 2 ]; then exit 1; fi
	detect_os || exit 1
	execute_bootstrap
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	main "$@"
fi
