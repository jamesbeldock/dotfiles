#!/usr/bin/env bats
#
# Sanity checks for the `nushell` stow package: confirms the on-disk
# layout, that env.nu/config.nu carry the load-bearing pieces from the
# zsh port, and (when `nu` is available) that both files parse.

setup() {
    load test_helper
    NUSHELL_DIR="${PROJECT_ROOT}/nushell/Library/Application Support/nushell"
    ENV_NU="${NUSHELL_DIR}/env.nu"
    CONFIG_NU="${NUSHELL_DIR}/config.nu"
}

# --- Layout ---

@test "nushell package directory exists" {
    [ -d "$NUSHELL_DIR" ]
}

@test "env.nu exists and is non-empty" {
    [ -s "$ENV_NU" ]
}

@test "config.nu exists and is non-empty" {
    [ -s "$CONFIG_NU" ]
}

@test "package contains exactly the two managed nu files" {
    run find "$NUSHELL_DIR" -maxdepth 1 -type f -name '*.nu'
    assert_success
    # Two lines, one per file
    [ "$(echo "$output" | wc -l | tr -d ' ')" -eq 2 ]
}

# --- env.nu content ---

@test "env.nu sets up the homebrew PATH" {
    grep -q "/opt/homebrew/bin" "$ENV_NU"
}

@test "env.nu sets EDITOR to nvim" {
    grep -qE '\$env\.EDITOR\s*=\s*"nvim"' "$ENV_NU"
}

@test "env.nu guards GPG_TTY against non-tty stdin" {
    # The literal `^tty` call must be wrapped in `do { ... } | complete`
    # so non-interactive nu invocations don't fail.
    grep -q "do { \^tty } | complete" "$ENV_NU"
}

@test "env.nu wires up vendor autoload for starship, atuin, zoxide" {
    grep -q 'starship init nu' "$ENV_NU"
    grep -q 'zoxide init nushell' "$ENV_NU"
    grep -q 'atuin init nu' "$ENV_NU"
}

# --- config.nu content ---

@test "config.nu auto-launches tmux on interactive shells" {
    grep -q 'exec tmux' "$CONFIG_NU"
    grep -q '\$nu.is-interactive' "$CONFIG_NU"
}

@test "config.nu defines all ported functions" {
    for cmd in mkd cdf fs o tre digga gz getcertnames targz; do
        grep -qE "^def (--env )?${cmd} " "$CONFIG_NU" \
            || { echo "Missing command: $cmd" >&2; return 1; }
    done
}

@test "config.nu defines vim/nuconfig/nuenv aliases" {
    grep -qE '^alias vim\s*=\s*nvim' "$CONFIG_NU"
    grep -qE '^alias nuconfig\s*=' "$CONFIG_NU"
    grep -qE '^alias nuenv\s*=' "$CONFIG_NU"
}

@test "config.nu does NOT alias ls (would clobber nu's structured ls)" {
    ! grep -qE '^alias ls\s*=' "$CONFIG_NU"
}

@test "config.nu does NOT alias cat (would clobber nu pipelines)" {
    ! grep -qE '^alias cat\s*=' "$CONFIG_NU"
}

@test "config.nu suppresses nu's startup banner" {
    grep -qE '\$env\.config\.show_banner\s*=\s*false' "$CONFIG_NU"
}

@test "config.nu runs fastfetch on interactive startup" {
    grep -q 'fastfetch' "$CONFIG_NU"
    # Must be guarded by interactive check
    grep -q '\$nu.is-interactive.*fastfetch\|fastfetch.*\$nu.is-interactive' "$CONFIG_NU" \
        || grep -B1 'fastfetch' "$CONFIG_NU" | grep -q 'is-interactive'
}

# --- Live syntax check (skipped when nu unavailable) ---

@test "env.nu parses cleanly under nu" {
    if ! command -v nu &> /dev/null; then
        skip "nu not installed"
    fi
    run nu --no-config-file -c "source \"$ENV_NU\"; print OK" < /dev/null
    assert_success
    assert_output --partial "OK"
}

@test "config.nu parses cleanly under nu" {
    if ! command -v nu &> /dev/null; then
        skip "nu not installed"
    fi
    # Source env first so PATH and helpers are populated; config.nu may
    # call `exec tmux` only inside an interactive shell, so this
    # non-interactive run skips that branch.
    run nu --no-config-file -c "source \"$ENV_NU\"; source \"$CONFIG_NU\"; print OK" < /dev/null
    assert_success
    assert_output --partial "OK"
}
