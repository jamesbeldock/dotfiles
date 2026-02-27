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
