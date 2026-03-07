"""API router for package catalog management."""
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from services import config_service

router = APIRouter()


@router.get("/")
def get_catalog():
    return config_service.load_catalog()


@router.get("/groups")
def list_groups():
    catalog = config_service.load_catalog()
    groups = catalog.get("groups", {})
    return [
        {
            "name": name,
            "description": defn.get("description", ""),
            "package_count": len(defn.get("packages", [])),
            "platform": defn.get("platform"),
            "install_type": defn.get("install_type"),
        }
        for name, defn in groups.items()
    ]


@router.get("/groups/{name}")
def get_group(name: str):
    catalog = config_service.load_catalog()
    groups = catalog.get("groups", {})
    if name not in groups:
        raise HTTPException(404, f"Group '{name}' not found")
    return {"name": name, **groups[name]}


class GroupUpdate(BaseModel):
    description: str | None = None
    packages: list[dict] | None = None
    platform: str | None = None
    install_type: str | None = None
    platform_overrides: dict | None = None


@router.put("/groups/{name}")
def update_group(name: str, body: GroupUpdate):
    catalog = config_service.load_catalog()
    groups = catalog.get("groups", {})
    if name not in groups:
        raise HTTPException(404, f"Group '{name}' not found")

    if body.description is not None:
        groups[name]["description"] = body.description
    if body.packages is not None:
        groups[name]["packages"] = body.packages
    if body.platform is not None:
        groups[name]["platform"] = body.platform
    if body.install_type is not None:
        groups[name]["install_type"] = body.install_type
    if body.platform_overrides is not None:
        groups[name]["platform_overrides"] = body.platform_overrides

    config_service.save_catalog(catalog)
    return {"name": name, **groups[name]}


class GroupCreate(BaseModel):
    name: str
    description: str = ""
    packages: list[dict] = []


@router.post("/groups")
def create_group(body: GroupCreate):
    catalog = config_service.load_catalog()
    groups = catalog.get("groups", {})
    if body.name in groups:
        raise HTTPException(409, f"Group '{body.name}' already exists")
    groups[body.name] = {"description": body.description, "packages": body.packages}
    config_service.save_catalog(catalog)
    return {"name": body.name, **groups[body.name]}


@router.delete("/groups/{name}")
def delete_group(name: str):
    catalog = config_service.load_catalog()
    groups = catalog.get("groups", {})
    if name not in groups:
        raise HTTPException(404, f"Group '{name}' not found")
    del groups[name]
    config_service.save_catalog(catalog)
    return {"deleted": name}


class StowPackagesUpdate(BaseModel):
    stow_packages: list[str]


@router.put("/stow-packages")
def update_stow_packages(body: StowPackagesUpdate):
    catalog = config_service.load_catalog()
    catalog["stow_packages"] = body.stow_packages
    config_service.save_catalog(catalog)
    return {"stow_packages": body.stow_packages}


@router.post("/validate")
def validate():
    errors = config_service.validate_all()
    if errors:
        return {"valid": False, "errors": errors}
    return {"valid": True, "errors": []}
