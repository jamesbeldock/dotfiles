# James's dotfiles

(a work in progress, originally and still loosely based on
[Mathias's dotfiles](https://github.com/mathiasbynens/dotfiles))

Config for zsh, nushell, nvim, tmux, git, starship, wezterm/iTerm2 and friends,
plus the scripts that install the packages those configs expect. Dotfiles are
symlinked into `$HOME` with [GNU Stow](https://www.gnu.org/software/stow/);
package lists live in YAML under `config/` rather than in the shell scripts.

- [Sets](#sets)
- [Clean macOS setup](#clean-macos-setup)
- [Clean Linux setup](#clean-linux-setup)
- [What bootstrap actually does](#what-bootstrap-actually-does)
- [Running the pieces individually](#running-the-pieces-individually)
- [How the stow layout works](#how-the-stow-layout-works)
- [When a file is already in the way](#when-a-file-is-already-in-the-way)
- [Known rough edges](#known-rough-edges)
- [Testing](#testing)

## Sets

Every script takes a *set* naming how much to install. Sets are defined by the
files in `config/sets/`, so `--list` is always the authoritative answer.

| Set | Linux | macOS | Stow packages | What it is |
|---|---|---|---|---|
| `iot` | yes | — | 6 | Basic tools, core utils, and the usual CLI kit (tmux, zsh, nvim) |
| `lxc` | yes | — | 6 | Minimal tools, core utils, LXC-specific bits |
| `server` | yes | yes | 8 | `iot` plus network/security tools and general utilities |
| `workstation` | yes | yes | 13 | Everything, including GUI casks and Nerd Fonts |

`iot` and `lxc` declare no macOS packages. Running them on a Mac is not an
error — the installer prints a skip message and moves on to stowing.

## Clean macOS setup

### 1. Xcode command line tools

```bash
xcode-select --install
```

### 2. Clone the repo

Homebrew is *not* a prerequisite — `osx-package-install.sh` installs it if it
is missing. But you need `git`, which arrives with the Xcode CLI tools above.

```bash
mkdir -p ~/code && cd ~/code
git clone --recurse-submodules https://github.com/jamesbeldock/dotfiles.git
cd dotfiles
```

`--recurse-submodules` matters: Oh My Zsh and the BATS test libraries are
submodules. If you already cloned without it, run
`git submodule update --init --recursive`.

### 3. Install the Python dependencies

**This step is required, and bootstrap fails without it.** The install scripts
read `config/*.yaml` by shelling out to `python3 tools/load_config.py`, which
imports PyYAML and jsonschema. macOS ships `python3` but not those packages, so
a clean machine dies at the first step with `ModuleNotFoundError: No module
named 'yaml'` followed by a misleading `Error: No config sets found`.

A virtualenv is the tidiest fix — activating it puts the right `python3` first
on `PATH`, which is all the scripts care about:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r tools/requirements.txt
```

Confirm it took before going further:

```bash
bash bootstrap.sh --list      # => Available sets: iot lxc server workstation
```

If that prints a traceback instead, the `python3` on your `PATH` still lacks
the dependencies.

### 4. Bootstrap

```bash
bash bootstrap.sh workstation
```

Run it with `bash`, from inside the repo. Two things to know:

- **Do not `source` it.** `main` is guarded by `[[ "${BASH_SOURCE[0]}" == "${0}" ]]`,
  so sourcing defines the functions and runs nothing at all — silently.
- **Do not run it from elsewhere.** `execute_bootstrap` invokes its child
  scripts by relative path (`./osx-package-install.sh`), so `$PWD` must be the
  repo root.

Expect it to take a while on a fresh machine: `brew update && brew upgrade`
runs first, then every formula and cask in the set.

### 5. Sign in to GitHub (optional)

`gh` is installed as part of `james_tools`, so this is easier afterwards:

```bash
gh auth login
```

## Clean Linux setup

Debian/Ubuntu only — the installer is `apt-get` based.

### 1. Install git and Python dependencies

```bash
sudo apt update
sudo apt install -y git python3 python3-venv python3-pip
```

### 2. Clone the repo

```bash
mkdir -p ~/code && cd ~/code
git clone --recurse-submodules https://github.com/jamesbeldock/dotfiles.git
cd dotfiles
```

### 3. Install the Python dependencies

Same requirement and same reason as macOS — see
[step 3 above](#3-install-the-python-dependencies).

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r tools/requirements.txt
bash bootstrap.sh --list      # => Available sets: iot lxc server workstation
```

On distros that mark the system Python externally managed (PEP 668), the venv
is not optional — a plain `pip install` into system Python is refused.

### 4. Bootstrap

```bash
bash bootstrap.sh server        # or: iot, lxc, workstation
```

You will be prompted for `sudo`. The script detects whether it is already root
and only prefixes `sudo` when it is not, so it works unmodified inside a
container running as root.

## What bootstrap actually does

`bootstrap.sh <set>` runs, in order:

1. **Validates the config.** `tools/validate_config.py` checks every YAML file
   against its JSON schema and cross-checks that group and stow-package names
   actually exist. A bad config aborts before anything is installed.
2. **Installs packages** — `osx-package-install.sh` (Homebrew formulae + casks,
   installing Homebrew itself if absent) or `linux-apt-package-install.sh`
   (`apt-get`, plus starship via its upstream install script).
3. **Stows the dotfiles** — `stow-packages.sh` symlinks each stow package for
   the set into `$HOME`. Where a real file is already sitting at a target, it
   shows you the diff and asks which copy to keep (see below) instead of
   aborting. A package that fails for some other reason is reported and
   skipped rather than aborting the run, so you see every problem in one pass.
4. **Post-install odds and ends** — the atuin stow package, the eza theme
   symlink, and cloning TPM + tmux2k into `~/.tmux/plugins/`. Each step creates
   the directories it needs and skips work already done, so re-running is
   quiet.

## Running the pieces individually

Each script stands alone and takes the same arguments:

```bash
bash bootstrap.sh --list                 # show available sets
bash bootstrap.sh --help
bash stow-packages.sh workstation        # re-link dotfiles only
bash osx-package-install.sh server       # macOS packages only
bash linux-apt-package-install.sh iot    # Linux packages only
```

All of them are safe to re-run. Package installs skip anything already present,
and `stow` is idempotent once the symlinks exist — a re-run only stops to ask
about targets you chose to keep last time.

To see what a set resolves to without installing anything:

```bash
python3 tools/load_config.py --set workstation --platform macos --type casks
python3 tools/load_config.py --set server --type stow
python3 tools/validate_config.py
```

## How the stow layout works

Each top-level directory named in `config/packages.yaml`'s `stow_packages` is a
stow package whose contents mirror `$HOME`:

```
nvim/.config/nvim/...        ->  ~/.config/nvim/...
zsh/.zshrc                   ->  ~/.zshrc
karabiner/dot-config/...     ->  ~/.config/...
```

Everything is stowed with `stow -v -t ~/ --dotfiles`, so a `dot-` prefix in the
repo becomes a leading `.` in `$HOME`. Both spellings appear in this repo —
literal `.zshrc` and prefixed `dot-config` — and `--dotfiles` handles both.

`.stow-local-ignore` keeps `README`, `LICENSE`, VCS metadata and editor cruft
out of `$HOME`.

## When a file is already in the way

Plain `stow` gives up on a whole package the moment it finds a real file where
a symlink should go. `tools/stow_conflicts.sh` steps in first: it dry-runs
stow, and for every blocked target it prints a summary of the diff between
your file and the repo's, then asks which one wins:

```
Conflict on /Users/you/.zshrc
  existing: /Users/you/.zshrc (file)
  repo:     /Users/you/code/dotfiles/zsh/.zshrc (file)
  diff:     41 line(s) only in the repo version, 2 only in the existing file
  | --- /Users/you/.zshrc
  | +++ /Users/you/code/dotfiles/zsh/.zshrc
  | @@ -1,3 +1,42 @@
  | -export PATH="/usr/local/opt/ruby/bin:$PATH"
  ...
  | ... 25 more diff line(s)
  Keep [n]ew from repo, [e]xisting file, show full [d]iff, or [q]uit?
```

- **`n`** renames your file to `<file>.stow-backup-<timestamp>` and links the
  repo version over it. Nothing is ever deleted.
- **`e`** leaves your file exactly where it is and skips that one symlink; the
  rest of the package still gets stowed.
- **`d`** prints the whole diff, then asks again.
- **`q`** stops the run, leaving every file untouched.

The prompt reads from `/dev/tty`, so it still works when the script's stdin is
a pipe. Three environment variables tune it:

| Variable                  | Default    | Effect                                        |
| ------------------------- | ---------- | --------------------------------------------- |
| `STOW_CONFLICT_POLICY`    | `ask`      | `new` or `existing` answers every prompt for you |
| `STOW_DIFF_PREVIEW_LINES` | `20`       | how many diff lines to show inline            |
| `STOW_TTY`                | `/dev/tty` | where to read answers from                    |

With no terminal to ask — CI, a `nohup`'d run — it keeps the existing file and
says so, which never loses anything you had.

## Known rough edges

Real behaviour worth knowing before a first run, rather than discovering at
step 40:

- **`source bootstrap.sh` silently does nothing.** Use `bash bootstrap.sh <set>`.
  Older versions of this README recommended sourcing; that never ran `main`.
- **A set argument is required.** `bootstrap.sh` with no argument prints usage
  and exits 0, which reads like success.
- **macOS: the `zsh` package hits a conflict on a clean machine.**
  `osx-package-install.sh` appends a Ruby `PATH` line to `~/.zshrc`, creating
  the file, so the repo's `.zshrc` has something in its way. You get the diff
  prompt described above; answering `n` backs up the two-line stub and links
  the real one.
- **Bootstrap now stops if package installation fails.** It used to carry on to
  the stow step regardless, which on a machine where Homebrew never came up
  meant one `stow: command not found` per package and the real error buried
  hundreds of lines earlier. Nothing is symlinked when the install step fails.
- **Step 4 of bootstrap is re-runnable.** It used to assume a warm machine: it
  called `zinit` (a zsh function, from a bash script — it never once ran), and
  `ln -s`d into a `~/.eza/` that does not exist yet, and `git clone`d into
  `~/.tmux/plugins/` even when already populated. The `zinit` block is gone —
  atuin comes from the brew formula and `.zshrc` initialises it — and the other
  two create what they need and skip what is already there.
- **`shell.sh` is not wired in.** `bootstrap.sh` has the call commented out
  pending a Linux fix, so Oh My Zsh and the default-shell change do not happen
  automatically. Run it by hand on macOS if you want them.

## Testing

The repo has a BATS suite for the shell scripts and a pytest suite for the
Python tools, both run in CI on Linux and macOS. See [TESTING.md](TESTING.md)
for prerequisites and how to run them.

```bash
pip install -r tools/requirements-dev.txt
pytest && ./test/libs/bats-core/bin/bats test/
```

Nushell specifics — the config layout, what is ported from zsh, and how vendor
autoload files are generated — are in [NUSHELL.md](NUSHELL.md).
