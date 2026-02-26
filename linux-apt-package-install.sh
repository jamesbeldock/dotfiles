#! /bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# parse_args: sets MODE and PACKAGES_TO_INSTALL from YAML config.
# Returns 0 on success, 1 for help, 2 for invalid arg.
parse_args() {
    if [ "$1" = "--help" ] || [ "$1" = "-h" ] || [ -z "$1" ] ; then
        echo "Usage: linux-apt-package-install.sh [--help|-h] server|workstation|iot|lxc"
        echo "  iot:         Basic tools, Core utils, and James's tools (tmux, zsh, etc.)"
        echo "  lxc:         Minimal tools, Core utils, and James's tools (tmux, zsh, etc.)"
        echo "  server:      IoT + Network/Security tools + General utilities (git, etc.)"
        echo "  workstation: Server + Fonts"
        return 1
    elif [ "$1" = "iot" ] || [ "$1" = "lxc" ] || [ "$1" = "server" ] || [ "$1" = "workstation" ]; then
        MODE="$1"
        eval "$(python3 "$SCRIPT_DIR/tools/load_config.py" --set "$MODE" --platform linux)"
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
