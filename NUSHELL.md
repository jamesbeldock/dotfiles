# Nushell port

This documents the port of the existing zsh setup into [nushell](https://www.nushell.sh/),
performed on 2026-05-22 against the workstation set.

## Layout

The `nushell` stow package mirrors the macOS default config location so
`stow nushell` produces:

```
~/Library/Application Support/nushell/config.nu  ->  nushell/Library/Application Support/nushell/config.nu
~/Library/Application Support/nushell/env.nu     ->  nushell/Library/Application Support/nushell/env.nu
```

`history.txt` and `vendor/autoload/` stay as real, machine-local files in
`~/Library/Application Support/nushell/` — only the two config files are
managed.

The package is macOS-only as written. On Linux, nushell looks at
`~/.config/nushell/` instead; if the package is needed on a Linux host
later, add a parallel `dot-config/nushell/` tree or set
`$XDG_CONFIG_HOME` so nushell resolves to the same path.

## Wiring

- `config/packages.yaml`
  - `nushell` added to the master `stow_packages` list
  - `nushell` formula added to the `james_tools` group so
    `brew install` picks it up alongside the rest of the dev toolchain
- `config/sets/workstation.yaml`
  - `nushell` added to `stow_packages`
  - Not added to `server`, `iot`, or `lxc` — add it there if/when those
    hosts grow a nushell setup

`stow-packages.sh` itself needed no changes: it iterates whatever the
selected set's `stow_packages` array contains.

## What was carried over from `.zshrc`

Sourced from `zsh/.zshrc`, `basic/dot-aliases`, `basic/dot-exports`, and
`basic/dot-functions`.

**`env.nu`**
- Homebrew + Ruby + coreutils gnubin PATH, plus `HOMEBREW_NO_ENV_HINTS=1`
- Antigravity PATH
- `EDITOR=nvim`, `LANG`, `LC_ALL`, `PYTHONIOENCODING`, `MANPAGER`
- `GPG_TTY` — guarded with `do | complete` so non-interactive `nu`
  invocations (scripts, subshells with no tty on stdin) don't crash on
  the `tty` call
- Lazy generation of `vendor/autoload/{starship,atuin,zoxide}.nu`. These
  drop into nushell's autoload dir, so the next interactive shell picks
  them up. Delete a file to force regeneration after upgrading the tool.

**`config.nu`**
- Auto-launch tmux on interactive shells outside of tmux (mirrors
  `.zshrc`). Guarded by `$nu.is-interactive`, so scripts aren't replaced
  by tmux.
- Aliases: `vim = nvim`, `nuconfig`, `nuenv` (analogues of `zshconfig` /
  `ohmyzsh`)
- Translated functions: `mkd`, `cdf`, `fs`, `o`, `tre`, `digga`, `gz`,
  `getcertnames`, `targz`
- `fastfetch` on interactive startup

## What was *not* carried over

### Already handled natively by nushell
- `zsh-autosuggestions`, `zsh-syntax-highlighting`, `zsh-completions` —
  nushell ships these
- `z` plugin — already replaced by zoxide
- `ENABLE_CORRECTION` (oh-my-zsh spelling correction) — nushell's hinter
  covers the same ground

### zsh-specific / no nushell analogue
- `oh-my-zsh`, `zinit`, and every oh-my-zsh plugin (`git`, `docker`,
  `docker-compose`, `extract`, `sudo`, `colored-man-pages`, `aliases`,
  `fzf`, `1password-zsh-plugin`) — these are zsh-framework constructs
- `~/.iterm2_shell_integration.zsh` — zsh script. iTerm2 publishes a
  separate nushell integration if needed later
- `ITERM_ENABLE_SHELL_INTEGRATION_WITH_TMUX` — only meaningful to the
  zsh integration script above
- `BASH_SILENCE_DEPRECATION_WARNING`, `LESS_TERMCAP_md` — bash / `less`
  specific env vars with no effect from nushell

### Skipped per request (would conflict with nushell)
- `alias ls = eza` — nushell's built-in `ls` returns structured tables
  that pipe into `where`/`sort-by`/etc. Aliasing to eza loses that.
- `alias cat = bat` — same logic; nushell pipelines lean on `open`
  instead of `cat`
- `diff` override (`git diff --no-index --color-words`) — surprises any
  callers expecting BSD/GNU `diff` semantics

### Borderline cases that *were* carried (with caveats)
- **Auto-tmux exec** — kept, mirrors zsh. Note that tmux's default shell
  is still zsh, so panes opened inside tmux will be zsh sourcing
  `.zshrc`. If you want nu inside tmux, that's a tmux config change
  (`set-option -g default-command 'nu'`).
- **`fastfetch` on startup** — kept. Adds visible output to every
  interactive nu start; harmless because of the `$nu.is-interactive`
  guard.

## Caveats / known gaps
- **No fzf shell integration.** Upstream fzf only ships `--zsh`,
  `--bash`, `--fish` init flags. `fzf` is still on `$PATH` for explicit
  pipelines, but there are no keybindings (Ctrl-T / Ctrl-R / Alt-C). If
  that matters, look at `nu_plugin_fzf` or a community recipe.
- **`getcertnames` and `gz`** are thin shells over external `openssl` /
  `gzip` / `wc`. They work, but they're less idiomatic than the rest of
  the translated commands — could be tightened later.
- The `vendor/autoload` cache files are generated on first launch and
  not regenerated until deleted, so upgrading starship/atuin/zoxide
  needs a one-time `rm` of the corresponding `.nu` file in
  `~/Library/Application Support/nushell/vendor/autoload/`.
