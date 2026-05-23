"""Shared fixtures for Playwright UI tests."""
import multiprocessing
import socket
import time

import pytest
import uvicorn
from playwright.sync_api import sync_playwright


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
    """Launch a headless Chromium browser for the test session."""
    pw = sync_playwright().start()
    b = pw.chromium.launch(headless=True)
    yield b
    b.close()
    pw.stop()


@pytest.fixture
def page(browser, server_url):
    """Create a new page and navigate to the app for each test."""
    p = browser.new_page(viewport={"width": 1280, "height": 900})
    p.goto(server_url)
    p.wait_for_selector("header")
    yield p
    p.close()
