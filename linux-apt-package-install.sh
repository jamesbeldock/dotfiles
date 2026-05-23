#! /bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/tools/discover_sets.sh"

# parse_args: sets MODE and PACKAGES_TO_INSTALL from YAML config.
# Returns 0 on success, 1 for help/list, 2 for invalid arg, 3 for platform skip.
parse_args() {
    if [ "$1" = "--list" ]; then
        discover_sets "$SCRIPT_DIR" || return 2
        echo "Available sets: ${AVAILABLE_SETS[*]}"
        return 1
    fi

    if [ "$1" = "--help" ] || [ "$1" = "-h" ] || [ -z "$1" ]; then
        discover_sets "$SCRIPT_DIR" || return 2
        echo "Usage: linux-apt-package-install.sh [--help|-h|--list] <set>"
        echo "Available sets: ${AVAILABLE_SETS[*]}"
        return 1
    fi

    discover_sets "$SCRIPT_DIR" || return 2

    if ! is_valid_set "$1"; then
        echo "Invalid option: $1"
        echo "Available sets: ${AVAILABLE_SETS[*]}"
        return 2
    fi

    # Check this set has linux config
    check_set_platform "$SCRIPT_DIR" "$1" "linux"
    if [ "$HAS_PLATFORM" != "true" ]; then
        echo "Set '$1' has no Linux package configuration. Nothing to install."
        return 3
    fi

    if ! validate_configs "$SCRIPT_DIR"; then
        echo "Config validation failed. Aborting." >&2
        return 2
    fi

    MODE="$1"
    eval "$(python3 "$SCRIPT_DIR/tools/load_config.py" --set "$MODE" --platform linux)"
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
    if [ $rc -eq 3 ]; then exit 0; fi
    detect_privilege
    execute_install
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
