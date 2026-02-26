#!/usr/bin/env bats

setup() {
    load test_helper
}

@test "validate_config.py exits 0 on valid configs" {
    run python3 "${PROJECT_ROOT}/tools/validate_config.py"
    assert_success
    assert_output --partial "All config files valid"
}

@test "validate_config.py catches invalid group reference" {
    # Create a temp set file with a bad group name
    local tmpdir
    tmpdir="$(mktemp -d)"
    cp -r "${PROJECT_ROOT}/config/"* "$tmpdir/"
    cat > "$tmpdir/sets/bad.yaml" << 'EOF'
name: bad
stow_packages:
  - basic
linux:
  groups:
    - nonexistent_group
EOF
    run python3 "${PROJECT_ROOT}/tools/validate_config.py" --config-dir "$tmpdir"
    assert_failure
    assert_output --partial "unknown group"
    rm -rf "$tmpdir"
}

@test "validate_config.py catches invalid stow package reference" {
    local tmpdir
    tmpdir="$(mktemp -d)"
    cp -r "${PROJECT_ROOT}/config/"* "$tmpdir/"
    cat > "$tmpdir/sets/bad.yaml" << 'EOF'
name: bad
stow_packages:
  - nonexistent_package
EOF
    run python3 "${PROJECT_ROOT}/tools/validate_config.py" --config-dir "$tmpdir"
    assert_failure
    assert_output --partial "not in catalog"
    rm -rf "$tmpdir"
}

@test "validate_config.py catches macos_only group in linux.groups" {
    local tmpdir
    tmpdir="$(mktemp -d)"
    cp -r "${PROJECT_ROOT}/config/"* "$tmpdir/"
    cat > "$tmpdir/sets/bad.yaml" << 'EOF'
name: bad
stow_packages:
  - basic
linux:
  groups:
    - cask_apps
EOF
    run python3 "${PROJECT_ROOT}/tools/validate_config.py" --config-dir "$tmpdir"
    assert_failure
    assert_output --partial "macos_only"
    rm -rf "$tmpdir"
}
