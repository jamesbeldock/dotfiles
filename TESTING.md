# Testing Guide

This repository uses [BATS](https://github.com/bats-core/bats-core)
(Bash Automated Testing System) for unit testing the shell scripts.

## Prerequisites

- **Bash 4.0+** (required by test helpers; macOS ships with Bash 3.2)
- **Git** (for submodule checkout)

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

## Running Tests

### Run all tests

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

## What Is Tested

| Script                         | Tests Cover                                                          |
|--------------------------------|----------------------------------------------------------------------|
| `stow-packages.sh`            | Arg parsing, mode setting, PACKAGE arrays for all 4 modes, privilege detection |
| `linux-apt-package-install.sh` | Arg parsing, mode setting, all 7 file-scope arrays, package assembly for all 4 modes, privilege detection |
| `osx-package-install.sh`       | Arg parsing (incl. iot early exit), mode setting, file-scope arrays, formulae/cask assembly for server and workstation |
| `bootstrap.sh`                 | Arg parsing, mode setting, OS detection with mocked OSTYPE           |

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
test/
  libs/
    bats-core/          # git submodule: test runner
    bats-support/       # git submodule: output helpers
    bats-assert/        # git submodule: assertion functions
  test_helper.bash      # common setup, loads libraries, shared helpers
  stow-packages.bats
  linux-apt-package-install.bats
  osx-package-install.bats
  bootstrap.bats
```
