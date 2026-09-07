"""Shared fixtures for the pytest suite.

These tests cover the branching logic *inside* tools/load_config.py and
tools/validate_config.py by importing them and calling their functions
directly. The bash-eval contract those tools expose to the install scripts
(`eval "$(python3 load_config.py ...)"` populating a bash array) stays
covered by test/load-config.bats and test/validate-config.bats -- that is an
integration concern pytest cannot meaningfully assert on.
"""
import shutil
import sys
import textwrap
from pathlib import Path

import pytest

PROJECT_ROOT = Path(__file__).resolve().parents[2]
TOOLS_DIR = PROJECT_ROOT / "tools"

# tools/ is a directory of standalone scripts, not an installable package,
# so put it on the path rather than importing through a package name.
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))


@pytest.fixture(scope="session")
def project_root():
    return PROJECT_ROOT


@pytest.fixture(scope="session")
def real_config_dir():
    """The repo's actual config/ directory. Read-only -- do not modify."""
    return PROJECT_ROOT / "config"


@pytest.fixture
def config_dir(tmp_path):
    """A writable copy of config/ that a test can corrupt freely."""
    dest = tmp_path / "config"
    shutil.copytree(PROJECT_ROOT / "config", dest)
    return dest


@pytest.fixture
def write_set(config_dir):
    """Write a set file into the throwaway config dir.

    Returns the config dir so a test can pass it straight to --config-dir.
    """
    def _write(name, body):
        path = config_dir / "sets" / f"{name}.yaml"
        path.write_text(textwrap.dedent(body).lstrip())
        return config_dir
    return _write


@pytest.fixture
def run_cli(monkeypatch, capsys):
    """Run a tool's main() in-process with the given argv.

    Returns (exit_code, stdout, stderr). A clean return is reported as 0, so
    callers can assert on exit status uniformly.
    """
    def _run(module, *argv):
        monkeypatch.setattr(sys, "argv", [module.__name__, *[str(a) for a in argv]])
        code = 0
        try:
            module.main()
        except SystemExit as exc:
            code = exc.code if exc.code is not None else 0
        captured = capsys.readouterr()
        return code, captured.out, captured.err
    return _run
