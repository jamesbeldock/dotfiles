"""Shared fixtures for Playwright UI tests."""
import multiprocessing
import os
import shutil
import socket
import time
from pathlib import Path

import pytest
import uvicorn
from playwright.sync_api import sync_playwright

PROJECT_ROOT = Path(__file__).resolve().parents[2]

# Deliberately obvious in a directory listing, in case a run is ever killed
# between the mkdir and the teardown. Must start with an alphanumeric to
# satisfy validate_name: the sidebar lists a package the API then refuses to
# read or write, which shows up as a silently empty file table.
SCRATCH_PACKAGE = "ui-scratch-pkg"


def _find_free_port():
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind(("", 0))
        return s.getsockname()[1]


def _run_server(port):
    """Run the FastAPI app in a subprocess."""
    import sys
    import os
    sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "api"))
    from main import app
    uvicorn.run(app, host="127.0.0.1", port=port, log_level="warning")


@pytest.fixture(scope="session")
def server_url():
    """Start the FastAPI server and return its base URL."""
    port = _find_free_port()
    proc = multiprocessing.Process(target=_run_server, args=(port,), daemon=True)
    proc.start()

    url = f"http://127.0.0.1:{port}"
    for _ in range(50):
        try:
            import urllib.request
            urllib.request.urlopen(f"{url}/api/health", timeout=1)
            break
        except Exception:
            time.sleep(0.1)
    else:
        proc.kill()
        raise RuntimeError("Server did not start in time")

    yield url
    proc.kill()
    proc.join(timeout=3)


@pytest.fixture(scope="session")
def browser():
    """Launch a headless Chromium browser for the test session.

    Set SKIP_UI_TESTS=1 to skip the whole suite where Chromium cannot start —
    a restricted Mach bootstrap namespace, for instance, fails with
    "bootstrap_check_in ...: Permission denied" before any test runs.
    """
    if os.environ.get("SKIP_UI_TESTS"):
        pytest.skip("SKIP_UI_TESTS is set")

    pw = sync_playwright().start()
    b = pw.chromium.launch(headless=True)
    yield b
    b.close()
    pw.stop()


@pytest.fixture
def scratch_package():
    """A throwaway stow package for tests that create or delete files.

    Made on disk rather than through the UI's "+ New" button, which would also
    write the package name into config/packages.yaml — no test should edit real
    config. Torn down even when the test fails, so a leftover file can never end
    up in a real package for `stow` to link into $HOME.
    """
    pkg_dir = PROJECT_ROOT / SCRATCH_PACKAGE
    pkg_dir.mkdir(exist_ok=True)
    try:
        yield SCRATCH_PACKAGE
    finally:
        shutil.rmtree(pkg_dir, ignore_errors=True)


@pytest.fixture
def page(browser, server_url):
    """Create a new page and navigate to the app for each test."""
    p = browser.new_page(viewport={"width": 1280, "height": 900})
    p.goto(server_url)
    p.wait_for_selector("header")
    yield p
    p.close()
