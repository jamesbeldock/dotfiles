#! /bin/bash

# set -x	# debugging on
# pwd

# Run this script first of all. It will run the others.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/tools/discover_sets.sh"
source "$SCRIPT_DIR/tools/stow_conflicts.sh"

# parse_args: sets MODE. Returns 0 on success, 1 for help/list, 2 for invalid arg.
parse_args() {
	if [[ "$1" == "--list" ]]; then
		discover_sets "$SCRIPT_DIR" || return 2
		echo "Available sets: ${AVAILABLE_SETS[*]}"
		return 1
	fi

	if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]] || [[ -z "$1" ]]; then
		discover_sets "$SCRIPT_DIR" || return 2
		echo "Usage: bootstrap.sh [--help|-h|--list] <set>"
		echo "This script bootstraps a new machine by installing packages and stowing dotfiles."
		echo "Available sets: ${AVAILABLE_SETS[*]}"
		return 1
	fi

	discover_sets "$SCRIPT_DIR" || return 2

	if ! is_valid_set "$1"; then
		echo "Invalid option: $1"
		echo "Available sets: ${AVAILABLE_SETS[*]}"
		return 2
	fi

	if ! validate_configs "$SCRIPT_DIR"; then
		echo "Config validation failed. Aborting." >&2
		return 2
	fi

	MODE="$1"
	return 0
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

# link_eza_theme: points ~/.eza/theme.yml at the stowed tokyonight theme.
# The theme arrives with the "config resources" package, and ~/.eza does not
# exist on a new machine, so both the directory and a re-run have to be handled.
link_eza_theme() {
	local theme="$HOME/.config/resources/tokyonight.yml"
	if [ ! -f "$theme" ]; then
		echo "Skipping eza theme: $theme not found (is 'config resources' stowed?)" >&2
		return 1
	fi
	mkdir -p "$HOME/.eza"
	ln -sfn "$theme" "$HOME/.eza/theme.yml"
	echo "Linked eza theme: $HOME/.eza/theme.yml -> $theme"
}

# clone_if_missing: git clone unless the destination is already there.
# Args: $1 = repository URL, $2 = destination directory
# A plain `git clone` fails on any re-run, which is what made bootstrap noisy
# the second time through.
clone_if_missing() {
	local url="$1" dest="$2"
	if [ -d "$dest" ]; then
		echo "Already present, skipping clone: $dest"
		return 0
	fi
	mkdir -p "$(dirname "$dest")"
	git clone "$url" "$dest"
}

# execute_bootstrap: runs child scripts and post-install tasks.
# Returns 1 if package installation failed.
execute_bootstrap() {
	# source ./shell.sh #TODO: fix this for Linux
	local rc=0
	if [[ "$OS_TYPE" == "darwin" ]]; then
		bash ./osx-package-install.sh "$MODE" || rc=$?
	elif [[ "$OS_TYPE" == "linux" ]]; then
		bash ./linux-apt-package-install.sh "$MODE" || rc=$?
	fi

	# Stowing needs the packages that step installs — stow itself, above all.
	# Carrying on regardless produced one "stow: command not found" per package
	# and buried the real error hundreds of lines up.
	if [ $rc -ne 0 ]; then
		echo "Package installation failed (exit $rc). Stopping before stow." >&2
		echo "Nothing has been symlinked; fix the errors above and re-run." >&2
		return 1
	fi

	bash ./stow-packages.sh "$MODE"

	# atuin's config lives in a stow package that no set lists, so link it here.
	# The binary itself comes from the james_tools/lxc_tools brew formulae, and
	# .zshrc runs `atuin init zsh` at startup — there used to be a `zinit`
	# invocation here that installed a second copy from GitHub releases, but
	# zinit is a zsh function and this script runs under bash, so it never once
	# executed.
	stow_require && stow_package "$SCRIPT_DIR" "$HOME" atuin

	link_eza_theme
	clone_if_missing https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
	clone_if_missing https://github.com/2KAbhishek/tmux2k.git "$HOME/.tmux/plugins/tmux2k"
}

main() {
	parse_args "$@"
	local rc=$?
	if [ $rc -eq 1 ]; then exit 0; fi
	if [ $rc -eq 2 ]; then exit 1; fi
	detect_os || exit 1
	execute_bootstrap || exit 1
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	main "$@"
fi
