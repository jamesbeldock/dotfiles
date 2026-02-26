#!/usr/bin/env bats

setup() {
    load test_helper
    source "${PROJECT_ROOT}/osx-package-install.sh"
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

@test "parse_args iot returns 3 (early exit)" {
    run parse_args iot
    [ "$status" -eq 3 ]
    assert_output --partial "not applicable"
}

# --- Mode setting ---

@test "parse_args server sets MODE to server" {
    parse_args server
    assert_equal "$MODE" "server"
}

@test "parse_args workstation sets MODE to workstation" {
    parse_args workstation
    assert_equal "$MODE" "workstation"
}

# --- File-scope arrays ---

@test "GNU_CORE_UTILS array is populated" {
    assert_array_contains GNU_CORE_UTILS "coreutils"
    assert_array_contains GNU_CORE_UTILS "stow"
    assert_array_contains GNU_CORE_UTILS "bash"
}

@test "CASK_APPS array is populated" {
    assert_array_contains CASK_APPS "iterm2"
    assert_array_contains CASK_APPS "wezterm"
    assert_array_contains CASK_APPS "alfred"
    assert_array_contains CASK_APPS "docker"
    assert_array_contains CASK_APPS "1password"
}

@test "JAMES_TOOLS contains starship (macOS-specific)" {
    assert_array_contains JAMES_TOOLS "starship"
}

# --- Server mode package assembly ---

@test "server mode FORMULAE_TO_INSTALL includes expected arrays" {
    parse_args server
    # GNU_CORE_UTILS
    assert_array_contains FORMULAE_TO_INSTALL "coreutils"
    # BASIC_TOOLS
    assert_array_contains FORMULAE_TO_INSTALL "grep"
    # JAMES_TOOLS
    assert_array_contains FORMULAE_TO_INSTALL "bat"
    # NETWORK_SECURITY_TOOLS
    assert_array_contains FORMULAE_TO_INSTALL "nmap"
    # GENERAL_UTILITIES
    assert_array_contains FORMULAE_TO_INSTALL "git"
}

@test "server mode CASKS_TO_INSTALL is empty" {
    parse_args server
    assert_array_length CASKS_TO_INSTALL 0
}

# --- Workstation mode package assembly ---

@test "workstation mode FORMULAE_TO_INSTALL matches server" {
    parse_args server
    local server_formulae=("${FORMULAE_TO_INSTALL[@]}")

    parse_args workstation
    for pkg in "${server_formulae[@]}"; do
        assert_array_contains FORMULAE_TO_INSTALL "$pkg"
    done
}

@test "workstation mode CASKS_TO_INSTALL includes NERD_FONTS and CASK_APPS" {
    parse_args workstation
    assert_array_contains CASKS_TO_INSTALL "font-jetbrains-mono-nerd-font"
    assert_array_contains CASKS_TO_INSTALL "font-fira-code-nerd-font"
    assert_array_contains CASKS_TO_INSTALL "iterm2"
    assert_array_contains CASKS_TO_INSTALL "wezterm"
    assert_array_contains CASKS_TO_INSTALL "docker"
}

@test "workstation CASKS_TO_INSTALL count matches NERD_FONTS + CASK_APPS count" {
    parse_args workstation
    local expected=$(( ${#NERD_FONTS[@]} + ${#CASK_APPS[@]} ))
    assert_array_length CASKS_TO_INSTALL "$expected"
}
