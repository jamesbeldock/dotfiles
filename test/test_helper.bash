# test/test_helper.bash
# Common test helper loaded by all .bats files

# Resolve paths
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$TEST_DIR/.." && pwd)"

# Load BATS helper libraries
load "${TEST_DIR}/libs/bats-support/load"
load "${TEST_DIR}/libs/bats-assert/load"

# Resolve PY the same way the shell helpers do, so tests that invoke tools/*.py
# directly run under the repo venv without the suite having to be started from
# an activated shell.
source "${PROJECT_ROOT}/tools/discover_sets.sh"
resolve_python

# assert_array_contains ARRAY_NAME VALUE
# Asserts that the named array contains the given value.
assert_array_contains() {
    local arr_name="$1"
    local value="$2"
    eval "local items=(\"\${${arr_name}[@]}\")"
    for item in "${items[@]}"; do
        if [[ "$item" == "$value" ]]; then
            return 0
        fi
    done
    echo "Expected array '$arr_name' to contain '$value'" >&2
    eval "echo \"Array contents: \${${arr_name}[*]}\"" >&2
    return 1
}

# assert_array_not_contains ARRAY_NAME VALUE
# Asserts that the named array does NOT contain the given value.
assert_array_not_contains() {
    local arr_name="$1"
    local value="$2"
    eval "local items=(\"\${${arr_name}[@]}\")"
    for item in "${items[@]}"; do
        if [[ "$item" == "$value" ]]; then
            echo "Expected array '$arr_name' to NOT contain '$value'" >&2
            return 1
        fi
    done
    return 0
}

# assert_array_length ARRAY_NAME EXPECTED_LENGTH
# Asserts that the named array has exactly the expected number of elements.
assert_array_length() {
    local arr_name="$1"
    local expected="$2"
    eval "local actual=\${#${arr_name}[@]}"
    if [[ "$actual" -ne "$expected" ]]; then
        echo "Expected array '$arr_name' to have $expected elements, got $actual" >&2
        eval "echo \"Array contents: \${${arr_name}[*]}\"" >&2
        return 1
    fi
    return 0
}
