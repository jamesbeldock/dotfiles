# TODO: remove this warning:
# this hasn't been debugged yet; don't trust this to work
echo "WARNING: This script hasn't been debugged yet; don't trust this to work"

sudo apt-get install -y  update

sudo apt-get install -y  upgrade

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
    if ! apt list --installed | grep -q "^$package$"; then
        sudo apt-get install -y  install "$package"
    fi
done

BASIC_TOOLS=(
    "grep"
    "openssh"
    "screen"
    "php"
    "gmp"
    "vim"
    "gnupg"
)

for package in "${BASIC_TOOLS[@]}"; do
    if ! apt list --installed | grep -q "^$package$"; then
         sudo apt-get install -y  install "$package"
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
        if ! apt list --installed | grep -q "^$package$"; then
            sudo apt-get install -y  install "$package"
        fi
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
   if ! apt list --installed | grep -q "^$package$"; then
       sudo apt-get install -y  install "$package"
   fi
done

# James's preferred development tools
JAMES_TOOLS=(
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
    if ! apt list --installed | grep -q "^$package$"; then
        sudo apt-get install -y "$package"
    fi
done

# Font installations
NERD_FONTS=(
    "font-jetbrains-mono-nerd-font"
    "font-fira-code-nerd-font"
)

for font in "${NERD_FONTS[@]}"; do
    if ! apt list --installed | grep -q "^$font$"; then
        sudo apt-get install -y  install "$font"
    fi
done

# Remove outdated versions from the cellar.
sudo apt-get install -y  autoremove
