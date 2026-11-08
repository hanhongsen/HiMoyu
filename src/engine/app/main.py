"""FastAPI 入口。"""

from __future__ import annotations

from pathlib import Path

from fastapi import FastAPI
from fastapi.responses import RedirectResponse
from fastapi.staticfiles import StaticFiles

from app import config
from app.api import routes_mock, routes_state, ws

SIMULATOR_DIR = Path(__file__).resolve().parents[1] / "simulator"

app = FastAPI(title=config.APP_NAME, version=config.APP_VERSION)

app.include_router(routes_state.router)
app.include_router(routes_mock.router)
app.include_router(ws.router)
app.mount("/sim", StaticFiles(directory=str(SIMULATOR_DIR), html=True), name="simulator")


@app.get("/", include_in_schema=False)
async def index() -> RedirectResponse:
    return RedirectResponse(url="/sim/")
