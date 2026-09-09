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

# --- Platform checks ---

@test "parse_args returns 3 for sets without macos config" {
    run parse_args iot
    [ "$status" -eq 3 ]
    assert_output --partial "not applicable"
}

@test "parse_args returns 3 for lxc on macos" {
    run parse_args lxc
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

# --- Homebrew PATH bootstrapping ---
#
# On a clean Mac the installer puts brew in /opt/homebrew/bin, which is not on
# PATH until a new login shell reads /etc/paths.d/homebrew. ensure_brew has to
# load it itself or every later brew call fails with "command not found".

@test "brew_shellenv returns 1 when no candidate brew exists" {
    run brew_shellenv "$BATS_TEST_TMPDIR/nope/brew" "$BATS_TEST_TMPDIR/also-nope/brew"
    assert_failure
}

@test "brew_shellenv evals shellenv from the first candidate that exists" {
    local fake="$BATS_TEST_TMPDIR/brew"
    cat >"$fake" <<'SH'
#!/bin/bash
echo 'export BREW_SHELLENV_RAN=1'
SH
    chmod +x "$fake"

    brew_shellenv "$BATS_TEST_TMPDIR/missing/brew" "$fake"
    assert_equal "$BREW_SHELLENV_RAN" "1"
}

@test "brew_shellenv skips a candidate that is not executable" {
    local notexec="$BATS_TEST_TMPDIR/not-exec"
    echo 'export SHOULD_NOT_RUN=1' >"$notexec"
    chmod -x "$notexec"

    run brew_shellenv "$notexec"
    assert_failure
}

@test "ensure_brew fails instead of continuing when brew stays missing" {
    # No brew on PATH, and the installer is a no-op, so brew never appears.
    command() { return 1; }
    curl() { echo ":"; }
    brew_shellenv() { return 1; }

    run ensure_brew
    assert_failure
    assert_output --partial "still not on PATH"
}

@test "ensure_brew fails when brew --prefix comes back empty" {
    # An empty BREW_PREFIX is what turned a symlink target into /bin/sha256sum.
    command() { return 0; }
    brew() { case "$1" in --prefix) echo "" ;; *) return 0 ;; esac; }

    run ensure_brew
    assert_failure
    assert_output --partial "Could not determine the Homebrew prefix"
}
