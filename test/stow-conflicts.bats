#!/usr/bin/env bats
#
# Tests for tools/stow_conflicts.sh - the interactive "which copy wins?"
# layer that sits between stow-packages.sh and GNU Stow.
#
# The parsing/diff/prompt tests are pure and always run. The end-to-end
# stow_package tests need a real `stow` on PATH and skip without one, the
# same way the nushell vendor-autoload tests skip when their tools are absent.

setup() {
    load test_helper
    source "${PROJECT_ROOT}/tools/stow_conflicts.sh"

    SANDBOX="$(mktemp -d)"
    STOW_DIR="$SANDBOX/stow"
    TARGET_DIR="$SANDBOX/home"
    mkdir -p "$STOW_DIR/pkg" "$TARGET_DIR"

    # Never inherit the developer's terminal or policy into a test.
    STOW_TTY="$SANDBOX/no-such-tty"
    STOW_CONFLICT_POLICY="ask"
    STOW_DIFF_PREVIEW_LINES=20
}

teardown() {
    [ -n "$SANDBOX" ] && rm -rf "$SANDBOX"
}

require_stow() {
    command -v stow >/dev/null 2>&1 || skip "GNU Stow is not installed"
}

# answers TEXT...: writes one answer per argument to a file and points
# STOW_TTY at it, standing in for the user typing at a terminal.
answers() {
    printf '%s\n' "$@" >"$SANDBOX/answers"
    STOW_TTY="$SANDBOX/answers"
}

# --- Conflict parsing ---

@test "stow_parse_conflicts reads the 'cannot stow over existing target' form" {
    stow_parse_conflicts "  * cannot stow ../stow/pkg/dot-zshrc over existing target .zshrc since neither a link nor a directory and --adopt not specified"
    assert_array_length STOW_CONFLICT_TARGETS 1
    assert_array_contains STOW_CONFLICT_TARGETS ".zshrc"
}

@test "stow_parse_conflicts reads the 'not owned by stow' form" {
    stow_parse_conflicts "  * existing target is not owned by stow: .config/nvim/init.lua"
    assert_array_contains STOW_CONFLICT_TARGETS ".config/nvim/init.lua"
}

@test "stow_parse_conflicts reads the 'stowed to a different package' form" {
    stow_parse_conflicts "  * existing target is stowed to a different package: .zshrc => ../other/dot-zshrc"
    assert_array_contains STOW_CONFLICT_TARGETS ".zshrc"
}

@test "stow_parse_conflicts collects every conflict in the output" {
    stow_parse_conflicts "WARNING! stowing pkg would cause conflicts:
  * cannot stow ../stow/pkg/dot-a over existing target .a since neither a link nor a directory and --adopt not specified
  * cannot stow ../stow/pkg/dot-b over existing target .b since neither a link nor a directory and --adopt not specified
All operations aborted."
    assert_array_length STOW_CONFLICT_TARGETS 2
    assert_array_contains STOW_CONFLICT_TARGETS ".a"
    assert_array_contains STOW_CONFLICT_TARGETS ".b"
}

@test "stow_parse_conflicts ignores ordinary progress output" {
    stow_parse_conflicts "LINK: .zshrc => ../stow/pkg/dot-zshrc
MKDIR: .config"
    assert_array_length STOW_CONFLICT_TARGETS 0
}

# --- Mapping a target back to the repo file ---

@test "stow_source_for_target maps a dot- prefixed package file" {
    touch "$STOW_DIR/pkg/dot-zshrc"
    run stow_source_for_target "$STOW_DIR/pkg" ".zshrc"
    assert_success
    assert_output "$STOW_DIR/pkg/dot-zshrc"
}

@test "stow_source_for_target maps a literal dotfile in the package" {
    touch "$STOW_DIR/pkg/.zshrc"
    run stow_source_for_target "$STOW_DIR/pkg" ".zshrc"
    assert_success
    assert_output "$STOW_DIR/pkg/.zshrc"
}

@test "stow_source_for_target walks nested paths one component at a time" {
    mkdir -p "$STOW_DIR/pkg/dot-config/nvim"
    touch "$STOW_DIR/pkg/dot-config/nvim/init.lua"
    run stow_source_for_target "$STOW_DIR/pkg" ".config/nvim/init.lua"
    assert_success
    assert_output "$STOW_DIR/pkg/dot-config/nvim/init.lua"
}

@test "stow_source_for_target fails when the package has no such file" {
    run stow_source_for_target "$STOW_DIR/pkg" ".nope"
    assert_failure
}

# --- Diff summary ---

@test "stow_summarize_conflict counts the lines on each side" {
    printf 'a\nOLD\nc\n' >"$TARGET_DIR/.f"
    printf 'a\nNEW\nc\n' >"$STOW_DIR/pkg/dot-f"
    run stow_summarize_conflict "$TARGET_DIR/.f" "$STOW_DIR/pkg/dot-f"
    assert_output --partial "1 line(s) only in the repo version, 1 only in the existing file"
    assert_output --partial "-OLD"
    assert_output --partial "+NEW"
}

@test "stow_summarize_conflict says so when the two files match" {
    printf 'same\n' >"$TARGET_DIR/.f"
    printf 'same\n' >"$STOW_DIR/pkg/dot-f"
    run stow_summarize_conflict "$TARGET_DIR/.f" "$STOW_DIR/pkg/dot-f"
    assert_output --partial "contents are identical"
}

@test "stow_summarize_conflict truncates a long diff to the preview length" {
    seq 1 100 >"$TARGET_DIR/.f"
    seq 101 200 >"$STOW_DIR/pkg/dot-f"
    STOW_DIFF_PREVIEW_LINES=5
    run stow_summarize_conflict "$TARGET_DIR/.f" "$STOW_DIR/pkg/dot-f"
    assert_output --partial "more diff line(s)"
}

@test "stow_summarize_conflict handles a directory on one side" {
    printf 'file\n' >"$TARGET_DIR/.f"
    mkdir -p "$STOW_DIR/pkg/dot-f"
    run stow_summarize_conflict "$TARGET_DIR/.f" "$STOW_DIR/pkg/dot-f"
    assert_output --partial "no line diff available"
}

@test "stow_summarize_conflict reports where an existing symlink points" {
    printf 'elsewhere\n' >"$SANDBOX/elsewhere"
    ln -s "$SANDBOX/elsewhere" "$TARGET_DIR/.f"
    printf 'repo\n' >"$STOW_DIR/pkg/dot-f"
    run stow_summarize_conflict "$TARGET_DIR/.f" "$STOW_DIR/pkg/dot-f"
    assert_output --partial "(symlink)"
    assert_output --partial "-> $SANDBOX/elsewhere"
}

@test "stow_summarize_conflict copes with an unresolvable repo file" {
    printf 'file\n' >"$TARGET_DIR/.f"
    run stow_summarize_conflict "$TARGET_DIR/.f" ""
    assert_output --partial "could not be located"
}

# --- Prompting ---

@test "stow_ask honours a 'new' policy without prompting" {
    STOW_CONFLICT_POLICY=new
    run stow_ask "$TARGET_DIR/.f" "$STOW_DIR/pkg/dot-f"
    assert_output "new"
}

@test "stow_ask honours an 'existing' policy without prompting" {
    STOW_CONFLICT_POLICY=existing
    run stow_ask "$TARGET_DIR/.f" "$STOW_DIR/pkg/dot-f"
    assert_output "existing"
}

@test "stow_ask keeps the existing file when there is nobody to ask" {
    stow_ask "$TARGET_DIR/.f" "$STOW_DIR/pkg/dot-f" >"$SANDBOX/out" 2>/dev/null 9</dev/null
    assert_equal "$(cat "$SANDBOX/out")" "existing"
}

@test "stow_ask reads 'n' as the repo version" {
    answers n
    stow_ask "$TARGET_DIR/.f" "$STOW_DIR/pkg/dot-f" >"$SANDBOX/out" 2>/dev/null 9<"$STOW_TTY"
    assert_equal "$(cat "$SANDBOX/out")" "new"
}

@test "stow_ask reads 'e' as the existing file" {
    answers e
    stow_ask "$TARGET_DIR/.f" "$STOW_DIR/pkg/dot-f" >"$SANDBOX/out" 2>/dev/null 9<"$STOW_TTY"
    assert_equal "$(cat "$SANDBOX/out")" "existing"
}

@test "stow_ask reads 'q' as quit" {
    answers q
    stow_ask "$TARGET_DIR/.f" "$STOW_DIR/pkg/dot-f" >"$SANDBOX/out" 2>/dev/null 9<"$STOW_TTY"
    assert_equal "$(cat "$SANDBOX/out")" "quit"
}

@test "stow_ask re-prompts after an unrecognised answer" {
    answers "yes please" n
    stow_ask "$TARGET_DIR/.f" "$STOW_DIR/pkg/dot-f" >"$SANDBOX/out" 2>"$SANDBOX/err" 9<"$STOW_TTY"
    assert_equal "$(cat "$SANDBOX/out")" "new"
    run cat "$SANDBOX/err"
    assert_output --partial "Please answer n, e, d or q."
}

@test "stow_ask shows the full diff on 'd' and keeps asking" {
    printf 'a\nOLD\n' >"$TARGET_DIR/.f"
    printf 'a\nNEW\n' >"$STOW_DIR/pkg/dot-f"
    answers d e
    stow_ask "$TARGET_DIR/.f" "$STOW_DIR/pkg/dot-f" >"$SANDBOX/out" 2>"$SANDBOX/err" 9<"$STOW_TTY"
    assert_equal "$(cat "$SANDBOX/out")" "existing"
    run cat "$SANDBOX/err"
    assert_output --partial "+NEW"
}

# --- Applying a decision ---

@test "stow_resolve_conflict backs the existing file up when the repo wins" {
    printf 'mine\n' >"$TARGET_DIR/.f"
    printf 'theirs\n' >"$STOW_DIR/pkg/dot-f"
    STOW_CONFLICT_POLICY=new
    run stow_resolve_conflict "$TARGET_DIR/.f" "$STOW_DIR/pkg/dot-f"
    [ "$status" -eq 0 ]
    assert_output --partial "Backed up existing file to"
    [ ! -e "$TARGET_DIR/.f" ]
    [ "$(cat "$TARGET_DIR"/.f.stow-backup-*)" = "mine" ]
}

@test "stow_resolve_conflict never overwrites an earlier backup" {
    printf 'mine\n' >"$TARGET_DIR/.f"
    printf 'theirs\n' >"$STOW_DIR/pkg/dot-f"
    STOW_CONFLICT_POLICY=new
    stow_resolve_conflict "$TARGET_DIR/.f" "$STOW_DIR/pkg/dot-f"
    printf 'mine again\n' >"$TARGET_DIR/.f"
    stow_resolve_conflict "$TARGET_DIR/.f" "$STOW_DIR/pkg/dot-f"
    assert_equal "$(ls -A "$TARGET_DIR" | grep -c stow-backup)" "2"
}

@test "stow_resolve_conflict sets the existing file aside when it wins" {
    printf 'mine\n' >"$TARGET_DIR/.f"
    printf 'theirs\n' >"$STOW_DIR/pkg/dot-f"
    STOW_CONFLICT_POLICY=existing
    # Returns 1 for "the existing file won", which is not a failure.
    stow_resolve_conflict "$TARGET_DIR/.f" "$STOW_DIR/pkg/dot-f" || true
    assert_array_contains STOW_KEPT_TARGETS "$TARGET_DIR/.f"
    [ ! -e "$TARGET_DIR/.f" ]
}

@test "stow_restore_kept puts the kept file back over stow's symlink" {
    printf 'mine\n' >"$TARGET_DIR/.f"
    printf 'theirs\n' >"$STOW_DIR/pkg/dot-f"
    STOW_CONFLICT_POLICY=existing
    stow_resolve_conflict "$TARGET_DIR/.f" "$STOW_DIR/pkg/dot-f" || true
    ln -s "$STOW_DIR/pkg/dot-f" "$TARGET_DIR/.f"

    stow_restore_kept
    [ ! -L "$TARGET_DIR/.f" ]
    assert_equal "$(cat "$TARGET_DIR/.f")" "mine"
    assert_array_length STOW_KEPT_TARGETS 0
}

# --- End to end ---

@test "stow_package links a clean package without asking anything" {
    require_stow
    printf 'repo\n' >"$STOW_DIR/pkg/dot-f"
    run stow_package "$STOW_DIR" "$TARGET_DIR" pkg
    assert_success
    refute_output --partial "Conflict on"
    [ -L "$TARGET_DIR/.f" ]
}

@test "stow_package backs up the existing file when the repo version wins" {
    require_stow
    printf 'mine\n' >"$TARGET_DIR/.f"
    printf 'theirs\n' >"$STOW_DIR/pkg/dot-f"
    answers n
    run stow_package "$STOW_DIR" "$TARGET_DIR" pkg
    assert_success
    [ -L "$TARGET_DIR/.f" ]
    assert_equal "$(cat "$TARGET_DIR/.f")" "theirs"
    assert_equal "$(cat "$TARGET_DIR"/.f.stow-backup-*)" "mine"
}

@test "stow_package skips only the file the existing copy won" {
    require_stow
    printf 'mine\n' >"$TARGET_DIR/.f"
    printf 'theirs\n' >"$STOW_DIR/pkg/dot-f"
    printf 'other\n' >"$STOW_DIR/pkg/dot-g"
    answers e
    run stow_package "$STOW_DIR" "$TARGET_DIR" pkg
    assert_success
    [ ! -L "$TARGET_DIR/.f" ]
    assert_equal "$(cat "$TARGET_DIR/.f")" "mine"
    [ -L "$TARGET_DIR/.g" ]
    [ -z "$(ls -A "$TARGET_DIR" | grep stow-keep || true)" ]
}

@test "stow_package resolves several conflicts in one pass" {
    require_stow
    printf 'mine-f\n' >"$TARGET_DIR/.f"
    printf 'mine-g\n' >"$TARGET_DIR/.g"
    printf 'theirs-f\n' >"$STOW_DIR/pkg/dot-f"
    printf 'theirs-g\n' >"$STOW_DIR/pkg/dot-g"
    answers n e
    run stow_package "$STOW_DIR" "$TARGET_DIR" pkg
    assert_success
    assert_equal "$(cat "$TARGET_DIR/.f")" "theirs-f"
    assert_equal "$(cat "$TARGET_DIR/.g")" "mine-g"
}

@test "stow_package returns 2 and touches nothing when the user quits" {
    require_stow
    printf 'mine\n' >"$TARGET_DIR/.f"
    printf 'theirs\n' >"$STOW_DIR/pkg/dot-f"
    printf 'other\n' >"$STOW_DIR/pkg/dot-g"
    answers q
    run stow_package "$STOW_DIR" "$TARGET_DIR" pkg
    [ "$status" -eq 2 ]
    assert_equal "$(cat "$TARGET_DIR/.f")" "mine"
    [ ! -e "$TARGET_DIR/.g" ]
}

@test "stow_package is idempotent once the links exist" {
    require_stow
    printf 'repo\n' >"$STOW_DIR/pkg/dot-f"
    stow_package "$STOW_DIR" "$TARGET_DIR" pkg
    run stow_package "$STOW_DIR" "$TARGET_DIR" pkg
    assert_success
    refute_output --partial "Conflict on"
}

@test "stow_package keeps skipping a file that keeps winning" {
    require_stow
    printf 'mine\n' >"$TARGET_DIR/.f"
    printf 'theirs\n' >"$STOW_DIR/pkg/dot-f"
    answers e
    stow_package "$STOW_DIR" "$TARGET_DIR" pkg
    answers e
    run stow_package "$STOW_DIR" "$TARGET_DIR" pkg
    assert_success
    assert_equal "$(cat "$TARGET_DIR/.f")" "mine"
}

# --- Availability check ---

@test "stow_require succeeds when stow is on PATH" {
    stow_available() { return 0; }
    run stow_require
    assert_success
    assert_output ""
}

@test "stow_require explains how to install a missing stow" {
    stow_available() { return 1; }
    run stow_require
    assert_failure
    assert_output --partial "GNU Stow is not installed"
    assert_output --partial "apt-get install stow"
}
