"""Service for loading, saving, and validating YAML configuration files."""
import glob
import json
import os
from pathlib import Path
from typing import Any

import jsonschema
import yaml

from services.validation import validate_name

PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent.parent
CONFIG_DIR = PROJECT_ROOT / "config"
SETS_DIR = CONFIG_DIR / "sets"
SCHEMA_DIR = CONFIG_DIR / "schema"


def load_yaml(path: Path) -> dict:
    with open(path) as f:
        return yaml.safe_load(f) or {}


def save_yaml(path: Path, data: dict) -> None:
    with open(path, "w") as f:
        yaml.dump(data, f, default_flow_style=False, sort_keys=False, allow_unicode=True)


def load_json(path: Path) -> dict:
    with open(path) as f:
        return json.load(f)


# --- Catalog ---

def load_catalog() -> dict:
    return load_yaml(CONFIG_DIR / "packages.yaml")


def save_catalog(data: dict) -> None:
    save_yaml(CONFIG_DIR / "packages.yaml", data)


# --- Sets ---

def list_sets() -> list[dict]:
    """Return list of {name, description} for each set."""
    results = []
    for path in sorted(SETS_DIR.glob("*.yaml")):
        cfg = load_yaml(path)
        results.append({
            "name": path.stem,
            "description": cfg.get("description", ""),
        })
    return results


def load_set(name: str) -> dict:
    validate_name(name, "set name")
    path = SETS_DIR / f"{name}.yaml"
    if not path.exists():
        raise FileNotFoundError(f"Set '{name}' not found")
    return load_yaml(path)


def save_set(name: str, data: dict) -> None:
    validate_name(name, "set name")
    data["name"] = name
    save_yaml(SETS_DIR / f"{name}.yaml", data)


def delete_set(name: str) -> None:
    validate_name(name, "set name")
    path = SETS_DIR / f"{name}.yaml"
    if not path.exists():
        raise FileNotFoundError(f"Set '{name}' not found")
    path.unlink()


# --- Resolution ---

def resolve_packages(catalog: dict, group_names: list[str], platform: str | None = None) -> list[dict]:
    """Resolve group names to a list of {name, group} dicts with platform awareness."""
    packages = []
    for group_name in group_names:
        group = catalog["groups"].get(group_name, {})
        for pkg in group.get("packages", []):
            packages.append({"name": pkg["name"], "group": group_name})
        if platform and "platform_overrides" in group:
            overrides = group["platform_overrides"].get(platform, {})
            for pkg in overrides.get("extra_packages", []):
                packages.append({"name": pkg["name"], "group": group_name})
    return packages


def resolve_set(name: str) -> dict:
    """Resolve a set to its full package lists per platform."""
    catalog = load_catalog()
    set_config = load_set(name)

    linux_groups = set_config.get("linux", {}).get("groups", [])
    macos_formulae_groups = set_config.get("macos", {}).get("formulae_groups", [])
    macos_cask_groups = set_config.get("macos", {}).get("cask_groups", [])

    return {
        "name": name,
        "linux": resolve_packages(catalog, linux_groups, "linux"),
        "macos_formulae": resolve_packages(catalog, macos_formulae_groups, "macos"),
        "macos_casks": resolve_packages(catalog, macos_cask_groups, "macos"),
        "stow": set_config.get("stow_packages", []),
    }


def compare_sets(set_names: list[str]) -> dict:
    """Build a comparison view: union of all packages across sets, grouped."""
    catalog = load_catalog()
    all_groups = catalog.get("groups", {})

    # Collect which groups each set uses, per platform
    set_configs = {}
    for name in set_names:
        set_configs[name] = load_set(name)

    # Build union of all referenced groups across all sets
    all_referenced_groups: set[str] = set()
    for cfg in set_configs.values():
        all_referenced_groups.update(cfg.get("linux", {}).get("groups", []))
        all_referenced_groups.update(cfg.get("macos", {}).get("formulae_groups", []))
        all_referenced_groups.update(cfg.get("macos", {}).get("cask_groups", []))

    # For each group, build package rows with per-set platform info
    groups_result = []
    for group_name in all_groups:
        if group_name not in all_referenced_groups:
            continue

        group_def = all_groups[group_name]
        base_packages = [pkg["name"] for pkg in group_def.get("packages", [])]

        # Collect platform override packages
        override_packages: dict[str, set[str]] = {"linux": set(), "macos": set()}
        if "platform_overrides" in group_def:
            for plat in ("linux", "macos"):
                extras = group_def["platform_overrides"].get(plat, {}).get("extra_packages", [])
                for pkg in extras:
                    override_packages[plat].add(pkg["name"])

        # Union of all package names (base + all overrides)
        all_pkg_names = list(base_packages)
        for plat_pkgs in override_packages.values():
            for p in plat_pkgs:
                if p not in all_pkg_names:
                    all_pkg_names.append(p)

        packages_result = []
        for pkg_name in all_pkg_names:
            is_base = pkg_name in base_packages
            pkg_sets = {}
            for sname, cfg in set_configs.items():
                linux_groups = cfg.get("linux", {}).get("groups", [])
                macos_f_groups = cfg.get("macos", {}).get("formulae_groups", [])
                macos_c_groups = cfg.get("macos", {}).get("cask_groups", [])

                # Linux: package is present if group in linux.groups AND
                # (package is base OR is a linux override)
                on_linux = (group_name in linux_groups and
                            (is_base or pkg_name in override_packages["linux"]))

                # macOS formula: group in formulae_groups
                on_macos_formula = (group_name in macos_f_groups and
                                    (is_base or pkg_name in override_packages["macos"]))

                # macOS cask: group in cask_groups
                on_macos_cask = (group_name in macos_c_groups and
                                 (is_base or pkg_name in override_packages["macos"]))

                macos_val: str | bool = False
                if on_macos_cask:
                    macos_val = "cask"
                elif on_macos_formula:
                    macos_val = "formula"

                pkg_sets[sname] = {"linux": on_linux, "macos": macos_val}

            packages_result.append({"name": pkg_name, "sets": pkg_sets})

        groups_result.append({
            "name": group_name,
            "description": group_def.get("description", ""),
            "packages": packages_result,
        })

    return {"sets": set_names, "groups": groups_result}


# --- Validation ---

def validate_all() -> list[str]:
    """Run full validation. Returns list of error strings (empty = valid)."""
    errors = []

    packages_schema = load_json(SCHEMA_DIR / "packages-schema.json")
    set_schema = load_json(SCHEMA_DIR / "set-schema.json")

    catalog = load_yaml(CONFIG_DIR / "packages.yaml")
    validator = jsonschema.Draft202012Validator(packages_schema)
    for error in validator.iter_errors(catalog):
        path = ".".join(str(p) for p in error.absolute_path) if error.absolute_path else "(root)"
        errors.append(f"packages.yaml: {path}: {error.message}")

    valid_groups = set(catalog.get("groups", {}).keys())
    valid_stow = set(catalog.get("stow_packages", []))
    macos_only_groups = {
        g for g, d in catalog.get("groups", {}).items()
        if d.get("platform") == "macos_only"
    }

    set_files = sorted(SETS_DIR.glob("*.yaml"))
    if not set_files:
        errors.append("No set files found in config/sets/")

    for set_path in set_files:
        filename = set_path.name
        set_config = load_yaml(set_path)

        v = jsonschema.Draft202012Validator(set_schema)
        for error in v.iter_errors(set_config):
            path = ".".join(str(p) for p in error.absolute_path) if error.absolute_path else "(root)"
            errors.append(f"{filename}: {path}: {error.message}")

        expected_name = set_path.stem
        if set_config.get("name", "") != expected_name:
            errors.append(f"{filename}: name mismatch: file is '{expected_name}' but name field is '{set_config.get('name', '')}'")

        for pkg in set_config.get("stow_packages", []):
            if pkg not in valid_stow:
                errors.append(f"{filename}: stow_packages: '{pkg}' not in catalog stow_packages")

        for group in set_config.get("linux", {}).get("groups", []):
            if group not in valid_groups:
                errors.append(f"{filename}: linux.groups: unknown group '{group}'")
            if group in macos_only_groups:
                errors.append(f"{filename}: linux.groups: '{group}' is macos_only")

        for group in set_config.get("macos", {}).get("formulae_groups", []):
            if group not in valid_groups:
                errors.append(f"{filename}: macos.formulae_groups: unknown group '{group}'")
        for group in set_config.get("macos", {}).get("cask_groups", []):
            if group not in valid_groups:
                errors.append(f"{filename}: macos.cask_groups: unknown group '{group}'")

    return errors
