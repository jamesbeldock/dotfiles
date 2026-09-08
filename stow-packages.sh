#! /bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/tools/discover_sets.sh"
source "$SCRIPT_DIR/tools/stow_conflicts.sh"

# parse_args: sets MODE and PACKAGE array from YAML config.
# Returns 0 on success, 1 for help/list, 2 for invalid arg.
parse_args() {
	if [[ "$1" == "--list" ]]; then
		discover_sets "$SCRIPT_DIR" || return 2
		echo "Available sets: ${AVAILABLE_SETS[*]}"
		return 1
	fi

	if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]] || [[ -z "$1" ]]; then
		discover_sets "$SCRIPT_DIR" || return 2
		echo "Usage: stow-packages.sh [--help|-h|--list] <set>"
		echo "This script uses GNU Stow to symlink dotfiles from the stow-packages directory to the home directory."
		echo "Each subdirectory in stow-packages represents a package of dotfiles to be managed."
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
	eval "$(python3 "$SCRIPT_DIR/tools/load_config.py" --set "$MODE" --type stow)"
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
# Files already sitting at a target are diffed and resolved one at a time by
# stow_package rather than aborting the package. Continues past a failing
# package so one problem does not hide the rest, then reports every failure.
# Returns 1 if any package failed or the user quit.
execute_stow() {
	echo "Privilege mode: $PRIV_MODE"
	echo "Stowing packages in $MODE mode..."
	FAILED_PACKAGES=()
	local rc
	for package in "${PACKAGE[@]}"; do
		echo "Stowing package: $package"
		stow_package "$SCRIPT_DIR" "$HOME" "$package" && rc=0 || rc=$?
		if [ $rc -eq 2 ]; then
			echo "Aborted at your request; ${#FAILED_PACKAGES[@]} package(s) had failed so far." >&2
			return 1
		fi
		if [ $rc -ne 0 ]; then
			FAILED_PACKAGES+=("$package")
		fi
	done
	if [ ${#FAILED_PACKAGES[@]} -gt 0 ]; then
		echo "Failed to stow ${#FAILED_PACKAGES[@]} of ${#PACKAGE[@]} package(s): ${FAILED_PACKAGES[*]}" >&2
		echo "Fix the problems reported above, then re-run." >&2
		return 1
	fi
	echo "All packages stowed successfully."
	return 0
}

main() {
	parse_args "$@"
	local rc=$?
	if [ $rc -eq 1 ]; then exit 0; fi
	if [ $rc -eq 2 ]; then exit 1; fi
	detect_privilege
	execute_stow || exit 1
	exit 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	main "$@"
fi
