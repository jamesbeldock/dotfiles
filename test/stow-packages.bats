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
    assert_output --partial "Invalid option"
}

# --- Dynamic set discovery ---

@test "parse_args help shows available sets dynamically" {
    run parse_args --help
    assert_output --partial "Available sets:"
    assert_output --partial "server"
    assert_output --partial "workstation"
}

@test "parse_args --list returns 1 and shows sets" {
    run parse_args --list
    [ "$status" -eq 1 ]
    assert_output --partial "Available sets:"
}

@test "parse_args accepts all discovered sets" {
    eval "$(python3 "$PROJECT_ROOT/tools/load_config.py" --list-sets)"
    for set_name in "${AVAILABLE_SETS[@]}"; do
        parse_args "$set_name"
    done
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

# --- Privilege detection ---

@test "detect_privilege as non-root sets PRIV_MODE correctly" {
    if [ "$(id -u)" -eq 0 ]; then
        skip "running as root"
    fi
    detect_privilege
    assert_equal "$PRIV_MODE" "non-root (sudo will be used where required)"
}

@test "detect_privilege as root sets PRIV_MODE correctly" {
    id() { echo 0; }
    detect_privilege
    assert_equal "$PRIV_MODE" "root (no sudo required)"
    unset -f id
}

# --- Stow execution ---
#
# `stow` is stubbed out so these tests never touch the real home directory.
# The stub echoes the package it was handed (always the last argument) so
# tests can assert which packages were attempted.

# stub_stow FAILING...: replaces `stow` with a stub that exits 1 for any
# package named in the argument list and 0 for everything else.
stub_stow() {
    # Global, not local: the stub body is evaluated after stub_stow returns.
    STUB_STOW_FAILING=" $* "
    stow() {
        local pkg="${!#}"
        echo "STOWED:$pkg"
        [[ "$STUB_STOW_FAILING" == *" $pkg "* ]] && return 1
        return 0
    }
}

@test "execute_stow succeeds when every package stows" {
    MODE="test"
    PRIV_MODE="test"
    PACKAGE=(alpha beta)
    stub_stow
    run execute_stow
    assert_success
    assert_output --partial "All packages stowed successfully."
}

@test "execute_stow returns 1 when a package conflicts" {
    MODE="test"
    PRIV_MODE="test"
    PACKAGE=(alpha beta)
    stub_stow beta
    run execute_stow
    assert_failure
    [ "$status" -eq 1 ]
}

@test "execute_stow does not claim success when a package conflicts" {
    MODE="test"
    PRIV_MODE="test"
    PACKAGE=(alpha beta)
    stub_stow beta
    run execute_stow
    refute_output --partial "All packages stowed successfully."
}

@test "execute_stow names the package that failed" {
    MODE="test"
    PRIV_MODE="test"
    PACKAGE=(alpha beta)
    stub_stow beta
    run execute_stow
    assert_output --partial "Failed to stow 1 of 2 package(s): beta"
}

@test "execute_stow continues past a failing package" {
    MODE="test"
    PRIV_MODE="test"
    PACKAGE=(alpha beta gamma)
    stub_stow alpha
    run execute_stow
    assert_output --partial "STOWED:alpha"
    assert_output --partial "STOWED:beta"
    assert_output --partial "STOWED:gamma"
}

@test "execute_stow reports every failed package" {
    MODE="test"
    PRIV_MODE="test"
    PACKAGE=(alpha beta gamma)
    stub_stow alpha gamma
    run execute_stow
    assert_failure
    assert_output --partial "Failed to stow 2 of 3 package(s): alpha gamma"
}
