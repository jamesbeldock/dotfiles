"""Unit tests for tools/validate_config.py.

Scope: the cross-validation branches in main(), each driven by a deliberately
broken config tree. test/validate-config.bats keeps a handful of the same
checks at the subprocess level to prove the exit codes reach the shell.
"""
import pytest

import validate_config


VALID_SET = """
    name: extra
    stow_packages:
    - basic
    linux:
      groups:
      - gnu_core_utils
"""


class TestValidConfig:
    def test_real_config_passes(self, run_cli, real_config_dir):
        code, out, _ = run_cli(validate_config, "--config-dir", real_config_dir)
        assert code == 0
        assert "All config files valid" in out

    def test_reports_the_number_of_sets_validated(self, run_cli, real_config_dir):
        code, out, _ = run_cli(validate_config, "--config-dir", real_config_dir)
        assert code == 0
        assert "(4 sets validated)" in out

    def test_a_well_formed_extra_set_still_passes(self, run_cli, write_set):
        cfg = write_set("extra", VALID_SET)
        code, out, _ = run_cli(validate_config, "--config-dir", cfg)
        assert code == 0
        assert "(5 sets validated)" in out


class TestCrossValidation:
    @pytest.mark.parametrize(
        "name,body,expected",
        [
            pytest.param(
                "bad",
                """
                name: bad
                stow_packages:
                - basic
                linux:
                  groups:
                  - nonexistent_group
                """,
                "linux.groups: unknown group 'nonexistent_group'",
                id="unknown-linux-group",
            ),
            pytest.param(
                "bad",
                """
                name: bad
                stow_packages:
                - basic
                macos:
                  formulae_groups:
                  - nonexistent_group
                """,
                "macos.formulae_groups: unknown group 'nonexistent_group'",
                id="unknown-formulae-group",
            ),
            pytest.param(
                "bad",
                """
                name: bad
                stow_packages:
                - basic
                macos:
                  cask_groups:
                  - nonexistent_group
                """,
                "macos.cask_groups: unknown group 'nonexistent_group'",
                id="unknown-cask-group",
            ),
            pytest.param(
                "bad",
                """
                name: bad
                stow_packages:
                - nonexistent_package
                """,
                "'nonexistent_package' not in catalog stow_packages",
                id="unknown-stow-package",
            ),
            pytest.param(
                "mismatch",
                """
                name: wrong_name
                stow_packages:
                - basic
                """,
                "name mismatch: file is 'mismatch' but name field is 'wrong_name'",
                id="filename-name-mismatch",
            ),
            pytest.param(
                "bad",
                """
                name: bad
                stow_packages:
                - basic
                linux:
                  groups:
                  - cask_apps
                """,
                "linux.groups: 'cask_apps' is macos_only",
                id="macos-only-group-on-linux",
            ),
        ],
    )
    def test_rejects_bad_set(self, run_cli, write_set, name, body, expected):
        cfg = write_set(name, body)
        code, out, _ = run_cli(validate_config, "--config-dir", cfg)
        assert code == 1
        assert "Validation FAILED" in out
        assert expected in out

    def test_a_macos_only_group_is_fine_under_macos(self, run_cli, write_set):
        cfg = write_set("okay", """
            name: okay
            stow_packages:
            - basic
            macos:
              cask_groups:
              - cask_apps
        """)
        code, _, _ = run_cli(validate_config, "--config-dir", cfg)
        assert code == 0

    def test_all_errors_are_reported_together(self, run_cli, write_set):
        # main() accumulates into one list rather than failing fast, so a
        # single run should surface every problem in the file.
        cfg = write_set("bad", """
            name: wrong_name
            stow_packages:
            - nonexistent_package
            linux:
              groups:
              - nonexistent_group
        """)
        code, out, _ = run_cli(validate_config, "--config-dir", cfg)
        assert code == 1
        assert "name mismatch" in out
        assert "not in catalog stow_packages" in out
        assert "unknown group" in out


class TestSchemaValidation:
    def test_missing_required_field_is_caught(self, run_cli, write_set):
        cfg = write_set("bad", """
            name: bad
        """)
        code, out, _ = run_cli(validate_config, "--config-dir", cfg)
        assert code == 1
        assert "stow_packages" in out

    def test_unknown_top_level_key_is_caught(self, run_cli, write_set):
        # set-schema.json sets additionalProperties: false, so a typo'd key
        # is an error rather than being silently ignored.
        cfg = write_set("bad", """
            name: bad
            stow_packages:
            - basic
            windows:
              groups: []
        """)
        code, out, _ = run_cli(validate_config, "--config-dir", cfg)
        assert code == 1
        assert "windows" in out

    def test_wrong_type_is_caught(self, run_cli, write_set):
        cfg = write_set("bad", """
            name: bad
            stow_packages: basic
        """)
        code, out, _ = run_cli(validate_config, "--config-dir", cfg)
        assert code == 1
        assert "bad.yaml" in out


class TestValidateSchemaHelper:
    """validate_schema() is pure -- exercise it without touching the filesystem."""

    SCHEMA = {
        "type": "object",
        "required": ["name"],
        "properties": {"name": {"type": "string"}},
    }

    def test_valid_data_yields_no_errors(self):
        assert validate_config.validate_schema({"name": "ok"}, self.SCHEMA, "f.yaml") == []

    def test_error_is_prefixed_with_the_filename(self):
        errors = validate_config.validate_schema({}, self.SCHEMA, "f.yaml")
        assert len(errors) == 1
        assert errors[0].strip().startswith("f.yaml:")

    def test_nested_path_is_rendered_dotted(self):
        schema = {
            "type": "object",
            "properties": {
                "macos": {
                    "type": "object",
                    "properties": {"cask_groups": {"type": "array"}},
                }
            },
        }
        errors = validate_config.validate_schema(
            {"macos": {"cask_groups": "not-a-list"}}, schema, "f.yaml"
        )
        assert len(errors) == 1
        assert "macos.cask_groups" in errors[0]

    def test_root_level_error_is_labelled_root(self):
        errors = validate_config.validate_schema([], self.SCHEMA, "f.yaml")
        assert len(errors) == 1
        assert "(root)" in errors[0]


class TestEmptyConfigTree:
    def test_no_set_files_is_an_error(self, run_cli, config_dir):
        for path in (config_dir / "sets").glob("*.yaml"):
            path.unlink()
        code, out, _ = run_cli(validate_config, "--config-dir", config_dir)
        assert code == 1
        assert "No set files found" in out

    def test_a_broken_catalog_reports_instead_of_crashing(self, run_cli, config_dir):
        # A structurally invalid packages.yaml must produce a readable
        # failure, not a traceback out of the cross-validation below it.
        (config_dir / "packages.yaml").write_text("groups: not-a-mapping\n")
        code, out, _ = run_cli(validate_config, "--config-dir", config_dir)
        assert code == 1
        assert "Validation FAILED" in out
        assert "packages.yaml" in out
