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

for package in "${GNU_CORE_UTILS[@]}"; do
    if ! brew list --formula | grep -q "^$package$"; then
        brew install "$package"
    fi
done

# Create symlink for sha256sum
ln -s "${BREW_PREFIX}/bin/gsha256sum" "${BREW_PREFIX}/bin/sha256sum"

# Switch to using brew-installed zsh as default shell
if ! fgrep -q "${BREW_PREFIX}/bin/zsh" /etc/shells; then
  echo "${BREW_PREFIX}/bin/zsh" | sudo tee -a /etc/shells;
  chsh -s "${BREW_PREFIX}/bin/zsh";
fi;

# Install more recent versions of some macOS tools.
MACOS_TOOLS=(
    "grep"
    "openssh"
    "screen"
    "php"
    "gmp"
    "vim"
    "gnupg"
)

for package in "${MACOS_TOOLS[@]}"; do
    if ! brew list --formula | grep -q "^$package$"; then
         brew install "$package"
    fi
done

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

for package in "${NETWORK_SECURITY_TOOLS[@]}"; do
    brew install "$package"
done

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

for package in "${GENERAL_UTILITIES[@]}"; do
   if ! brew list --formula | grep -q "^$package$"; then
       brew install "$package"
   fi
done

# James's preferred development tools
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
    "fastfetch"
)

for package in "${JAMES_TOOLS[@]}"; do
    if ! brew list --formula | grep -q "^$package$"; then
        brew install "$package"
    fi
done

# Font installations
NERD_FONTS=(
    "font-jetbrains-mono-nerd-font"
    "font-fira-code-nerd-font"
)

for font in "${NERD_FONTS[@]}"; do
    if ! brew list --cask | grep -q "^$font$"; then
        brew install --cask "$font"
    fi
done

# Cask applications
CASK_APPS=(
    "iterm2"
)

for app in "${CASK_APPS[@]}"; do
    if ! brew list --cask | grep -q "^$app$"; then
        brew install --cask "$app"
    fi
done
echo 'export PATH="/opt/homebrew/opt/ruby/bin:$PATH"' >> ~/.zshrc

# Remove outdated versions from the cellar.
brew cleanup
