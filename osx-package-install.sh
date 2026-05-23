#! /bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/tools/discover_sets.sh"
# Install GNU core utilities (those that come with macOS are outdated).
# Don't forget to add `$(brew --prefix coreutils)/libexec/gnubin` to `$PATH`.
GNU_CORE_UTILS=(
	"coreutils"
	"moreutils" # Install some other useful utilities like `sponge`
	"findutils" # Install GNU `find`, `locate`, `updatedb`, and `xargs`, `g`-prefixed
	"bash"      # Install a modern version of Bash
	"bash-completion2"
	"wget"
	"gnu-sed"
	"stow"
)

# Install more recent versions of some macOS tools.
BASIC_TOOLS=(
	"grep"
	"openssh"
	"screen"
	"php"
	"gmp"
	"vim"
	"gnupg"
)

# Network and security tools
NETWORK_SECURITY_TOOLS=(
	"dns2tcp"
	"knock"
	"netpbm"
	"nmap"
	"pngcheck"
	"socat"
	"sqlmap"
	"tcptrace"
	"xpdf"
	"xz"
)

# Install other useful binaries.
GENERAL_UTILITIES=(
	"ack"
	"git"
	"git-lfs"
	"gs"
	"lua"
	"lynx"
	"p7zip"
	"pigz"
	"pv"
	"rename"
	"rlwrap"
	"ssh-copy-id"
	"tree"
	"vbindiff"
	"zopfli"
)

# James's preferred tools
JAMES_TOOLS=(
    "starship"
    "bat"
    "zsh"
    "fzf"
    "luarocks"
    "gh"
    "pandoc"
    "ripgrep"
    "tmux"
    "mosh"
    "atuin"
    "eza"
    "fd"
    "python3"
    "neovim"
    "broot"
    "bottom"
    "git-delta"
    "uv"
    "thefuck"
    "mtr"
    "htop"
    "tpm"
    "yazi"
    "stow"
    "ruby"
    "tldr"
    "fastfetch"
    "trash"
)

# Font installations
NERD_FONTS=(
	"font-jetbrains-mono-nerd-font"
	"font-fira-code-nerd-font"
)

# Cask applications
CASK_APPS=(
    "iterm2"
    "wezterm"
    "visual-studio-code"
    "alfred"
    "spotify"
    "docker"
    "cmake"
    "vimr"
    "itsycal"
    "dash"
    "1password"
    "1password-cli"
	"flux-app"
)

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
# Returns 0 on success, 1 for help/list, 2 for invalid arg, 3 for platform skip.
parse_args() {
	if [ "$1" = "--list" ]; then
		discover_sets "$SCRIPT_DIR" || return 2
		echo "Available sets: ${AVAILABLE_SETS[*]}"
		return 1
	fi

	if [ "$1" = "--help" ] || [ "$1" = "-h" ] || [ -z "$1" ]; then
		discover_sets "$SCRIPT_DIR" || return 2
		echo "Usage: osx-package-install.sh [--help|-h|--list] <set>"
		echo "Available sets: ${AVAILABLE_SETS[*]}"
		return 1
	fi

	discover_sets "$SCRIPT_DIR" || return 2

	if ! is_valid_set "$1"; then
		echo "Invalid option: $1"
		echo "Available sets: ${AVAILABLE_SETS[*]}"
		return 2
	fi

	# Check if this set supports macOS
	check_set_platform "$SCRIPT_DIR" "$1" "macos"
	if [ "$HAS_PLATFORM" != "true" ]; then
		echo "Set '$1' is not applicable on macOS (no macos configuration). Skipping."
		return 3
	fi

	if ! validate_configs "$SCRIPT_DIR"; then
		echo "Config validation failed. Aborting." >&2
		return 2
	fi

	MODE="$1"
	eval "$(python3 "$SCRIPT_DIR/tools/load_config.py" --set "$MODE" --platform macos --type formulae)"
	eval "$(python3 "$SCRIPT_DIR/tools/load_config.py" --set "$MODE" --platform macos --type casks)"
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
