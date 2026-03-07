"""Service for filesystem operations on stow package directories."""
import os
import shutil
from pathlib import Path

from services.config_service import PROJECT_ROOT, load_catalog, save_catalog

# Directories at the project root that are NOT stow packages
NON_STOW_DIRS = {
    ".claude", ".git", ".github", "config", "test", "tools", "web",
}


def compute_target(rel_path: str) -> str:
    """Convert a stow package-relative path to its home directory target.

    Applies the --dotfiles convention: leading 'dot-' becomes '.'
    """
    parts = Path(rel_path).parts
    converted = []
    for part in parts:
        if part.startswith("dot-"):
            converted.append("." + part[4:])
        else:
            converted.append(part)
    return "~/" + str(Path(*converted))


def list_packages() -> list[dict]:
    """List stow package directories at the project root."""
    catalog = load_catalog()
    catalog_stow = set(catalog.get("stow_packages", []))

    packages = []
    for entry in sorted(PROJECT_ROOT.iterdir()):
        if not entry.is_dir():
            continue
        if entry.name.startswith("."):
            continue
        if entry.name in NON_STOW_DIRS:
            continue

        file_count = sum(1 for _ in entry.rglob("*") if _.is_file())
        packages.append({
            "name": entry.name,
            "file_count": file_count,
            "in_catalog": entry.name in catalog_stow,
        })
    return packages


def create_package(name: str) -> None:
    """Create a new stow package directory and add it to the catalog."""
    pkg_dir = PROJECT_ROOT / name
    if pkg_dir.exists():
        raise FileExistsError(f"Directory '{name}' already exists")
    pkg_dir.mkdir()

    catalog = load_catalog()
    stow_pkgs = catalog.get("stow_packages", [])
    if name not in stow_pkgs:
        stow_pkgs.append(name)
        stow_pkgs.sort()
        catalog["stow_packages"] = stow_pkgs
        save_catalog(catalog)


def delete_package(name: str) -> None:
    """Delete a stow package directory and remove it from the catalog."""
    pkg_dir = PROJECT_ROOT / name
    if not pkg_dir.exists():
        raise FileNotFoundError(f"Package '{name}' not found")
    if name in NON_STOW_DIRS:
        raise PermissionError(f"Cannot delete non-stow directory '{name}'")

    shutil.rmtree(pkg_dir)

    catalog = load_catalog()
    stow_pkgs = catalog.get("stow_packages", [])
    if name in stow_pkgs:
        stow_pkgs.remove(name)
        catalog["stow_packages"] = stow_pkgs
        save_catalog(catalog)


def list_files(package_name: str) -> list[dict]:
    """List all files in a stow package with their target paths."""
    pkg_dir = PROJECT_ROOT / package_name
    if not pkg_dir.exists():
        raise FileNotFoundError(f"Package '{package_name}' not found")

    files = []
    for path in sorted(pkg_dir.rglob("*")):
        if path.is_file():
            rel = str(path.relative_to(pkg_dir))
            files.append({
                "path": rel,
                "target": compute_target(rel),
                "size": path.stat().st_size,
            })
    return files


def read_file(package_name: str, file_path: str) -> str:
    """Read a file's contents from a stow package."""
    full_path = PROJECT_ROOT / package_name / file_path
    if not full_path.exists():
        raise FileNotFoundError(f"File not found: {package_name}/{file_path}")
    # Ensure path doesn't escape the package directory
    full_path.resolve().relative_to((PROJECT_ROOT / package_name).resolve())
    return full_path.read_text(errors="replace")


def write_file(package_name: str, file_path: str, content: str) -> None:
    """Create or update a file in a stow package."""
    pkg_dir = PROJECT_ROOT / package_name
    if not pkg_dir.exists():
        raise FileNotFoundError(f"Package '{package_name}' not found")

    full_path = pkg_dir / file_path
    # Ensure path doesn't escape the package directory
    full_path.resolve().relative_to(pkg_dir.resolve())
    full_path.parent.mkdir(parents=True, exist_ok=True)
    full_path.write_text(content)


def delete_file(package_name: str, file_path: str) -> None:
    """Delete a file from a stow package."""
    full_path = PROJECT_ROOT / package_name / file_path
    if not full_path.exists():
        raise FileNotFoundError(f"File not found: {package_name}/{file_path}")
    full_path.resolve().relative_to((PROJECT_ROOT / package_name).resolve())
    full_path.unlink()

    # Clean up empty parent directories
    parent = full_path.parent
    while parent != PROJECT_ROOT / package_name:
        if not any(parent.iterdir()):
            parent.rmdir()
            parent = parent.parent
        else:
            break
