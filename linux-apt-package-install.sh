#! /bin/bash

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
    'tldr'
    "fastfetch"
)

# LXC-specific tools
LXC_TOOLS=(
    "git"
    "git-lfs"
    "lua"
    "gh"
    "ssh-copy-id"
    "bat"
    "zsh"
    "tmux"
    "mosh"
    "atuin"
    "neovim"
    "stow"
    "fastfetch"
)

# Font installations
NERD_FONTS=(
    "font-jetbrains-mono-nerd-font"
    "font-fira-code-nerd-font"
)

# parse_args: sets MODE and PACKAGES_TO_INSTALL.
# Returns 0 on success, 1 for help, 2 for invalid arg.
parse_args() {
    if [ "$1" = "--help" ] || [ "$1" = "-h" ] || [ -z "$1" ] ; then
        echo "Usage: linux-apt-package-install.sh [--help|-h] server|workstation|iot|lxc"
        echo "  iot:         Basic tools, Core utils, and James's tools (tmux, zsh, etc.)"
        echo "  lxc:         Minimal tools, Core utils, and James's tools (tmux, zsh, etc.)"
        echo "  server:      IoT + Network/Security tools + General utilities (git, etc.)"
        echo "  workstation: Server + Fonts"
        return 1
    elif [ "$1" = "iot" ]; then
        MODE="iot"
        PACKAGES_TO_INSTALL=(
            "${GNU_CORE_UTILS[@]}"
            "${BASIC_TOOLS[@]}"
            "${JAMES_TOOLS[@]}"
        )
    elif [ "$1" = "lxc" ]; then
        MODE="lxc"
        PACKAGES_TO_INSTALL=(
            "${GNU_CORE_UTILS[@]}"
            "${BASIC_TOOLS[@]}"
            "${LXC_TOOLS[@]}"
        )
    elif [ "$1" = "server" ]; then
        MODE="server"
        PACKAGES_TO_INSTALL=(
            "${GNU_CORE_UTILS[@]}"
            "${BASIC_TOOLS[@]}"
            "${JAMES_TOOLS[@]}"
            "${NETWORK_SECURITY_TOOLS[@]}"
            "${GENERAL_UTILITIES[@]}"
        )
    elif [ "$1" = "workstation" ]; then
        MODE="workstation"
        PACKAGES_TO_INSTALL=(
            "${GNU_CORE_UTILS[@]}"
            "${BASIC_TOOLS[@]}"
            "${JAMES_TOOLS[@]}"
            "${NETWORK_SECURITY_TOOLS[@]}"
            "${GENERAL_UTILITIES[@]}"
            "${NERD_FONTS[@]}"
        )
    else
        echo "Invalid option: $1"
        return 2
    fi
    return 0
}

# detect_privilege: sets SUDO and PRIV_MODE based on uid.
detect_privilege() {
    if [ "$(id -u)" -eq 0 ]; then
        SUDO=""
        PRIV_MODE="root (no sudo required)"
    else
        SUDO="sudo"
        PRIV_MODE="non-root (sudo will be used where required)"
    fi
}

# execute_install: runs apt-get update/upgrade, installs packages, starship, autoremove.
execute_install() {
    echo "Privilege mode: $PRIV_MODE"
    echo "Installing packages for $MODE mode..."

    $SUDO apt-get update
    $SUDO apt-get upgrade -y

    for package in "${PACKAGES_TO_INSTALL[@]}"; do
        if ! apt list --installed 2>/dev/null | grep -q "^${package}/"; then
            $SUDO apt-get install -y "$package"
        else
            echo "$package is already installed."
        fi
    done

    # install or update starship
    curl -sS https://starship.rs/install.sh | sh
    # Remove outdated versions from the cellar.
    $SUDO apt-get autoremove -y
}

main() {
    parse_args "$@"
    local rc=$?
    if [ $rc -eq 1 ]; then exit 0; fi
    if [ $rc -eq 2 ]; then exit 1; fi
    detect_privilege
    execute_install
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
