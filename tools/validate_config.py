#!/usr/bin/env python3
"""Validates YAML config files against JSON schemas and cross-validates references.

Usage:
    python3 validate_config.py [--config-dir CONFIG_DIR]
"""
import argparse
import glob
import json
import os
import sys

import jsonschema
import yaml


def find_config_dir():
    """Find the config directory relative to this script."""
    script_dir = os.path.dirname(os.path.abspath(__file__))
    return os.path.join(os.path.dirname(script_dir), "config")


def load_json(path):
    with open(path) as f:
        return json.load(f)


def load_yaml(path):
    with open(path) as f:
        return yaml.safe_load(f)


def validate_schema(data, schema, filename):
    """Validate data against a JSON schema. Returns list of error strings."""
    errors = []
    validator = jsonschema.Draft202012Validator(schema)
    for error in validator.iter_errors(data):
        path = ".".join(str(p) for p in error.absolute_path) if error.absolute_path else "(root)"
        errors.append(f"  {filename}: {path}: {error.message}")
    return errors


def main():
    parser = argparse.ArgumentParser(description="Validate YAML config files")
    parser.add_argument("--config-dir", help="Config directory path (auto-detected if not set)")
    args = parser.parse_args()

    config_dir = args.config_dir or find_config_dir()
    schema_dir = os.path.join(config_dir, "schema")
    errors = []

    # Load schemas
    packages_schema = load_json(os.path.join(schema_dir, "packages-schema.json"))
    set_schema = load_json(os.path.join(schema_dir, "set-schema.json"))

    # Validate packages.yaml
    packages_path = os.path.join(config_dir, "packages.yaml")
    catalog = load_yaml(packages_path)
    errors.extend(validate_schema(catalog, packages_schema, "packages.yaml"))

    # Collect valid group names and stow packages from catalog
    valid_groups = set(catalog.get("groups", {}).keys())
    valid_stow = set(catalog.get("stow_packages", []))
    macos_only_groups = set()
    for group_name, group_def in catalog.get("groups", {}).items():
        if group_def.get("platform") == "macos_only":
            macos_only_groups.add(group_name)

    # Validate each set file
    sets_dir = os.path.join(config_dir, "sets")
    set_files = sorted(glob.glob(os.path.join(sets_dir, "*.yaml")))

    if not set_files:
        errors.append("No set files found in config/sets/")

    for set_path in set_files:
        filename = os.path.basename(set_path)
        set_config = load_yaml(set_path)

        # Schema validation
        errors.extend(validate_schema(set_config, set_schema, filename))

        # Cross-validate: stow packages exist in catalog
        for pkg in set_config.get("stow_packages", []):
            if pkg not in valid_stow:
                errors.append(f"  {filename}: stow_packages: '{pkg}' not in catalog stow_packages")

        # Cross-validate: linux group names exist
        for group in set_config.get("linux", {}).get("groups", []):
            if group not in valid_groups:
                errors.append(f"  {filename}: linux.groups: unknown group '{group}'")
            if group in macos_only_groups:
                errors.append(f"  {filename}: linux.groups: '{group}' is macos_only")

        # Cross-validate: macos group names exist
        for group in set_config.get("macos", {}).get("formulae_groups", []):
            if group not in valid_groups:
                errors.append(f"  {filename}: macos.formulae_groups: unknown group '{group}'")
        for group in set_config.get("macos", {}).get("cask_groups", []):
            if group not in valid_groups:
                errors.append(f"  {filename}: macos.cask_groups: unknown group '{group}'")

    if errors:
        print("Validation FAILED:")
        for e in errors:
            print(e)
        sys.exit(1)
    else:
        print(f"All config files valid ({len(set_files)} sets validated).")
        sys.exit(0)


if __name__ == "__main__":
    main()
