"""Playwright UI tests for the Dotfiles Config Manager web app."""
import re

import pytest
from playwright.sync_api import expect


def _wait_for_packages(page):
    """Wait for stow packages to load and return the entry locators."""
    entries = page.locator("div.cursor-pointer div.truncate")
    entries.first.wait_for(state="visible", timeout=5000)
    assert entries.count() > 0, "No stow packages loaded"
    return entries


def _select_first_package(page):
    """Wait for packages to load and click the first one."""
    entries = _wait_for_packages(page)
    entries.first.click()
    expect(page.locator("button", has_text="+ New File")).to_be_visible()


def _select_package_with_files(page):
    """Select a package that has at least 1 file. Returns False if none found."""
    _wait_for_packages(page)
    # Each package entry shows "N file(s)" — find one with count > 0
    pkg_items = page.locator("div.cursor-pointer").all()
    for item in pkg_items:
        text = item.text_content() or ""
        # Skip entries showing "0 files"
        if "0 file" in text:
            continue
        item.locator("div.truncate").click()
        expect(page.locator("button", has_text="+ New File")).to_be_visible()
        return True
    return False


def _find_compare_dropdown(page):
    """Find and return the 'Compare with...' select element."""
    for s in page.locator("main select").all():
        first_opt = s.locator("option").first.text_content() or ""
        if "Compare" in first_opt:
            return s
    pytest.fail("Compare dropdown not found")


# ---------------------------------------------------------------------------
# App chrome / navigation
# ---------------------------------------------------------------------------

class TestAppStructure:
    def test_header_title(self, page):
        expect(page.locator("header")).to_contain_text("Dotfiles Config Manager")

    def test_two_tabs_present(self, page):
        nav = page.locator("nav")
        expect(nav.get_by_text("Stow Packages")).to_be_visible()
        expect(nav.get_by_text("Configuration Sets")).to_be_visible()

    def test_default_tab_is_config_sets(self, page):
        btn = page.locator("nav button", has_text="Configuration Sets")
        expect(btn).to_have_class(re.compile(r"border-blue-600"))

    def test_switch_to_stow_tab(self, page):
        page.locator("nav button", has_text="Stow Packages").click()
        expect(page.locator("main")).to_contain_text("Stow Packages")

    def test_switch_back_to_config_tab(self, page):
        page.locator("nav button", has_text="Stow Packages").click()
        page.locator("nav button", has_text="Configuration Sets").click()
        expect(page.locator("main select").first).to_be_visible()


# ---------------------------------------------------------------------------
# Stow Packages tab
# ---------------------------------------------------------------------------

class TestStowPackagesTab:
    @pytest.fixture(autouse=True)
    def navigate_to_stow(self, page):
        page.locator("nav button", has_text="Stow Packages").click()
        page.locator("main").wait_for(state="visible")

    def test_package_list_heading(self, page):
        expect(page.locator("main")).to_contain_text("Stow Packages")

    def test_packages_listed(self, page):
        """At least one stow package should appear in the sidebar."""
        entries = _wait_for_packages(page)
        assert entries.count() >= 1

    def test_package_shows_file_count(self, page):
        _wait_for_packages(page)
        expect(page.locator("main")).to_contain_text("file")

    def test_select_package_shows_file_browser(self, page):
        _select_first_package(page)
        expect(page.locator("main")).to_contain_text("Source")
        expect(page.locator("main")).to_contain_text("Target")

    def test_file_browser_shows_home_targets(self, page):
        if not _select_package_with_files(page):
            pytest.skip("No packages with files available")
        expect(page.locator("main")).to_contain_text("~/")

    def test_click_file_opens_editor(self, page):
        if not _select_package_with_files(page):
            pytest.skip("No packages with files available")
        page.locator("main tbody tr.cursor-pointer").first.click()
        expect(page.locator("main")).to_contain_text("Save")

    def test_editor_save_button_disabled_initially(self, page):
        if not _select_package_with_files(page):
            pytest.skip("No packages with files available")
        page.locator("main tbody tr.cursor-pointer").first.click()
        save_btn = page.locator("button", has_text="Save")
        expect(save_btn).to_be_disabled()

    def test_new_package_button_exists(self, page):
        expect(page.locator("main button", has_text="+ New")).to_be_visible()

    def test_empty_state_message(self, page):
        expect(page.locator("main")).to_contain_text("Select a stow package")

    def test_new_file_button_after_selecting_package(self, page):
        _select_first_package(page)
        expect(page.locator("button", has_text="+ New File")).to_be_visible()

    def test_delete_file(self, page):
        """Create a temp file via the UI, then delete it."""
        tmp_file = "_test_delete_me.txt"

        _select_first_package(page)

        # Create file via the "+ New File" prompt
        page.on("dialog", lambda d: d.accept(tmp_file))
        page.locator("button", has_text="+ New File").click()

        # Wait for the temp file to appear in the file list
        row = page.locator("main tbody tr", has_text=tmp_file)
        expect(row).to_be_visible()

        # Now delete it
        page.on("dialog", lambda d: d.accept())
        row.hover()
        row.locator("button[title='Delete file']").click()

        # File should disappear from the table
        expect(row).not_to_be_visible()


# ---------------------------------------------------------------------------
# Configuration Sets tab
# ---------------------------------------------------------------------------

class TestConfigSetsTab:
    @pytest.fixture(autouse=True)
    def navigate_to_sets(self, page):
        page.locator("nav button", has_text="Configuration Sets").click()
        page.locator("main select").first.wait_for(state="visible")

    def test_active_set_label(self, page):
        expect(page.locator("main")).to_contain_text("Active Set")

    def test_dropdown_has_options(self, page):
        """Dropdown should contain at least one set."""
        select = page.locator("main select").first
        options = select.locator("option").all()
        real_options = [o for o in options if o.get_attribute("value")]
        assert len(real_options) >= 1, "No sets in dropdown"

    def test_default_set_selected(self, page):
        select = page.locator("main select").first
        value = select.input_value()
        assert value != "", "No default set selected"

    def test_package_table_headers(self, page):
        table = page.locator("main table")
        expect(table).to_contain_text("Group")
        expect(table).to_contain_text("Package")

    def test_linux_macos_columns(self, page):
        table = page.locator("main table")
        expect(table).to_contain_text("Linux")
        expect(table).to_contain_text("macOS")

    def test_group_rows_present(self, page):
        """At least one group row (with collapse arrow) should appear."""
        page.locator("main table tbody tr").first.wait_for(state="visible")
        group_rows = page.locator("main table tbody tr", has_text="\u25be")
        assert group_rows.count() > 0, "No group rows found in table"

    def test_switch_active_set(self, page):
        select = page.locator("main select").first
        initial = select.input_value()
        # Pick a different set
        options = select.locator("option").all()
        others = [o.text_content() for o in options
                  if o.get_attribute("value") and o.get_attribute("value") != initial]
        if not others:
            pytest.skip("Only one set available, cannot test switching")
        select.select_option(label=others[0])
        expect(page.locator("main table")).to_contain_text(others[0])

    def test_group_collapse_toggle(self, page):
        # Wait for table rows
        page.locator("main table tbody tr").first.wait_for(state="visible")

        # Find a group header row (contains collapse arrow)
        group_row = page.locator("main table tbody tr", has_text="\u25be").first
        expect(group_row).to_be_visible()

        rows_before = page.locator("main table tbody tr").count()
        group_row.click()
        # After collapsing, row count should decrease
        page.wait_for_timeout(300)
        rows_after = page.locator("main table tbody tr").count()
        assert rows_after != rows_before, "Collapsing group did not change row count"

    def test_compare_dropdown_exists(self, page):
        _find_compare_dropdown(page)

    def test_add_compare_set(self, page):
        compare_select = _find_compare_dropdown(page)
        options = compare_select.locator("option").all()
        real = [o for o in options if o.get_attribute("value")]
        if not real:
            pytest.skip("No sets available for comparison")
        compare_name = real[0].text_content()
        compare_select.select_option(label=compare_name)

        # Should appear as a chip
        expect(page.locator("span.inline-flex", has_text=compare_name)).to_be_visible()

    def test_remove_compare_chip(self, page):
        compare_select = _find_compare_dropdown(page)
        options = compare_select.locator("option").all()
        real = [o for o in options if o.get_attribute("value")]
        if not real:
            pytest.skip("No sets available for comparison")
        compare_name = real[0].text_content()
        compare_select.select_option(label=compare_name)

        chip = page.locator("span.inline-flex", has_text=compare_name)
        expect(chip).to_be_visible()

        # Click the dismiss button inside the chip
        chip.locator("button").click()
        expect(chip).not_to_be_visible()

    def test_new_set_button(self, page):
        expect(page.locator("main button", has_text="+ New Set")).to_be_visible()

    def test_delete_set_button(self, page):
        expect(page.locator("main button", has_text="Delete Set")).to_be_visible()

    def test_platform_toggle_buttons(self, page):
        page.locator("main table tbody tr").first.wait_for(state="visible")
        group_row = page.locator("main table tbody tr", has_text="\u25be").first
        buttons = group_row.locator("button").all()
        toggle_btns = [b for b in buttons if b.get_attribute("title") and "group" in (b.get_attribute("title") or "").lower()]
        assert len(toggle_btns) >= 2, f"Expected >=2 platform toggles, found {len(toggle_btns)}"

    def test_table_shows_active_set_name(self, page):
        select = page.locator("main select").first
        active = select.input_value()
        expect(page.locator("main table")).to_contain_text(active)

    def test_package_names_in_expanded_group(self, page):
        """Expanded groups should show individual package names in monospace."""
        page.locator("main table tbody tr").first.wait_for(state="visible")
        mono_cells = page.locator("main table tbody td.font-mono")
        assert mono_cells.count() > 0, "No package name cells found"
