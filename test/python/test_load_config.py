"""Unit tests for tools/load_config.py.

Scope: the pure resolution logic and the CLI's error branches. Package-content
assertions ("workstation includes bat") live in test/load-config.bats, where
they double as a check on the bash-eval contract.
"""
import pytest

import load_config


# A hand-built catalog keeps these tests independent of config/packages.yaml,
# so editing the real package list cannot break them.
CATALOG = {
    "groups": {
        "core": {
            "packages": [{"name": "coreutils"}, {"name": "stow"}],
        },
        "tools": {
            "packages": [{"name": "bat"}, {"name": "fzf"}],
            "platform_overrides": {
                "macos": {"extra_packages": [{"name": "starship"}]},
            },
        },
        "empty": {"packages": []},
    }
}


class TestResolvePackages:
    def test_flattens_a_single_group(self):
        assert load_config.resolve_packages(CATALOG, ["core"]) == ["coreutils", "stow"]

    def test_concatenates_groups_in_order(self):
        result = load_config.resolve_packages(CATALOG, ["tools", "core"])
        assert result == ["bat", "fzf", "coreutils", "stow"]

    def test_no_groups_yields_empty_list(self):
        assert load_config.resolve_packages(CATALOG, []) == []

    def test_group_with_no_packages_contributes_nothing(self):
        assert load_config.resolve_packages(CATALOG, ["empty", "core"]) == [
            "coreutils",
            "stow",
        ]

    def test_platform_override_appends_extra_packages(self):
        result = load_config.resolve_packages(CATALOG, ["tools"], platform="macos")
        assert result == ["bat", "fzf", "starship"]

    def test_override_is_skipped_for_other_platforms(self):
        result = load_config.resolve_packages(CATALOG, ["tools"], platform="linux")
        assert result == ["bat", "fzf"]

    def test_override_is_skipped_when_platform_is_none(self):
        assert load_config.resolve_packages(CATALOG, ["tools"]) == ["bat", "fzf"]

    def test_group_without_overrides_is_unaffected_by_platform(self):
        assert load_config.resolve_packages(CATALOG, ["core"], platform="macos") == [
            "coreutils",
            "stow",
        ]

    def test_duplicates_are_preserved_not_deduped(self):
        # Documents current behaviour: two groups sharing a package emit it
        # twice, and the install scripts rely on brew/apt tolerating that.
        assert load_config.resolve_packages(CATALOG, ["core", "core"]) == [
            "coreutils",
            "stow",
            "coreutils",
            "stow",
        ]

    def test_unknown_group_raises(self):
        with pytest.raises(KeyError):
            load_config.resolve_packages(CATALOG, ["nope"])


class TestFormatBashArray:
    def test_empty_list_is_still_a_valid_array(self):
        assert load_config.format_bash_array("PKGS", []) == "PKGS=()"

    def test_each_value_is_quoted(self):
        assert load_config.format_bash_array("PKGS", ["a", "b"]) == 'PKGS=("a" "b")'

    def test_value_containing_a_space_stays_one_element(self):
        # "config resources" is a real stow package; unquoted it would split
        # into two array elements and stow would fail on both.
        assert (
            load_config.format_bash_array("PACKAGE", ["basic", "config resources"])
            == 'PACKAGE=("basic" "config resources")'
        )


class TestListSets:
    def test_lists_the_real_sets_sorted(self, real_config_dir):
        assert load_config.list_sets(real_config_dir) == [
            "iot",
            "lxc",
            "server",
            "workstation",
        ]

    def test_empty_sets_dir_yields_empty_list(self, tmp_path):
        (tmp_path / "sets").mkdir()
        assert load_config.list_sets(tmp_path) == []

    def test_ignores_non_yaml_files(self, tmp_path):
        sets = tmp_path / "sets"
        sets.mkdir()
        (sets / "real.yaml").write_text("name: real\n")
        (sets / "README.md").write_text("not a set\n")
        (sets / "old.yaml.bak").write_text("name: old\n")
        assert load_config.list_sets(tmp_path) == ["real"]


class TestCheckPlatformSupport:
    @pytest.mark.parametrize(
        "set_name,platform,expected",
        [
            ("server", "macos", True),
            ("server", "linux", True),
            ("workstation", "macos", True),
            ("workstation", "linux", True),
            # iot/lxc declare macos with empty group lists -> unsupported.
            ("iot", "macos", False),
            ("iot", "linux", True),
            ("lxc", "macos", False),
            ("lxc", "linux", True),
        ],
    )
    def test_against_real_sets(self, real_config_dir, set_name, platform, expected):
        assert (
            load_config.check_platform_support(real_config_dir, set_name, platform)
            is expected
        )

    def test_missing_platform_key_is_unsupported(self, write_set):
        cfg = write_set("edge", """
            name: edge
            stow_packages: []
        """)
        assert load_config.check_platform_support(cfg, "edge", "macos") is False

    def test_empty_platform_mapping_is_unsupported(self, write_set):
        cfg = write_set("edge", """
            name: edge
            stow_packages: []
            macos: {}
        """)
        assert load_config.check_platform_support(cfg, "edge", "macos") is False

    def test_all_empty_group_lists_is_unsupported(self, write_set):
        cfg = write_set("edge", """
            name: edge
            stow_packages: []
            macos:
              formulae_groups: []
              cask_groups: []
        """)
        assert load_config.check_platform_support(cfg, "edge", "macos") is False

    def test_one_non_empty_group_list_is_enough(self, write_set):
        cfg = write_set("edge", """
            name: edge
            stow_packages: []
            macos:
              formulae_groups: []
              cask_groups:
              - cask_apps
        """)
        assert load_config.check_platform_support(cfg, "edge", "macos") is True


class TestCli:
    """The argparse-level branches, including the two error paths."""

    def test_list_sets_emits_a_bash_array(self, run_cli, real_config_dir):
        code, out, _ = run_cli(load_config, "--list-sets", "--config-dir", real_config_dir)
        assert code == 0
        assert out.strip() == 'AVAILABLE_SETS=("iot" "lxc" "server" "workstation")'

    @pytest.mark.parametrize(
        "set_name,platform,expected",
        [("server", "macos", "true"), ("iot", "macos", "false")],
    )
    def test_check_platform_emits_has_platform(
        self, run_cli, real_config_dir, set_name, platform, expected
    ):
        code, out, _ = run_cli(
            load_config,
            "--set", set_name,
            "--check-platform", platform,
            "--config-dir", real_config_dir,
        )
        assert code == 0
        assert out.strip() == f"HAS_PLATFORM={expected}"

    def test_missing_set_is_an_error(self, run_cli, real_config_dir):
        code, _, err = run_cli(load_config, "--config-dir", real_config_dir)
        assert code == 1
        assert "--set is required" in err

    def test_missing_platform_is_an_error(self, run_cli, real_config_dir):
        # --type stow is the only mode that does not need a platform.
        code, _, err = run_cli(
            load_config, "--set", "server", "--config-dir", real_config_dir
        )
        assert code == 1
        assert "--platform is required" in err

    def test_stow_needs_no_platform(self, run_cli, real_config_dir):
        code, out, _ = run_cli(
            load_config,
            "--set", "server",
            "--type", "stow",
            "--config-dir", real_config_dir,
        )
        assert code == 0
        assert out.startswith("PACKAGE=(")

    @pytest.mark.parametrize(
        "argv,var",
        [
            (["--platform", "linux"], "PACKAGES_TO_INSTALL"),
            (["--platform", "macos", "--type", "formulae"], "FORMULAE_TO_INSTALL"),
            (["--platform", "macos", "--type", "casks"], "CASKS_TO_INSTALL"),
            # macOS defaults to formulae when --type is omitted.
            (["--platform", "macos"], "FORMULAE_TO_INSTALL"),
        ],
    )
    def test_each_mode_names_its_own_variable(
        self, run_cli, real_config_dir, argv, var
    ):
        code, out, _ = run_cli(
            load_config, "--set", "workstation", "--config-dir", real_config_dir, *argv
        )
        assert code == 0
        assert out.startswith(f"{var}=(")

    def test_unknown_platform_is_rejected_by_argparse(self, run_cli, real_config_dir):
        code, _, err = run_cli(
            load_config,
            "--set", "server",
            "--platform", "solaris",
            "--config-dir", real_config_dir,
        )
        assert code == 2
        assert "invalid choice" in err
