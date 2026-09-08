# Testing Guide

This repository uses two test runners, split by what is under test:

- **[BATS](https://github.com/bats-core/bats-core)** (`test/*.bats`) for the
  shell scripts, the nushell package, and the bash-eval contract the Python
  tools expose to the install scripts.
- **[pytest](https://docs.pytest.org/)** (`test/python/`) for the branching
  logic inside `tools/load_config.py` and `tools/validate_config.py`, imported
  and called directly.

The split is deliberate and narrow. BATS can source a bash script and inspect
its arrays, which is most of what needs testing here; pytest can reach the
Python edge cases (empty inputs, malformed config, argparse error paths)
in-process, without a subprocess per assertion. Adding a package to
`config/packages.yaml`? That is a BATS test. Adding a branch to
`load_config.py`? That is a pytest test.

## Prerequisites

- **Bash 4.0+** (required by test helpers; macOS ships with Bash 3.2)
- **Git** (for submodule checkout)
- **Python 3** with the packages in `tools/requirements.txt` (PyYAML,
  jsonschema). `parse_args` shells out to `tools/load_config.py`, so without
  these most tests fail with `ModuleNotFoundError: No module named 'yaml'`.

### macOS

```bash
brew install bash
```

### Linux (Debian/Ubuntu)

Bash 4+ is typically already installed. No extra steps needed.

## Initial Setup

After cloning the repository, initialize the test library submodules:

```bash
git submodule update --init --recursive
```

This pulls bats-core, bats-support, and bats-assert into `test/libs/`.

Then install the Python dependencies. A virtualenv is recommended — Homebrew's
Python is marked externally managed (PEP 668), so a plain `pip install` into it
is refused:

```bash
python3 -m venv .venv
.venv/bin/pip install -r tools/requirements-dev.txt
```

`requirements-dev.txt` pulls in `requirements.txt` and adds pytest. If you only
want to *run* the tools rather than test them, `requirements.txt` is enough.

Activate it before running the suite, so the `python3` that
`tools/load_config.py` runs under is the one with the dependencies:

```bash
source .venv/bin/activate
```

CI does the equivalent via `actions/setup-python` plus
`pip install -r tools/requirements.txt` (see `.github/workflows/test.yml`).

## Running Tests

### Run everything

```bash
pytest && ./test/libs/bats-core/bin/bats test/
```

### Run all BATS tests

```bash
./test/libs/bats-core/bin/bats test/
```

### Run a single test file

```bash
./test/libs/bats-core/bin/bats test/stow-packages.bats
```

### Run a specific test by name

```bash
./test/libs/bats-core/bin/bats test/stow-packages.bats -f "workstation PACKAGE"
```

### Verbose output

```bash
./test/libs/bats-core/bin/bats --verbose-run test/
```

### Run the pytest suite

`pytest.ini` sets `testpaths`, so a bare `pytest` from the repo root picks up
`test/python/` only. The whole suite runs in well under a second.

```bash
pytest                                        # all Python tests
pytest test/python/test_load_config.py        # one file
pytest -k "platform_override"                 # by name
pytest -v                                     # per-test output
```

## Test Architecture

Each production script (`stow-packages.sh`, `linux-apt-package-install.sh`,
`osx-package-install.sh`, `bootstrap.sh`) has been refactored so that:

1. **All logic lives in named functions** (`parse_args`, `detect_privilege`,
   `detect_os`, `execute_*`)
2. **The `main` function is guarded** by a `BASH_SOURCE` check, so sourcing the
   script does not trigger execution
3. **Package arrays remain at file scope** and are available immediately after
   sourcing

Tests source the production scripts without executing them, giving direct
access to:

- **Functions**: `parse_args`, `detect_privilege`, `detect_os`, etc.
- **Package arrays**: `GNU_CORE_UTILS`, `JAMES_TOOLS`, `CASK_APPS`, etc.

Tests never install packages, run `apt-get`/`brew`, or require root privileges.

`tools/stow_conflicts.sh` is a sourced library rather than a script, so
`test/stow-conflicts.bats` sources it directly. Its end-to-end tests do run the
real `stow`, but only inside a `mktemp -d` sandbox that stands in for both the
stow directory and `$HOME`; they skip when `stow` is not installed.

## What Is Tested

| Script                         | Tests Cover                                                          |
|--------------------------------|----------------------------------------------------------------------|
| `stow-packages.sh`            | Arg parsing, mode setting, PACKAGE arrays for all 4 modes, privilege detection |
| `linux-apt-package-install.sh` | Arg parsing, mode setting, all 7 file-scope arrays, package assembly for all 4 modes, privilege detection |
| `osx-package-install.sh`       | Arg parsing (incl. iot early exit), mode setting, file-scope arrays, formulae/cask assembly for server and workstation |
| `bootstrap.sh`                 | Arg parsing, mode setting, OS detection with mocked OSTYPE           |
| `tools/stow_conflicts.sh`      | Parsing each of stow's conflict messages, mapping a target back to its `dot-` prefixed repo file, diff summaries (line counts, identical files, directories, symlinks, truncation), the prompt's answers and re-prompting, and end-to-end backup/skip/quit against a real `stow` in a sandbox |
| `nushell` package              | Stow layout, env.nu/config.nu content, live `nu` parse, and real vendor-autoload generation against a throwaway `$nu.data-dir` |

### pytest (`test/python/`)

| Module                     | Tests Cover                                                          |
|----------------------------|----------------------------------------------------------------------|
| `tools/load_config.py`     | `resolve_packages` group flattening and platform overrides, `format_bash_array` quoting, `list_sets` filtering, `check_platform_support` edge cases, and the CLI's error/exit paths |
| `tools/validate_config.py` | Every cross-validation branch (unknown group, macos_only misuse, stow mismatch, name mismatch), schema violations, error accumulation, and `validate_schema` path rendering |

Python tests import the tools directly (`conftest.py` puts `tools/` on
`sys.path`) and drive `main()` in-process via the `run_cli` fixture, which
patches `sys.argv` and returns `(exit_code, stdout, stderr)`.

## Adding Tests

1. Create or edit a `.bats` file in `test/`.
2. Load the helper in `setup()`:
   ```bash
   setup() {
       load test_helper
       source "${PROJECT_ROOT}/script-name.sh"
   }
   ```
3. Write tests using BATS syntax:
   ```bash
   @test "description" {
       parse_args "server"
       assert_equal "$MODE" "server"
   }
   ```
4. Use the shared helpers for array assertions:
   ```bash
   assert_array_contains ARRAY_NAME "value"
   assert_array_not_contains ARRAY_NAME "value"
   assert_array_length ARRAY_NAME 5
   ```
5. Run your new test to verify.

## File Layout

```
pytest.ini              # pytest config; testpaths = test/python
test/
  libs/
    bats-core/          # git submodule: test runner
    bats-support/       # git submodule: output helpers
    bats-assert/        # git submodule: assertion functions
  test_helper.bash      # common setup, loads libraries, shared helpers
  stow-packages.bats
  stow-conflicts.bats   # tools/stow_conflicts.sh; needs stow for the e2e tests
  linux-apt-package-install.bats
  osx-package-install.bats
  bootstrap.bats
  load-config.bats      # bash-eval contract for tools/load_config.py
  validate-config.bats  # exit codes for tools/validate_config.py
  nushell-package.bats
  python/
    conftest.py         # sys.path setup + shared fixtures
    test_load_config.py
    test_validate_config.py
```
