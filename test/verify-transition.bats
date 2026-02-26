#!/usr/bin/env bats

setup() {
    load test_helper
}

@test "transition verification passes for all sets" {
    run python3 "${PROJECT_ROOT}/tools/verify_transition.py"
    assert_success
    assert_output --partial "PASSED"
}
