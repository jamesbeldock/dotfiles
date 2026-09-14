#!/bin/bash
# tools/discover_sets.sh - Shared functions for dynamic set discovery
# Source this file from scripts: source "$SCRIPT_DIR/tools/discover_sets.sh"

# Repo root, resolved when this file is sourced rather than passed in, so
# resolve_python below can find the repo-local .venv without changing the
# signature of every helper here.
DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# resolve_python: sets PY to the interpreter that should run tools/*.py.
# Order: explicit override, already-activated venv, repo-local .venv, PATH.
#
# Finding .venv without it being activated is the point: Homebrew's and Debian's
# python3 are externally managed (PEP 668), so PyYAML and jsonschema can only
# live in a venv, and every entry point here is documented as runnable on its
# own. Requiring an activate step first made that a lie.
resolve_python() {
	if [ -n "$DOTFILES_PYTHON" ]; then
		PY="$DOTFILES_PYTHON"
	elif [ -n "$VIRTUAL_ENV" ] && [ -x "$VIRTUAL_ENV/bin/python3" ]; then
		PY="$VIRTUAL_ENV/bin/python3"
	elif [ -x "$DOTFILES_ROOT/.venv/bin/python3" ]; then
		PY="$DOTFILES_ROOT/.venv/bin/python3"
	else
		PY="python3"
	fi
}

# python_deps_hint: prints the fix for a python3 that cannot run the config tooling.
python_deps_hint() {
	echo "The config tooling needs PyYAML and jsonschema, and ${PY:-python3} does" >&2
	echo "not have them. From the repo root:" >&2
	echo "" >&2
	echo "    python3 -m venv .venv" >&2
	echo "    .venv/bin/python3 -m pip install -r tools/requirements.txt" >&2
	echo "" >&2
	echo "These scripts use .venv automatically; activating it is optional." >&2
	echo "Then re-run this script. See README.md, \"Install the Python dependencies\"." >&2
}

# require_python_deps: checks that an interpreter exists and can import what
# load_config.py and validate_config.py need.
# Returns 1 with an actionable message if it cannot.
require_python_deps() {
	resolve_python

	if ! command -v "$PY" >/dev/null 2>&1; then
		echo "Error: python3 is not on PATH." >&2
		python_deps_hint
		return 1
	fi

	local missing
	if ! missing="$("$PY" -c 'import importlib.util as u; print(" ".join(m for m in ("yaml", "jsonschema") if u.find_spec(m) is None))' 2>/dev/null)"; then
		echo "Error: $PY is on PATH but failed to run." >&2
		python_deps_hint
		return 1
	fi

	if [ -n "$missing" ]; then
		echo "Error: $PY is missing required module(s): $missing" >&2
		python_deps_hint
		return 1
	fi

	return 0
}

# load_config_array: runs a load_config.py invocation that assigns a bash array
# and checks that it worked, instead of eval-ing whatever came back.
# Args: $1 = project root, $2 = name of the array the call should set,
#       $3.. = arguments passed through to load_config.py
# Returns 1 if the loader failed or did not set the named array. The array is
# unset first, so a caller that ignores the return code cannot read a stale one.
load_config_array() {
	local script_dir="$1"
	local var_name="$2"
	shift 2
	local output

	unset "$var_name"
	resolve_python

	if ! output="$("$PY" "$script_dir/tools/load_config.py" "$@")"; then
		echo "Error: tools/load_config.py $* failed; could not read config/." >&2
		require_python_deps >/dev/null 2>&1 || python_deps_hint
		return 1
	fi

	eval "$output"

	# An empty array is a legitimate answer -- a set can list no casks. Never
	# having been assigned is not, and used to leave the caller iterating over
	# whatever the variable held before.
	if ! declare -p "$var_name" >/dev/null 2>&1; then
		echo "Error: tools/load_config.py $* did not set $var_name." >&2
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
	resolve_python

	# The exit code of load_config.py used to vanish into the command
	# substitution, so any failure -- a missing PyYAML above all -- surfaced as
	# an empty array and the "No config sets found" message below, which blames
	# the config for a broken interpreter.
	if ! output="$("$PY" "$script_dir/tools/load_config.py" --list-sets)"; then
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
	resolve_python

	# Same swallowed-exit-code problem as discover_sets above: a failure here
	# used to leave HAS_PLATFORM holding whatever the last call set.
	if ! output="$("$PY" "$script_dir/tools/load_config.py" --set "$set_name" --check-platform "$platform")"; then
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
	resolve_python
	output="$("$PY" "$script_dir/tools/validate_config.py" 2>&1)"
	local rc=$?
	if [ $rc -ne 0 ]; then
		echo "$output" >&2
	fi
	return $rc
}
