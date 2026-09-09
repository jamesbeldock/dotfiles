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

# --- Post-install steps ---
#
# Both of these failed on every clean machine: ~/.eza does not exist yet, and
# a plain `git clone` errors out on any re-run. Each test points HOME at a
# throwaway directory so nothing touches the real one.

fake_home() {
    FAKE_HOME="$(mktemp -d)"
    HOME="$FAKE_HOME"
}

stow_theme() {
    mkdir -p "$FAKE_HOME/.config/resources"
    touch "$FAKE_HOME/.config/resources/tokyonight.yml"
}

# Runs after every test in this file, so it must not report failure for the
# ones that never called fake_home.
teardown() {
    if [ -n "${FAKE_HOME:-}" ]; then
        rm -rf "$FAKE_HOME"
    fi
}

@test "link_eza_theme creates ~/.eza and links the theme" {
    fake_home
    stow_theme

    run link_eza_theme
    assert_success
    [ -L "$FAKE_HOME/.eza/theme.yml" ]
    assert_equal "$(readlink "$FAKE_HOME/.eza/theme.yml")" \
        "$FAKE_HOME/.config/resources/tokyonight.yml"
}

@test "link_eza_theme is safe to run twice" {
    fake_home
    stow_theme

    link_eza_theme
    run link_eza_theme
    assert_success
    [ -L "$FAKE_HOME/.eza/theme.yml" ]
}

@test "link_eza_theme skips with a reason when the theme is not stowed" {
    fake_home

    run link_eza_theme
    assert_failure
    assert_output --partial "config resources"
    [ ! -e "$FAKE_HOME/.eza/theme.yml" ]
}

@test "clone_if_missing skips a destination that already exists" {
    fake_home
    mkdir -p "$FAKE_HOME/.tmux/plugins/tpm"
    # A real clone would fail here; the stub proves git is never reached.
    git() { echo "GIT_CALLED"; return 1; }

    run clone_if_missing https://example.invalid/repo "$FAKE_HOME/.tmux/plugins/tpm"
    assert_success
    assert_output --partial "Already present"
    refute_output --partial "GIT_CALLED"
}

@test "clone_if_missing creates the parent directory before cloning" {
    fake_home
    git() { echo "GIT_CALLED"; mkdir -p "${@: -1}"; }

    run clone_if_missing https://example.invalid/repo "$FAKE_HOME/.tmux/plugins/tpm"
    assert_success
    assert_output --partial "GIT_CALLED"
    [ -d "$FAKE_HOME/.tmux/plugins" ]
}

@test "bootstrap no longer calls zinit" {
    # zinit is a zsh function; this script runs under bash, so the old atuin
    # block could never have executed.
    run grep -c "zinit" "${PROJECT_ROOT}/bootstrap.sh"
    refute_output "0"
    run grep -nE "^[[:space:]]*zinit " "${PROJECT_ROOT}/bootstrap.sh"
    assert_output ""
}
