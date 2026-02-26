#!/usr/bin/env python3
"""Verifies YAML configs match the current hard-coded bash arrays.

Sources each bash script, calls parse_args for each mode, captures the
resulting arrays, and compares against what load_config.py would produce.

Usage:
    python3 verify_transition.py [--config-dir CONFIG_DIR]
"""
import argparse
import os
import subprocess
import sys

import yaml


def find_project_root():
    """Find the project root relative to this script."""
    return os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def find_config_dir(project_root):
    return os.path.join(project_root, "config")


def load_catalog(config_dir):
    with open(os.path.join(config_dir, "packages.yaml")) as f:
        return yaml.safe_load(f)


def load_set_config(config_dir, set_name):
    with open(os.path.join(config_dir, "sets", f"{set_name}.yaml")) as f:
        return yaml.safe_load(f)


def resolve_packages(catalog, group_names, platform=None):
    """Resolve group names to a flat list of package names."""
    packages = []
    for group_name in group_names:
        group = catalog["groups"][group_name]
        for pkg in group["packages"]:
            packages.append(pkg["name"])
        if platform and "platform_overrides" in group:
            overrides = group["platform_overrides"].get(platform, {})
            for pkg in overrides.get("extra_packages", []):
                packages.append(pkg["name"])
    return packages


def get_bash_array(project_root, script, mode, array_name):
    """Source a bash script, call parse_args, and capture an array."""
    script_path = os.path.join(project_root, script)
    bash_code = f'''
        source "{script_path}"
        parse_args "{mode}"
        printf '%s\\n' "${{{array_name}[@]}}"
    '''
    result = subprocess.run(
        ["bash", "-c", bash_code],
        capture_output=True, text=True, cwd=project_root
    )
    if result.returncode not in (0, 1, 2, 3):
        return None
    lines = [line for line in result.stdout.strip().split("\n") if line]
    return lines


def compare_lists(label, expected, actual):
    """Compare two lists (order-independent). Returns list of error strings."""
    errors = []
    expected_set = set(expected)
    actual_set = set(actual)

    missing = expected_set - actual_set
    extra = actual_set - expected_set

    if missing:
        errors.append(f"  {label}: YAML missing packages present in bash: {sorted(missing)}")
    if extra:
        errors.append(f"  {label}: YAML has extra packages not in bash: {sorted(extra)}")

    return errors


def main():
    parser = argparse.ArgumentParser(description="Verify YAML configs match bash arrays")
    parser.add_argument("--config-dir", help="Config directory path")
    args = parser.parse_args()

    project_root = find_project_root()
    config_dir = args.config_dir or find_config_dir(project_root)
    catalog = load_catalog(config_dir)
    errors = []
    checks = 0

    # --- Linux package install ---
    linux_modes = {
        "iot": ["gnu_core_utils", "basic_tools", "james_tools"],
        "lxc": ["gnu_core_utils", "basic_tools", "lxc_tools"],
        "server": ["gnu_core_utils", "basic_tools", "james_tools",
                    "network_security_tools", "general_utilities"],
        "workstation": ["gnu_core_utils", "basic_tools", "james_tools",
                        "network_security_tools", "general_utilities", "nerd_fonts"],
    }

    for mode in linux_modes:
        set_config = load_set_config(config_dir, mode)
        yaml_groups = set_config.get("linux", {}).get("groups", [])
        yaml_packages = resolve_packages(catalog, yaml_groups, platform="linux")

        bash_packages = get_bash_array(
            project_root, "linux-apt-package-install.sh", mode, "PACKAGES_TO_INSTALL"
        )
        if bash_packages is not None:
            errors.extend(compare_lists(f"linux/{mode}/PACKAGES_TO_INSTALL", yaml_packages, bash_packages))
            checks += 1

    # --- macOS package install ---
    macos_modes = {
        "server": {
            "formulae_groups": ["gnu_core_utils", "basic_tools", "james_tools",
                                "network_security_tools", "general_utilities"],
            "cask_groups": [],
        },
        "workstation": {
            "formulae_groups": ["gnu_core_utils", "basic_tools", "james_tools",
                                "network_security_tools", "general_utilities"],
            "cask_groups": ["nerd_fonts", "cask_apps"],
        },
    }

    for mode, group_info in macos_modes.items():
        set_config = load_set_config(config_dir, mode)

        # Formulae
        yaml_f_groups = set_config.get("macos", {}).get("formulae_groups", [])
        yaml_formulae = resolve_packages(catalog, yaml_f_groups, platform="macos")
        bash_formulae = get_bash_array(
            project_root, "osx-package-install.sh", mode, "FORMULAE_TO_INSTALL"
        )
        if bash_formulae is not None:
            errors.extend(compare_lists(f"macos/{mode}/FORMULAE_TO_INSTALL", yaml_formulae, bash_formulae))
            checks += 1

        # Casks
        yaml_c_groups = set_config.get("macos", {}).get("cask_groups", [])
        yaml_casks = resolve_packages(catalog, yaml_c_groups, platform="macos")
        bash_casks = get_bash_array(
            project_root, "osx-package-install.sh", mode, "CASKS_TO_INSTALL"
        )
        if bash_casks is not None:
            errors.extend(compare_lists(f"macos/{mode}/CASKS_TO_INSTALL", yaml_casks, bash_casks))
            checks += 1

    # --- Stow packages ---
    stow_modes = {
        "workstation": ["basic", "config resources", "fastfetch", "git", "iterm2",
                        "nvim", "oh-my-zsh", "starship", "tmux", "wezterm", "zsh"],
        "server": ["basic", "config resources", "fastfetch", "git", "nvim",
                   "tmux", "starship", "zsh"],
        "iot": ["basic", "config resources", "fastfetch", "nvim", "tmux", "zsh"],
        "lxc": ["basic", "config resources", "fastfetch", "nvim", "tmux", "zsh"],
    }

    for mode, expected_stow in stow_modes.items():
        set_config = load_set_config(config_dir, mode)
        yaml_stow = set_config.get("stow_packages", [])
        bash_stow = get_bash_array(
            project_root, "stow-packages.sh", mode, "PACKAGE"
        )
        if bash_stow is not None:
            errors.extend(compare_lists(f"stow/{mode}/PACKAGE", yaml_stow, bash_stow))
            checks += 1

    if errors:
        print(f"Transition verification FAILED ({checks} checks, {len(errors)} errors):")
        for e in errors:
            print(e)
        sys.exit(1)
    else:
        print(f"Transition verification PASSED ({checks} checks, all match).")
        sys.exit(0)


if __name__ == "__main__":
    main()
