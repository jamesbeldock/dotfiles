#!/bin/bash
# tools/discover_sets.sh - Shared functions for dynamic set discovery
# Source this file from scripts: source "$SCRIPT_DIR/tools/discover_sets.sh"

# python_deps_hint: prints the fix for a python3 that cannot run the config tooling.
python_deps_hint() {
	echo "The config tooling needs PyYAML and jsonschema, and the python3 on your" >&2
	echo "PATH does not have them. From the repo root:" >&2
	echo "" >&2
	echo "    python3 -m venv .venv" >&2
	echo "    source .venv/bin/activate" >&2
	echo "    pip install -r tools/requirements.txt" >&2
	echo "" >&2
	echo "Then re-run this script. See README.md, \"Install the Python dependencies\"." >&2
}

# require_python_deps: checks that python3 exists and can import what
# load_config.py and validate_config.py need.
# Returns 1 with an actionable message if it cannot.
require_python_deps() {
	if ! command -v python3 >/dev/null 2>&1; then
		echo "Error: python3 is not on PATH." >&2
		python_deps_hint
		return 1
	fi

	local missing
	if ! missing="$(python3 -c 'import importlib.util as u; print(" ".join(m for m in ("yaml", "jsonschema") if u.find_spec(m) is None))' 2>/dev/null)"; then
		echo "Error: python3 is on PATH but failed to run." >&2
		python_deps_hint
		return 1
	fi

	if [ -n "$missing" ]; then
		echo "Error: python3 is missing required module(s): $missing" >&2
		python_deps_hint
		return 1
	fi

	return 0
}

# discover_sets: populates AVAILABLE_SETS array.
# Args: $1 = project root (SCRIPT_DIR)
# Returns 1 if the loader failed or no sets were found.
discover_sets() {
	local script_dir="$1"
	local output

	# Don't leave a previous call's values behind for a caller that ignores
	# the return code.
	AVAILABLE_SETS=()

	# The exit code of load_config.py used to vanish into the command
	# substitution, so any failure -- a missing PyYAML above all -- surfaced as
	# an empty array and the "No config sets found" message below, which blames
	# the config for a broken interpreter.
	if ! output="$(python3 "$script_dir/tools/load_config.py" --list-sets)"; then
		echo "Error: tools/load_config.py failed; could not read config/sets/." >&2
		require_python_deps >/dev/null 2>&1 || python_deps_hint
		return 1
	fi

	eval "$output"
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
# Returns 1 if the loader failed, leaving HAS_PLATFORM empty rather than stale.
check_set_platform() {
	local script_dir="$1"
	local set_name="$2"
	local platform="$3"
	local output

	HAS_PLATFORM=""

	# Same swallowed-exit-code problem as discover_sets above: a failure here
	# used to leave HAS_PLATFORM holding whatever the last call set.
	if ! output="$(python3 "$script_dir/tools/load_config.py" --set "$set_name" --check-platform "$platform")"; then
		echo "Error: could not check platform support for set '$set_name'." >&2
		return 1
	fi

	eval "$output"
	return 0
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
