#!/usr/bin/env bats

setup() {
    load test_helper
    source "${PROJECT_ROOT}/stow-packages.sh"
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
}

# --- Mode setting ---

@test "parse_args workstation sets MODE" {
    parse_args workstation
    assert_equal "$MODE" "workstation"
}

@test "parse_args server sets MODE" {
    parse_args server
    assert_equal "$MODE" "server"
}

@test "parse_args iot sets MODE" {
    parse_args iot
    assert_equal "$MODE" "iot"
}

@test "parse_args lxc sets MODE" {
    parse_args lxc
    assert_equal "$MODE" "lxc"
}

# --- Workstation package list ---

@test "workstation PACKAGE array contains expected items" {
    parse_args workstation
    assert_array_contains PACKAGE "basic"
    assert_array_contains PACKAGE "config resources"
    assert_array_contains PACKAGE "fastfetch"
    assert_array_contains PACKAGE "git"
    assert_array_contains PACKAGE "iterm2"
    assert_array_contains PACKAGE "nvim"
    assert_array_contains PACKAGE "oh-my-zsh"
    assert_array_contains PACKAGE "starship"
    assert_array_contains PACKAGE "tmux"
    assert_array_contains PACKAGE "wezterm"
    assert_array_contains PACKAGE "zsh"
    assert_array_length PACKAGE 11
}

# --- Server package list ---

@test "server PACKAGE array contains expected items" {
    parse_args server
    assert_array_contains PACKAGE "basic"
    assert_array_contains PACKAGE "git"
    assert_array_contains PACKAGE "nvim"
    assert_array_contains PACKAGE "tmux"
    assert_array_contains PACKAGE "starship"
    assert_array_contains PACKAGE "zsh"
    assert_array_contains PACKAGE "fastfetch"
    assert_array_contains PACKAGE "config resources"
    assert_array_length PACKAGE 8
}

@test "server PACKAGE array does NOT contain workstation-only items" {
    parse_args server
    assert_array_not_contains PACKAGE "iterm2"
    assert_array_not_contains PACKAGE "wezterm"
    assert_array_not_contains PACKAGE "oh-my-zsh"
}

# --- IoT package list ---

@test "iot PACKAGE array contains expected items" {
    parse_args iot
    assert_array_contains PACKAGE "basic"
    assert_array_contains PACKAGE "config resources"
    assert_array_contains PACKAGE "fastfetch"
    assert_array_contains PACKAGE "nvim"
    assert_array_contains PACKAGE "tmux"
    assert_array_contains PACKAGE "zsh"
    assert_array_length PACKAGE 6
}

@test "iot PACKAGE array does NOT contain server/workstation items" {
    parse_args iot
    assert_array_not_contains PACKAGE "git"
    assert_array_not_contains PACKAGE "starship"
    assert_array_not_contains PACKAGE "iterm2"
}

# --- LXC package list ---

@test "lxc PACKAGE array matches iot PACKAGE array" {
    parse_args iot
    local iot_packages=("${PACKAGE[@]}")

    parse_args lxc
    local lxc_packages=("${PACKAGE[@]}")

    assert_equal "${#iot_packages[@]}" "${#lxc_packages[@]}"

    for i in "${!iot_packages[@]}"; do
        assert_equal "${iot_packages[$i]}" "${lxc_packages[$i]}"
    done
}

# --- Privilege detection ---

@test "detect_privilege as non-root sets PRIV_MODE correctly" {
    # Skip if running as root (unlikely in test)
    if [ "$(id -u)" -eq 0 ]; then
        skip "running as root"
    fi
    detect_privilege
    assert_equal "$PRIV_MODE" "non-root (sudo will be used where required)"
}

@test "detect_privilege as root sets PRIV_MODE correctly" {
    # Mock id to return 0
    id() { echo 0; }
    detect_privilege
    assert_equal "$PRIV_MODE" "root (no sudo required)"
    unset -f id
}
