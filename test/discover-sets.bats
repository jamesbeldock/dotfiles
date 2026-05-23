#!/usr/bin/env bats

setup() {
    load test_helper
    source "${PROJECT_ROOT}/tools/discover_sets.sh"
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

# --- validate_configs ---

@test "validate_configs passes on valid configs" {
    validate_configs "$PROJECT_ROOT"
}
