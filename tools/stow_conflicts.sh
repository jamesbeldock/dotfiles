#!/bin/bash
# tools/stow_conflicts.sh - Interactive conflict resolution for GNU Stow.
# Source this file from scripts: source "$SCRIPT_DIR/tools/stow_conflicts.sh"
#
# Plain `stow` aborts a whole package the moment it finds a real file sitting
# where a symlink should go. `stow_package` instead asks stow to simulate the
# run, summarises the diff between each blocked target and the repo file it
# would be replaced by, and lets you pick a winner per file:
#
#   new      - rename the existing file to <file>.stow-backup-<timestamp>,
#              then let stow link the repo version over it
#   existing - leave your file alone and skip just that one link
#
# Knobs (all environment variables):
#   STOW_CONFLICT_POLICY    ask (default) | new | existing
#                           Non-interactive runs fall back to "existing".
#   STOW_DIFF_PREVIEW_LINES how many diff lines to show inline (default 20)
#   STOW_TTY                where to read answers from (default /dev/tty)

STOW_CONFLICT_POLICY="${STOW_CONFLICT_POLICY:-ask}"
STOW_DIFF_PREVIEW_LINES="${STOW_DIFF_PREVIEW_LINES:-20}"
STOW_TTY="${STOW_TTY:-/dev/tty}"

# Targets whose existing file the user chose to keep, plus the temporary paths
# those files are parked at while stow runs. Parallel arrays.
STOW_KEPT_TARGETS=()
STOW_KEPT_STASHES=()

# stow_available: true when GNU Stow is on PATH.
# A function so callers can check once instead of letting every package fail,
# and so tests can stub it.
stow_available() {
	command -v stow >/dev/null 2>&1
}

# stow_require: prints an actionable message and returns 1 if stow is missing.
# Args: candidate stow paths to check before declaring it uninstalled
#       (defaults to the Homebrew and Linuxbrew prefixes).
stow_require() {
	if stow_available; then
		return 0
	fi
	echo "GNU Stow is not on PATH, so nothing can be symlinked." >&2

	# "Not on PATH" and "not installed" need different fixes, and a
	# brew-installed stow is invisible to a shell that never loaded Homebrew.
	local candidates=("$@")
	if [ ${#candidates[@]} -eq 0 ]; then
		candidates=(
			/opt/homebrew/bin/stow
			/usr/local/bin/stow
			/home/linuxbrew/.linuxbrew/bin/stow
		)
	fi

	local candidate
	for candidate in "${candidates[@]}"; do
		if [ -x "$candidate" ]; then
			echo "It is installed at $candidate, just not on PATH." >&2
			echo 'Load Homebrew first: eval "$(brew shellenv)"' >&2
			return 1
		fi
	done

	echo "Install it (brew install stow, or apt-get install stow) and re-run." >&2
	return 1
}

# stow_simulate: dry-runs stow and prints its combined output.
# Args: $1 = stow dir, $2 = target dir, $3 = package
# Returns stow's exit code (non-zero when it would hit a conflict).
stow_simulate() {
	stow -n -v -d "$1" -t "$2" --dotfiles "$3" 2>&1
}

# stow_parse_conflicts: populates STOW_CONFLICT_TARGETS from stow's output.
# Each entry is a target path relative to the target directory.
# Args: $1 = stow output
stow_parse_conflicts() {
	STOW_CONFLICT_TARGETS=()
	local line target
	while IFS= read -r line; do
		case "$line" in
			*"cannot stow "*" over existing target "*)
				target="${line#*over existing target }"
				target="${target% since*}"
				;;
			*"existing target is not owned by stow: "*)
				target="${line##*existing target is not owned by stow: }"
				;;
			*"existing target is neither a link nor a directory: "*)
				target="${line##*existing target is neither a link nor a directory: }"
				;;
			*"existing target is stowed to a different package: "*)
				target="${line##*existing target is stowed to a different package: }"
				target="${target% =>*}"
				;;
			*)
				continue
				;;
		esac
		if [ -n "$target" ]; then
			STOW_CONFLICT_TARGETS+=("$target")
		fi
	done <<<"$1"
}

# stow_source_for_target: finds the package file that would land on a target.
# Walks the target path component by component, trying both the literal name
# and the --dotfiles spelling (".foo" in the target is "dot-foo" in the repo).
# Args: $1 = package directory, $2 = target path relative to the target dir
# Prints the package path, or nothing (returns 1) if it cannot be resolved.
stow_source_for_target() {
	local current="$1"
	local remaining="$2"
	local part
	while [ -n "$remaining" ]; do
		part="${remaining%%/*}"
		if [ "$part" = "$remaining" ]; then
			remaining=""
		else
			remaining="${remaining#*/}"
		fi
		[ -z "$part" ] && continue
		if [ -e "$current/$part" ] || [ -L "$current/$part" ]; then
			current="$current/$part"
		elif [ -e "$current/dot-${part#.}" ] || [ -L "$current/dot-${part#.}" ]; then
			current="$current/dot-${part#.}"
		else
			return 1
		fi
	done
	printf '%s\n' "$current"
}

# stow_file_kind: prints "directory", "symlink", "file" or "nothing".
stow_file_kind() {
	if [ -L "$1" ]; then
		echo "symlink"
	elif [ -d "$1" ]; then
		echo "directory"
	elif [ -e "$1" ]; then
		echo "file"
	else
		echo "nothing"
	fi
}

# stow_diff_text: prints the full unified diff between two files.
stow_diff_text() {
	command diff -u "$1" "$2" 2>&1
}

# stow_summarize_conflict: prints a short description of how the two files
# differ, followed by the first STOW_DIFF_PREVIEW_LINES lines of the diff.
# Args: $1 = existing target, $2 = repo file ("" if it could not be resolved)
stow_summarize_conflict() {
	local existing="$1" incoming="$2"

	echo "  existing: $existing ($(stow_file_kind "$existing"))"
	if [ -L "$existing" ]; then
		echo "            -> $(readlink "$existing")"
	fi
	if [ -z "$incoming" ]; then
		echo "  repo:     (could not be located; no diff available)"
		return
	fi
	echo "  repo:     $incoming ($(stow_file_kind "$incoming"))"

	if [ ! -f "$existing" ] || [ ! -f "$incoming" ]; then
		echo "  diff:     not two regular files; no line diff available"
		return
	fi
	if command cmp -s "$existing" "$incoming"; then
		echo "  diff:     contents are identical"
		return
	fi

	local diff_out
	# `diff` exits 1 for "they differ", which is the whole point here.
	diff_out="$(stow_diff_text "$existing" "$incoming")" || true
	case "$diff_out" in
		"Binary files "*)
			echo "  diff:     binary files differ"
			return
			;;
	esac

	local counts added removed total
	counts="$(printf '%s\n' "$diff_out" |
		awk '/^\+\+\+/ || /^---/ { next } /^\+/ { a++ } /^-/ { d++ } END { print a + 0, d + 0 }')"
	added="${counts%% *}"
	removed="${counts##* }"
	echo "  diff:     $added line(s) only in the repo version, $removed only in the existing file"

	total="$(printf '%s\n' "$diff_out" | wc -l | tr -d ' ')"
	printf '%s\n' "$diff_out" | head -n "$STOW_DIFF_PREVIEW_LINES" | sed 's/^/  | /'
	if [ "$total" -gt "$STOW_DIFF_PREVIEW_LINES" ]; then
		echo "  | ... $((total - STOW_DIFF_PREVIEW_LINES)) more diff line(s)"
	fi
}

# stow_ask: prompts for a conflict decision and echoes new|existing|quit.
# Reads answers from file descriptor 9, which stow_package holds open for the
# whole run; anything that cannot be read (no terminal, end of input) means
# "leave the existing file alone", which is the safe answer. Prompts and diffs
# go to stderr so stdout carries nothing but the decision.
# Args: $1 = existing target, $2 = repo file
stow_ask() {
	local existing="$1" incoming="$2"

	case "$STOW_CONFLICT_POLICY" in
		ask) ;;
		new)
			echo "new"
			return 0
			;;
		*)
			echo "existing"
			return 0
			;;
	esac

	local reply answer=""
	while [ -z "$answer" ]; do
		printf '  Keep [n]ew from repo, [e]xisting file, show full [d]iff, or [q]uit? ' >&2
		if ! read -r reply <&9 2>/dev/null; then
			answer="existing"
			break
		fi
		case "$(printf '%s' "$reply" | tr '[:upper:]' '[:lower:]')" in
			n | new) answer="new" ;;
			e | existing | s | skip) answer="existing" ;;
			q | quit) answer="quit" ;;
			d | diff)
				if [ -n "$incoming" ] && [ -f "$existing" ] && [ -f "$incoming" ]; then
					stow_diff_text "$existing" "$incoming" | sed 's/^/  | /' >&2
				else
					echo "  (no diff available for this pair)" >&2
				fi
				;;
			*)
				echo "  Please answer n, e, d or q." >&2
				;;
		esac
	done

	echo "$answer"
}

# stow_unique_path: prints $1 with a numeric suffix appended if needed so that
# nothing exists at the returned path.
stow_unique_path() {
	local candidate="$1"
	local n=1
	while [ -e "$candidate" ] || [ -L "$candidate" ]; do
		candidate="$1.$n"
		n=$((n + 1))
	done
	printf '%s\n' "$candidate"
}

# stow_resolve_conflict: shows the diff, asks, and moves files out of the way.
# Args: $1 = existing target, $2 = repo file ("" if unresolved)
# Returns 0 = use the repo version (existing backed up)
#         1 = keep the existing file (stashed until stow has run)
#         2 = user quit
#         3 = nothing could be done
stow_resolve_conflict() {
	local existing="$1" incoming="$2"

	echo
	echo "Conflict on $existing"
	stow_summarize_conflict "$existing" "$incoming"

	local choice backup stash
	choice="$(stow_ask "$existing" "$incoming")"
	case "$choice" in
		new)
			backup="$(stow_unique_path "$existing.stow-backup-$(date +%Y%m%d%H%M%S)")"
			if ! mv "$existing" "$backup"; then
				echo "  Could not back up $existing; leaving it in place." >&2
				return 3
			fi
			echo "  Backed up existing file to $backup; linking the repo version."
			return 0
			;;
		quit)
			return 2
			;;
		*)
			stash="$(stow_unique_path "$existing.stow-keep-$$")"
			if ! mv "$existing" "$stash"; then
				echo "  Could not set $existing aside; leaving it in place." >&2
				return 3
			fi
			STOW_KEPT_TARGETS+=("$existing")
			STOW_KEPT_STASHES+=("$stash")
			echo "  Keeping the existing file; skipping this link."
			return 1
			;;
	esac
}

# stow_restore_kept: puts every "keep existing" file back, removing the symlink
# stow created in its place. Clears the bookkeeping arrays.
stow_restore_kept() {
	local i target stash
	i=0
	while [ $i -lt ${#STOW_KEPT_TARGETS[@]} ]; do
		target="${STOW_KEPT_TARGETS[$i]}"
		stash="${STOW_KEPT_STASHES[$i]}"
		if [ -L "$target" ]; then
			rm -f "$target"
		fi
		mv "$stash" "$target"
		i=$((i + 1))
	done
	STOW_KEPT_TARGETS=()
	STOW_KEPT_STASHES=()
}

# stow_package: stows one package, resolving conflicts interactively.
# Holds the answer stream open on fd 9 for the whole package: reopening it per
# question would re-read the first answer whenever STOW_TTY is a plain file.
# Args: $1 = stow dir, $2 = target dir, $3 = package
# Returns 0 on success, 1 on failure, 2 if the user asked to quit.
stow_package() {
	local rc

	# Ctrl-C between setting a kept file aside and putting it back would strand
	# it at <file>.stow-keep-<pid>, so restore before dying. This replaces any
	# INT/TERM trap the calling script had; neither of ours sets one.
	trap 'stow_restore_kept; exit 130' INT TERM

	# Probe rather than test -r: /dev/tty is readable by its permission bits
	# even on a session with no controlling terminal, where opening it fails.
	# stderr is redirected first so a failed probe stays quiet.
	if { true; } 2>/dev/null 9<"$STOW_TTY"; then
		stow_package_run "$@" 9<"$STOW_TTY" && rc=0 || rc=$?
	elif [ -t 0 ]; then
		stow_package_run "$@" 9<&0 && rc=0 || rc=$?
	else
		stow_package_run "$@" 9</dev/null && rc=0 || rc=$?
	fi

	trap - INT TERM
	return $rc
}

# stow_package_run: the body of stow_package, with fd 9 already open.
# Args and return codes are stow_package's.
stow_package_run() {
	local stow_dir="$1" target_dir="$2" package="$3"
	local pkg_dir="$stow_dir/$package"

	STOW_KEPT_TARGETS=()
	STOW_KEPT_STASHES=()

	# `if`/`&&` forms below keep this usable from scripts running under `set -e`.
	local attempt=0 sim rc rel incoming resolved decision
	rc=0
	while [ $attempt -lt 10 ]; do
		attempt=$((attempt + 1))
		if sim="$(stow_simulate "$stow_dir" "$target_dir" "$package")"; then
			rc=0
			break
		else
			rc=$?
		fi

		stow_parse_conflicts "$sim"
		if [ ${#STOW_CONFLICT_TARGETS[@]} -eq 0 ]; then
			# Not a conflict we know how to negotiate; show stow's own words.
			printf '%s\n' "$sim" >&2
			stow_restore_kept
			return 1
		fi

		resolved=0
		for rel in "${STOW_CONFLICT_TARGETS[@]}"; do
			incoming="$(stow_source_for_target "$pkg_dir" "$rel")" || incoming=""
			stow_resolve_conflict "$target_dir/$rel" "$incoming" && decision=0 || decision=$?
			case $decision in
				0 | 1) resolved=1 ;;
				2)
					stow_restore_kept
					return 2
					;;
			esac
		done

		if [ $resolved -eq 0 ]; then
			printf '%s\n' "$sim" >&2
			stow_restore_kept
			return 1
		fi
	done

	if [ "$rc" -ne 0 ]; then
		echo "Gave up resolving conflicts for '$package' after $attempt attempts." >&2
		stow_restore_kept
		return 1
	fi

	if ! stow -v -d "$stow_dir" -t "$target_dir" --dotfiles "$package"; then
		stow_restore_kept
		return 1
	fi

	stow_restore_kept
	return 0
}
