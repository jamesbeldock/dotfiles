#!/usr/bin/env bats

setup() {
    load test_helper
    source "${PROJECT_ROOT}/tools/discover_sets.sh"
}

# --- require_python_deps ---

@test "require_python_deps passes in an environment that has the deps" {
    require_python_deps
}

@test "require_python_deps names the missing module and prints the fix" {
    # find_spec returns None for the stubbed module, so load_config.py's imports
    # would fail the same way.
    python3() { echo "yaml"; }
    run require_python_deps
    assert_failure
    assert_output --partial "yaml"
    assert_output --partial "pip install -r tools/requirements.txt"
}

@test "require_python_deps reports a python3 that is missing entirely" {
    command() {
        if [[ "$1" == "-v" && "$2" == "python3" ]]; then return 1; fi
        builtin command "$@"
    }
    run require_python_deps
    assert_failure
    assert_output --partial "python3 is not on PATH"
}

# --- discover_sets ---

@test "discover_sets populates AVAILABLE_SETS with all set files" {
    discover_sets "$PROJECT_ROOT"
    assert_array_contains AVAILABLE_SETS "iot"
    assert_array_contains AVAILABLE_SETS "lxc"
    assert_array_contains AVAILABLE_SETS "server"
    assert_array_contains AVAILABLE_SETS "workstation"
}

@test "discover_sets count matches actual yaml file count" {
    discover_sets "$PROJECT_ROOT"
    local file_count
    file_count=$(command ls "$PROJECT_ROOT/config/sets/"*.yaml 2>/dev/null | wc -l | tr -d ' ')
    assert_array_length AVAILABLE_SETS "$file_count"
}

@test "discover_sets with empty sets dir returns 1" {
    local tmpdir
    tmpdir="$(mktemp -d)"
    mkdir -p "$tmpdir/config/sets"
    cp "$PROJECT_ROOT/config/packages.yaml" "$tmpdir/config/"
    cp -r "$PROJECT_ROOT/config/schema" "$tmpdir/config/"
    # Create a minimal tools dir with load_config.py
    mkdir -p "$tmpdir/tools"
    cp "$PROJECT_ROOT/tools/load_config.py" "$tmpdir/tools/"
    run discover_sets "$tmpdir"
    assert_failure
    assert_output --partial "No config sets found"
    rm -rf "$tmpdir"
}

# A loader that cannot run is a different fault from a config directory with
# nothing in it, and the two used to be indistinguishable: the exit code went
# into a command substitution and only the empty array survived.
@test "discover_sets blames the loader, not the config, when load_config.py fails" {
    local tmpdir
    tmpdir="$(mktemp -d)"
    mkdir -p "$tmpdir/tools" "$tmpdir/config/sets"
    printf '%s\n' \
        'import sys' \
        'print("ModuleNotFoundError: No module named \x27yaml\x27", file=sys.stderr)' \
        'sys.exit(1)' > "$tmpdir/tools/load_config.py"

    run discover_sets "$tmpdir"
    assert_failure
    assert_output --partial "tools/load_config.py failed"
    refute_output --partial "No config sets found"
    rm -rf "$tmpdir"
}

@test "discover_sets clears a previous result when the loader fails" {
    local tmpdir
    tmpdir="$(mktemp -d)"
    mkdir -p "$tmpdir/tools"
    printf '%s\n' 'import sys' 'sys.exit(1)' > "$tmpdir/tools/load_config.py"

    discover_sets "$PROJECT_ROOT"
    assert_array_contains AVAILABLE_SETS "workstation"
    ! discover_sets "$tmpdir"
    assert_array_length AVAILABLE_SETS 0
    rm -rf "$tmpdir"
}

# --- is_valid_set ---

@test "is_valid_set returns 0 for existing set" {
    discover_sets "$PROJECT_ROOT"
    is_valid_set "server"
}

@test "is_valid_set returns 0 for all discovered sets" {
    discover_sets "$PROJECT_ROOT"
    for s in "${AVAILABLE_SETS[@]}"; do
        is_valid_set "$s"
    done
}

@test "is_valid_set returns 1 for nonexistent set" {
    discover_sets "$PROJECT_ROOT"
    run is_valid_set "nonexistent"
    assert_failure
}

@test "is_valid_set returns 1 for empty string" {
    discover_sets "$PROJECT_ROOT"
    run is_valid_set ""
    assert_failure
}

# --- check_set_platform ---

@test "check_set_platform returns true for server on linux" {
    check_set_platform "$PROJECT_ROOT" "server" "linux"
    assert_equal "$HAS_PLATFORM" "true"
}

@test "check_set_platform returns true for server on macos" {
    check_set_platform "$PROJECT_ROOT" "server" "macos"
    assert_equal "$HAS_PLATFORM" "true"
}

@test "check_set_platform returns false for iot on macos" {
    check_set_platform "$PROJECT_ROOT" "iot" "macos"
    assert_equal "$HAS_PLATFORM" "false"
}

@test "check_set_platform returns false for lxc on macos" {
    check_set_platform "$PROJECT_ROOT" "lxc" "macos"
    assert_equal "$HAS_PLATFORM" "false"
}

@test "check_set_platform returns true for iot on linux" {
    check_set_platform "$PROJECT_ROOT" "iot" "linux"
    assert_equal "$HAS_PLATFORM" "true"
}

@test "check_set_platform fails and clears HAS_PLATFORM on an unknown set" {
    check_set_platform "$PROJECT_ROOT" "server" "linux"
    assert_equal "$HAS_PLATFORM" "true"
    run check_set_platform "$PROJECT_ROOT" "nosuchset" "linux"
    assert_failure
    check_set_platform "$PROJECT_ROOT" "nosuchset" "linux" || true
    assert_equal "$HAS_PLATFORM" ""
}

# --- validate_configs ---

@test "validate_configs passes on valid configs" {
    validate_configs "$PROJECT_ROOT"
}
