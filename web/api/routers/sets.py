"""API router for configuration set management."""
from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel

from services import config_service

router = APIRouter()


@router.get("/")
def list_sets():
    return config_service.list_sets()


@router.get("/compare")
def compare_sets(sets: str = Query(..., description="Comma-separated set names")):
    set_names = [s.strip() for s in sets.split(",") if s.strip()]
    if len(set_names) < 1:
        raise HTTPException(400, "At least one set name required")
    try:
        return config_service.compare_sets(set_names)
    except FileNotFoundError as e:
        raise HTTPException(404, str(e))


@router.get("/{name}")
def get_set(name: str):
    try:
        return config_service.load_set(name)
    except FileNotFoundError:
        raise HTTPException(404, f"Set '{name}' not found")


@router.get("/{name}/resolved")
def get_resolved_set(name: str):
    try:
        return config_service.resolve_set(name)
    except FileNotFoundError:
        raise HTTPException(404, f"Set '{name}' not found")


class SetCreate(BaseModel):
    name: str
    description: str = ""
    stow_packages: list[str] = []
    linux: dict | None = None
    macos: dict | None = None


@router.post("/")
def create_set(body: SetCreate):
    existing = [s["name"] for s in config_service.list_sets()]
    if body.name in existing:
        raise HTTPException(409, f"Set '{body.name}' already exists")

    data = {"name": body.name, "description": body.description, "stow_packages": body.stow_packages}
    if body.linux:
        data["linux"] = body.linux
    if body.macos:
        data["macos"] = body.macos

    config_service.save_set(body.name, data)
    return data


class SetUpdate(BaseModel):
    description: str | None = None
    stow_packages: list[str] | None = None
    linux: dict | None = None
    macos: dict | None = None


@router.put("/{name}")
def update_set(name: str, body: SetUpdate):
    try:
        existing = config_service.load_set(name)
    except FileNotFoundError:
        raise HTTPException(404, f"Set '{name}' not found")

    if body.description is not None:
        existing["description"] = body.description
    if body.stow_packages is not None:
        existing["stow_packages"] = body.stow_packages
    if body.linux is not None:
        existing["linux"] = body.linux
    if body.macos is not None:
        existing["macos"] = body.macos

    config_service.save_set(name, existing)
    return existing


@router.delete("/{name}")
def delete_set(name: str):
    try:
        config_service.delete_set(name)
    except FileNotFoundError:
        raise HTTPException(404, f"Set '{name}' not found")
    return {"deleted": name}
