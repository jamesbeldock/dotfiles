"""FastAPI application for managing dotfiles configuration."""
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from routers import catalog, sets, stow

PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent

app = FastAPI(title="Dotfiles Config Manager")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:5173"],
    allow_methods=["GET", "POST", "PUT", "DELETE"],
    allow_headers=["Content-Type"],
)

app.include_router(catalog.router, prefix="/api/catalog", tags=["catalog"])
app.include_router(sets.router, prefix="/api/sets", tags=["sets"])
app.include_router(stow.router, prefix="/api/stow", tags=["stow"])


@app.get("/api/health")
def health():
    return {"status": "ok"}


# Serve frontend build if it exists
frontend_dist = Path(__file__).resolve().parent.parent / "frontend" / "dist"
if frontend_dist.is_dir():
    app.mount("/", StaticFiles(directory=str(frontend_dist), html=True), name="frontend")
