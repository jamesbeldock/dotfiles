# env.nu — loaded before config.nu

# Homebrew + Ruby + coreutils PATH (mirrors .zshrc PATH setup)
if ("/opt/homebrew/bin/brew" | path exists) {
    $env.HOMEBREW_NO_ENV_HINTS = "1"
    let coreutils_gnubin = (^/opt/homebrew/bin/brew --prefix coreutils | str trim | path join "libexec/gnubin")
    $env.PATH = (
        $env.PATH
        | prepend [
            $coreutils_gnubin
            "/opt/homebrew/opt/ruby/bin"
            "/opt/homebrew/sbin"
            "/opt/homebrew/bin"
        ]
        | uniq
    )
}

# Antigravity
$env.PATH = ($env.PATH | append "/Users/j/.antigravity/antigravity/bin" | uniq)

# Editor, locale, misc
$env.EDITOR = "nvim"
$env.LANG = "en_US.UTF-8"
$env.LC_ALL = "en_US.UTF-8"
$env.PYTHONIOENCODING = "UTF-8"
$env.MANPAGER = "less -X"
# Only set GPG_TTY when stdin is actually a tty (skips scripted nu invocations)
let tty_out = (do { ^tty } | complete)
if $tty_out.exit_code == 0 {
    $env.GPG_TTY = ($tty_out.stdout | str trim)
}

# Generate vendor autoload files for external tool integrations.
# Files dropped in this dir are auto-sourced by nushell on startup.
# Delete a file to force regeneration (e.g. after upgrading the tool).
let autoload_dir = ($nu.data-dir | path join "vendor/autoload")
mkdir $autoload_dir

let starship_file = ($autoload_dir | path join "starship.nu")
if not ($starship_file | path exists) and (which starship | is-not-empty) {
    ^starship init nu | save -f $starship_file
}

let zoxide_file = ($autoload_dir | path join "zoxide.nu")
if not ($zoxide_file | path exists) and (which zoxide | is-not-empty) {
    ^zoxide init nushell | save -f $zoxide_file
}

let atuin_file = ($autoload_dir | path join "atuin.nu")
if not ($atuin_file | path exists) and (which atuin | is-not-empty) {
    ^atuin init nu | save -f $atuin_file
}
