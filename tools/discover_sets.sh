#!/bin/bash
# tools/discover_sets.sh - Shared functions for dynamic set discovery
# Source this file from scripts: source "$SCRIPT_DIR/tools/discover_sets.sh"

# discover_sets: populates AVAILABLE_SETS array.
# Args: $1 = project root (SCRIPT_DIR)
# Returns 1 if no sets found.
discover_sets() {
	local script_dir="$1"
	eval "$(python3 "$script_dir/tools/load_config.py" --list-sets)"
	if [ ${#AVAILABLE_SETS[@]} -eq 0 ]; then
		echo "Error: No config sets found in config/sets/." >&2
		return 1
	fi
	return 0
}

# is_valid_set: checks if $1 is in AVAILABLE_SETS.
# Returns 0 if found, 1 if not.
is_valid_set() {
	local name="$1"
	for s in "${AVAILABLE_SETS[@]}"; do
		if [[ "$s" == "$name" ]]; then
			return 0
		fi
	done
	return 1
}

# check_set_platform: sets HAS_PLATFORM=true/false for a set+platform.
# Args: $1 = project root, $2 = set name, $3 = platform (linux|macos)
check_set_platform() {
	local script_dir="$1"
	local set_name="$2"
	local platform="$3"
	eval "$(python3 "$script_dir/tools/load_config.py" --set "$set_name" --check-platform "$platform")"
}

# validate_configs: runs validate_config.py, returns its exit code.
# Args: $1 = project root (SCRIPT_DIR)
validate_configs() {
	local script_dir="$1"
	local output
	output="$(python3 "$script_dir/tools/validate_config.py" 2>&1)"
	local rc=$?
	if [ $rc -ne 0 ]; then
		echo "$output" >&2
	fi
	return $rc
}
