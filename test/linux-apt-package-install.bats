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
