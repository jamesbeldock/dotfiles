if ! command -v brew &> /dev/null; then
    echo "Homebrew is not installed. Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Make sure we’re using the latest Homebrew.
brew update

# Upgrade any already-installed formulae.
brew upgrade

# Save Homebrew’s installed location.
BREW_PREFIX=$(brew --prefix)

# Install GNU core utilities (those that come with macOS are outdated).
# Don't forget to add `$(brew --prefix coreutils)/libexec/gnubin` to `$PATH`.
GNU_CORE_UTILS=(
    "coreutils"
    "moreutils"  # Install some other useful utilities like `sponge`
    "findutils"  # Install GNU `find`, `locate`, `updatedb`, and `xargs`, `g`-prefixed
    "bash"       # Install a modern version of Bash
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
    "alfred"
    "spotify"
    "docker"
    "cmake"
    "vimr"
    "itsycal"
    "dash"
    "1password"
    "1password-cli"
)

# Input parsing
if [ "$1" = "--help" ] || [ "$1" = "-h" ] || [ -z "$1" ] ; then
    echo "Usage: osx-package-install.sh [--help|-h] server|workstation|iot"
    echo "  iot:         Core utils, Basic tools, and James's tools"
    echo "  server:      IoT + Network/Security tools + General utilities"
    echo "  workstation: Server + Fonts + Cask apps"
    exit 0
elif [ "$1" = "iot" ]; then
    echo "IoT profile is not applicable on macOS. Skipping package installation."
    exit 0
elif [ "$1" = "server" ]; then
    MODE="server"
    FORMULAE_TO_INSTALL=(
        "${GNU_CORE_UTILS[@]}"
        "${BASIC_TOOLS[@]}"
        "${JAMES_TOOLS[@]}"
        "${NETWORK_SECURITY_TOOLS[@]}"
        "${GENERAL_UTILITIES[@]}"
    )
    CASKS_TO_INSTALL=()
elif [ "$1" = "workstation" ]; then
    MODE="workstation"
    FORMULAE_TO_INSTALL=(
        "${GNU_CORE_UTILS[@]}"
        "${BASIC_TOOLS[@]}"
        "${JAMES_TOOLS[@]}"
        "${NETWORK_SECURITY_TOOLS[@]}"
        "${GENERAL_UTILITIES[@]}"
    )
    CASKS_TO_INSTALL=(
        "${NERD_FONTS[@]}"
        "${CASK_APPS[@]}"
    )
else
    echo "Invalid option: $1"
    exit 1
fi

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
  echo "${BREW_PREFIX}/bin/zsh" | sudo tee -a /etc/shells;
  chsh -s "${BREW_PREFIX}/bin/zsh";
fi;

echo 'export PATH="/opt/homebrew/opt/ruby/bin:$PATH"' >> ~/.zshrc

# Remove outdated versions from the cellar.
brew cleanup
