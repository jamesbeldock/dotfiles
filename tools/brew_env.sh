#!/bin/bash
# tools/brew_env.sh - Put an installed Homebrew on PATH for the current shell.
# Source this file from scripts: source "$SCRIPT_DIR/tools/brew_env.sh"
#
# Every script that needs brew has to do this for itself. A child process
# cannot export PATH back to its parent, so when bootstrap.sh runs
# `bash ./osx-package-install.sh`, the PATH that child sets up dies with it —
# and the next child, `bash ./stow-packages.sh`, cannot see the stow that was
# just installed.

# brew_shellenv: makes brew (and everything it has installed) callable here.
# Args: candidate brew paths. Defaults to the Apple Silicon, Intel and
#       Linuxbrew prefixes, and short-circuits if brew already works.
# Returns 0 if brew is now available, 1 if no candidate was found.
brew_shellenv() {
	local candidates=("$@")

	if [ ${#candidates[@]} -eq 0 ]; then
		if command -v brew >/dev/null 2>&1; then
			return 0
		fi
		candidates=(
			/opt/homebrew/bin/brew
			/usr/local/bin/brew
			/home/linuxbrew/.linuxbrew/bin/brew
		)
	fi

	local candidate
	for candidate in "${candidates[@]}"; do
		if [ -x "$candidate" ]; then
			eval "$("$candidate" shellenv)"
			return 0
		fi
	done
	return 1
}
