"""API router for stow package and file management."""
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from services import stow_service

router = APIRouter()


@router.get("/packages")
def list_packages():
    return stow_service.list_packages()


class PackageCreate(BaseModel):
    name: str


@router.post("/packages")
def create_package(body: PackageCreate):
    try:
        stow_service.create_package(body.name)
    except ValueError as e:
        raise HTTPException(400, str(e))
    except FileExistsError as e:
        raise HTTPException(409, str(e))
    return {"created": body.name}


@router.delete("/packages/{name}")
def delete_package(name: str):
    try:
        stow_service.delete_package(name)
    except ValueError as e:
        raise HTTPException(400, str(e))
    except FileNotFoundError as e:
        raise HTTPException(404, str(e))
    except PermissionError as e:
        raise HTTPException(403, str(e))
    return {"deleted": name}


@router.get("/packages/{name}/files")
def list_files(name: str):
    try:
        return {"name": name, "files": stow_service.list_files(name)}
    except ValueError as e:
        raise HTTPException(400, str(e))
    except FileNotFoundError as e:
        raise HTTPException(404, str(e))


@router.get("/packages/{name}/files/{file_path:path}")
def read_file(name: str, file_path: str):
    try:
        content = stow_service.read_file(name, file_path)
    except FileNotFoundError as e:
        raise HTTPException(404, str(e))
    except ValueError as e:
        raise HTTPException(403, str(e))
    return {"path": file_path, "content": content}


class FileWrite(BaseModel):
    content: str


@router.put("/packages/{name}/files/{file_path:path}")
def write_file(name: str, file_path: str, body: FileWrite):
    try:
        stow_service.write_file(name, file_path, body.content)
    except FileNotFoundError as e:
        raise HTTPException(404, str(e))
    except ValueError as e:
        raise HTTPException(403, str(e))
    return {"path": file_path, "written": True}


@router.delete("/packages/{name}/files/{file_path:path}")
def delete_file(name: str, file_path: str):
    try:
        stow_service.delete_file(name, file_path)
    except FileNotFoundError as e:
        raise HTTPException(404, str(e))
    except ValueError as e:
        raise HTTPException(403, str(e))
    return {"path": file_path, "deleted": True}
