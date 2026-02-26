#! /bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ensure_brew: checks for brew, installs if missing, runs update/upgrade.
ensure_brew() {
	if ! command -v brew &>/dev/null; then
		echo "Homebrew is not installed. Installing Homebrew..."
		/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	fi

	# Make sure we're using the latest Homebrew.
	brew update

	# Upgrade any already-installed formulae.
	brew upgrade

	# Save Homebrew's installed location.
	BREW_PREFIX=$(brew --prefix)
}

# parse_args: sets MODE, FORMULAE_TO_INSTALL, CASKS_TO_INSTALL from YAML config.
# Returns 0 on success, 1 for help, 2 for invalid arg, 3 for iot early exit.
parse_args() {
	if [ "$1" = "--help" ] || [ "$1" = "-h" ] || [ -z "$1" ]; then
		echo "Usage: osx-package-install.sh [--help|-h] server|workstation|iot"
		echo "  iot:         Core utils, Basic tools, and James's tools"
		echo "  server:      IoT + Network/Security tools + General utilities"
		echo "  workstation: Server + Fonts + Cask apps"
		return 1
	elif [ "$1" = "iot" ]; then
		echo "IoT profile is not applicable on macOS. Skipping package installation."
		return 3
	elif [ "$1" = "server" ] || [ "$1" = "workstation" ]; then
		MODE="$1"
		eval "$(python3 "$SCRIPT_DIR/tools/load_config.py" --set "$MODE" --platform macos --type formulae)"
		eval "$(python3 "$SCRIPT_DIR/tools/load_config.py" --set "$MODE" --platform macos --type casks)"
	else
		echo "Invalid option: $1"
		return 2
	fi
	return 0
}

# execute_install: installs formulae and casks, then post-install steps.
execute_install() {
	echo "Installing packages for $MODE mode..."

	for package in "${FORMULAE_TO_INSTALL[@]}"; do
		if ! brew list --formula | grep -q "^$package$"; then
			brew install "$package"
		else
			echo "$package is already installed."
		fi
	done

	for cask in "${CASKS_TO_INSTALL[@]}"; do
		if ! brew list --cask | grep -q "^$cask$"; then
			brew install --cask "$cask"
		else
			echo "$cask is already installed."
		fi
	done

	# Create symlink for sha256sum
	if [ ! -L "${BREW_PREFIX}/bin/sha256sum" ]; then
		ln -s "${BREW_PREFIX}/bin/gsha256sum" "${BREW_PREFIX}/bin/sha256sum"
	fi

	# Switch to using brew-installed zsh as default shell
	if ! fgrep -q "${BREW_PREFIX}/bin/zsh" /etc/shells; then
		echo "${BREW_PREFIX}/bin/zsh" | sudo tee -a /etc/shells
		chsh -s "${BREW_PREFIX}/bin/zsh"
	fi

	echo 'export PATH="/opt/homebrew/opt/ruby/bin:$PATH"' >>~/.zshrc

	# Remove outdated versions from the cellar.
	brew cleanup
}

main() {
	parse_args "$@"
	local rc=$?
	if [ $rc -eq 1 ]; then exit 0; fi
	if [ $rc -eq 2 ]; then exit 1; fi
	if [ $rc -eq 3 ]; then exit 0; fi
	ensure_brew
	execute_install
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	main "$@"
fi
