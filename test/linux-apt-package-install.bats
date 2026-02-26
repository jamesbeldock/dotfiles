#!/usr/bin/env bats

setup() {
    load test_helper
    source "${PROJECT_ROOT}/linux-apt-package-install.sh"
}

# --- Argument parsing ---

@test "parse_args with --help returns 1" {
    run parse_args --help
    assert_failure
    [ "$status" -eq 1 ]
    assert_output --partial "Usage:"
}

@test "parse_args with -h returns 1" {
    run parse_args -h
    assert_failure
    [ "$status" -eq 1 ]
    assert_output --partial "Usage:"
}

@test "parse_args with no argument returns 1" {
    run parse_args
    assert_failure
    [ "$status" -eq 1 ]
    assert_output --partial "Usage:"
}

@test "parse_args with invalid argument returns 2" {
    run parse_args "foobar"
    [ "$status" -eq 2 ]
    assert_output --partial "Invalid option"
}

# --- Mode setting ---

@test "parse_args iot sets MODE to iot" {
    parse_args iot
    assert_equal "$MODE" "iot"
}

@test "parse_args lxc sets MODE to lxc" {
    parse_args lxc
    assert_equal "$MODE" "lxc"
}

@test "parse_args server sets MODE to server" {
    parse_args server
    assert_equal "$MODE" "server"
}

@test "parse_args workstation sets MODE to workstation" {
    parse_args workstation
    assert_equal "$MODE" "workstation"
}

# --- File-scope arrays are populated ---

@test "GNU_CORE_UTILS array is populated" {
    assert_array_contains GNU_CORE_UTILS "coreutils"
    assert_array_contains GNU_CORE_UTILS "stow"
    assert_array_contains GNU_CORE_UTILS "bash"
    assert_array_contains GNU_CORE_UTILS "wget"
}

@test "BASIC_TOOLS array is populated" {
    assert_array_contains BASIC_TOOLS "grep"
    assert_array_contains BASIC_TOOLS "vim"
    assert_array_contains BASIC_TOOLS "openssh"
    assert_array_contains BASIC_TOOLS "gnupg"
}

@test "JAMES_TOOLS array is populated" {
    assert_array_contains JAMES_TOOLS "bat"
    assert_array_contains JAMES_TOOLS "zsh"
    assert_array_contains JAMES_TOOLS "fzf"
    assert_array_contains JAMES_TOOLS "neovim"
    assert_array_contains JAMES_TOOLS "tmux"
}

@test "LXC_TOOLS array is populated" {
    assert_array_contains LXC_TOOLS "git"
    assert_array_contains LXC_TOOLS "zsh"
    assert_array_contains LXC_TOOLS "tmux"
    assert_array_contains LXC_TOOLS "neovim"
    assert_array_contains LXC_TOOLS "stow"
    assert_array_contains LXC_TOOLS "fastfetch"
}

@test "NETWORK_SECURITY_TOOLS array is populated" {
    assert_array_contains NETWORK_SECURITY_TOOLS "nmap"
    assert_array_contains NETWORK_SECURITY_TOOLS "socat"
    assert_array_contains NETWORK_SECURITY_TOOLS "dns2tcp"
}

@test "GENERAL_UTILITIES array is populated" {
    assert_array_contains GENERAL_UTILITIES "git"
    assert_array_contains GENERAL_UTILITIES "tree"
    assert_array_contains GENERAL_UTILITIES "lua"
    assert_array_contains GENERAL_UTILITIES "ack"
}

@test "NERD_FONTS array is populated" {
    assert_array_contains NERD_FONTS "font-jetbrains-mono-nerd-font"
    assert_array_contains NERD_FONTS "font-fira-code-nerd-font"
}

# --- IoT mode package assembly ---

@test "iot mode includes GNU_CORE_UTILS packages" {
    parse_args iot
    assert_array_contains PACKAGES_TO_INSTALL "coreutils"
    assert_array_contains PACKAGES_TO_INSTALL "stow"
}

@test "iot mode includes BASIC_TOOLS packages" {
    parse_args iot
    assert_array_contains PACKAGES_TO_INSTALL "grep"
    assert_array_contains PACKAGES_TO_INSTALL "vim"
}

@test "iot mode includes JAMES_TOOLS packages" {
    parse_args iot
    assert_array_contains PACKAGES_TO_INSTALL "bat"
    assert_array_contains PACKAGES_TO_INSTALL "neovim"
}

@test "iot mode does NOT include NETWORK_SECURITY_TOOLS" {
    parse_args iot
    assert_array_not_contains PACKAGES_TO_INSTALL "nmap"
    assert_array_not_contains PACKAGES_TO_INSTALL "sqlmap"
}

# --- LXC mode package assembly ---

@test "lxc mode includes GNU_CORE_UTILS packages" {
    parse_args lxc
    assert_array_contains PACKAGES_TO_INSTALL "coreutils"
    assert_array_contains PACKAGES_TO_INSTALL "stow"
}

@test "lxc mode includes BASIC_TOOLS packages" {
    parse_args lxc
    assert_array_contains PACKAGES_TO_INSTALL "grep"
    assert_array_contains PACKAGES_TO_INSTALL "vim"
}

@test "lxc mode includes LXC_TOOLS packages" {
    parse_args lxc
    assert_array_contains PACKAGES_TO_INSTALL "git"
    assert_array_contains PACKAGES_TO_INSTALL "neovim"
    assert_array_contains PACKAGES_TO_INSTALL "fastfetch"
}

@test "lxc mode does NOT include JAMES_TOOLS-only items" {
    parse_args lxc
    assert_array_not_contains PACKAGES_TO_INSTALL "broot"
    assert_array_not_contains PACKAGES_TO_INSTALL "yazi"
    assert_array_not_contains PACKAGES_TO_INSTALL "thefuck"
}

# --- Server mode package assembly ---

@test "server mode includes all expected arrays" {
    parse_args server
    # GNU_CORE_UTILS
    assert_array_contains PACKAGES_TO_INSTALL "coreutils"
    # BASIC_TOOLS
    assert_array_contains PACKAGES_TO_INSTALL "grep"
    # JAMES_TOOLS
    assert_array_contains PACKAGES_TO_INSTALL "bat"
    # NETWORK_SECURITY_TOOLS
    assert_array_contains PACKAGES_TO_INSTALL "nmap"
    # GENERAL_UTILITIES
    assert_array_contains PACKAGES_TO_INSTALL "tree"
}

@test "server mode does NOT include NERD_FONTS" {
    parse_args server
    assert_array_not_contains PACKAGES_TO_INSTALL "font-jetbrains-mono-nerd-font"
}

# --- Workstation mode package assembly ---

@test "workstation mode includes everything including NERD_FONTS" {
    parse_args workstation
    assert_array_contains PACKAGES_TO_INSTALL "coreutils"
    assert_array_contains PACKAGES_TO_INSTALL "grep"
    assert_array_contains PACKAGES_TO_INSTALL "bat"
    assert_array_contains PACKAGES_TO_INSTALL "nmap"
    assert_array_contains PACKAGES_TO_INSTALL "tree"
    assert_array_contains PACKAGES_TO_INSTALL "font-jetbrains-mono-nerd-font"
    assert_array_contains PACKAGES_TO_INSTALL "font-fira-code-nerd-font"
}

@test "workstation PACKAGES_TO_INSTALL is superset of server" {
    parse_args server
    local server_packages=("${PACKAGES_TO_INSTALL[@]}")

    parse_args workstation
    for pkg in "${server_packages[@]}"; do
        assert_array_contains PACKAGES_TO_INSTALL "$pkg"
    done
}

# --- Privilege detection ---

@test "detect_privilege as non-root sets SUDO to sudo" {
    if [ "$(id -u)" -eq 0 ]; then
        skip "running as root"
    fi
    detect_privilege
    assert_equal "$SUDO" "sudo"
}

@test "detect_privilege as root sets SUDO to empty string" {
    id() { echo 0; }
    detect_privilege
    assert_equal "$SUDO" ""
    unset -f id
}

@test "detect_privilege as non-root sets PRIV_MODE" {
    if [ "$(id -u)" -eq 0 ]; then
        skip "running as root"
    fi
    detect_privilege
    assert_equal "$PRIV_MODE" "non-root (sudo will be used where required)"
}

@test "detect_privilege as root sets PRIV_MODE" {
    id() { echo 0; }
    detect_privilege
    assert_equal "$PRIV_MODE" "root (no sudo required)"
    unset -f id
}
