#!/usr/bin/env bats

setup() {
    load test_helper
    source "${PROJECT_ROOT}/bootstrap.sh"
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
        assert_equal "$MODE" "$set_name"
    done
}

# --- Mode setting ---

@test "parse_args server sets MODE" {
    parse_args server
    assert_equal "$MODE" "server"
}

@test "parse_args workstation sets MODE" {
    parse_args workstation
    assert_equal "$MODE" "workstation"
}

@test "parse_args iot sets MODE" {
    parse_args iot
    assert_equal "$MODE" "iot"
}

@test "parse_args lxc sets MODE" {
    parse_args lxc
    assert_equal "$MODE" "lxc"
}

# --- OS detection ---

@test "detect_os on current platform succeeds" {
    detect_os
    [[ "$OS_TYPE" == "darwin" ]] || [[ "$OS_TYPE" == "linux" ]]
}

@test "detect_os with darwin OSTYPE sets OS_TYPE to darwin" {
    OSTYPE="darwin23.0"
    detect_os
    assert_equal "$OS_TYPE" "darwin"
}

@test "detect_os with linux-gnu OSTYPE sets OS_TYPE to linux" {
    OSTYPE="linux-gnu"
    detect_os
    assert_equal "$OS_TYPE" "linux"
}

@test "detect_os with unknown OSTYPE returns 1" {
    OSTYPE="freebsd"
    run detect_os
    assert_failure
    [ "$status" -eq 1 ]
    assert_output --partial "Unsupported OS"
}
