#! /bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# parse_args: sets MODE and PACKAGE array from YAML config.
# Returns 0 on success, 1 for help, 2 for invalid arg.
parse_args() {
	if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]] || [[ -z "$1" ]]; then
		echo "Usage: stow-packages.sh [--help|-h] server|workstation|iot|lxc"
		echo "This script uses GNU Stow to symlink dotfiles from the stow-packages directory to the home directory."
		echo "Each subdirectory in stow-packages represents a package of dotfiles to be managed."
		echo "server, workstation, iot, and lxc are predefined sets of packages."
		return 1
	elif [[ "$1" == "workstation" ]] || [[ "$1" == "server" ]] || [[ "$1" == "iot" ]] || [[ "$1" == "lxc" ]]; then
		MODE="$1"
		eval "$(python3 "$SCRIPT_DIR/tools/load_config.py" --set "$MODE" --type stow)"
	else
		return 2
	fi
	return 0
}

# detect_privilege: sets PRIV_MODE based on uid.
detect_privilege() {
	if [ "$(id -u)" -eq 0 ]; then
		PRIV_MODE="root (no sudo required)"
	else
		PRIV_MODE="non-root (sudo will be used where required)"
	fi
}

# execute_stow: runs stow for every package in the PACKAGE array.
execute_stow() {
	echo "Privilege mode: $PRIV_MODE"
	echo "Stowing packages in $MODE mode..."
	for package in "${PACKAGE[@]}"; do
		echo "Stowing package: $package"
		stow -v -t ~/ --dotfiles "$package"
	done
	echo "All packages stowed successfully."
}

main() {
	parse_args "$@"
	local rc=$?
	if [ $rc -eq 1 ]; then exit 0; fi
	if [ $rc -eq 2 ]; then exit 1; fi
	detect_privilege
	execute_stow
	exit 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	main "$@"
fi
