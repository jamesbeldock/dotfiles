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
