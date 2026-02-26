#!/usr/bin/env python3
"""Reads YAML config and outputs bash variable assignments.

Usage:
    python3 load_config.py --set server --platform linux
    python3 load_config.py --set workstation --platform macos --type formulae
    python3 load_config.py --set workstation --platform macos --type casks
    python3 load_config.py --set server --type stow
"""
import argparse
import os
import sys

import yaml


def find_config_dir():
    """Find the config directory relative to this script."""
    script_dir = os.path.dirname(os.path.abspath(__file__))
    return os.path.join(os.path.dirname(script_dir), "config")


def load_catalog(config_dir):
    """Load the master packages.yaml catalog."""
    path = os.path.join(config_dir, "packages.yaml")
    with open(path) as f:
        return yaml.safe_load(f)


def load_set_config(config_dir, set_name):
    """Load a set configuration file."""
    path = os.path.join(config_dir, "sets", f"{set_name}.yaml")
    with open(path) as f:
        return yaml.safe_load(f)


def resolve_packages(catalog, group_names, platform=None):
    """Resolve group names to a flat list of package names.

    Applies platform_overrides when platform is specified.
    """
    packages = []
    for group_name in group_names:
        group = catalog["groups"][group_name]
        for pkg in group["packages"]:
            packages.append(pkg["name"])
        # Apply platform overrides
        if platform and "platform_overrides" in group:
            overrides = group["platform_overrides"].get(platform, {})
            for pkg in overrides.get("extra_packages", []):
                packages.append(pkg["name"])
    return packages


def format_bash_array(var_name, values):
    """Format a list of values as a bash array assignment."""
    escaped = []
    for v in values:
        escaped.append(f'"{v}"')
    return f'{var_name}=({" ".join(escaped)})'


def main():
    parser = argparse.ArgumentParser(description="Load YAML config as bash variables")
    parser.add_argument("--set", required=True, help="Set name (server, workstation, iot, lxc)")
    parser.add_argument("--platform", choices=["linux", "macos"], help="Target platform")
    parser.add_argument("--type", choices=["formulae", "casks", "stow"],
                        help="Output type (default: platform packages)")
    parser.add_argument("--config-dir", help="Config directory path (auto-detected if not set)")
    args = parser.parse_args()

    config_dir = args.config_dir or find_config_dir()
    catalog = load_catalog(config_dir)
    set_config = load_set_config(config_dir, args.set)

    if args.type == "stow":
        print(format_bash_array("PACKAGE", set_config["stow_packages"]))
        return

    if not args.platform:
        print("Error: --platform is required when --type is not 'stow'", file=sys.stderr)
        sys.exit(1)

    if args.platform == "linux":
        groups = set_config.get("linux", {}).get("groups", [])
        packages = resolve_packages(catalog, groups, platform="linux")
        print(format_bash_array("PACKAGES_TO_INSTALL", packages))

    elif args.platform == "macos":
        output_type = args.type or "formulae"
        if output_type == "formulae":
            groups = set_config.get("macos", {}).get("formulae_groups", [])
            packages = resolve_packages(catalog, groups, platform="macos")
            print(format_bash_array("FORMULAE_TO_INSTALL", packages))
        elif output_type == "casks":
            groups = set_config.get("macos", {}).get("cask_groups", [])
            packages = resolve_packages(catalog, groups, platform="macos")
            print(format_bash_array("CASKS_TO_INSTALL", packages))


if __name__ == "__main__":
    main()
