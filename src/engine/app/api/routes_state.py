"""场次状态与调试接口。"""

from __future__ import annotations

from fastapi import APIRouter

from app import config
from app.realtime.hub import hub
from app.realtime.protocol import build_snapshot
from app.runtime import get_state, reset_state, state_lock

router = APIRouter(prefix="/api", tags=["state"])


@router.get("/health")
async def health() -> dict:
    return {"status": "ok", "app": config.APP_NAME, "version": config.APP_VERSION}


@router.get("/state")
async def read_state() -> dict:
    return build_snapshot(get_state())


@router.post("/session/reset")
async def reset_session() -> dict:
    async with state_lock:
        state = reset_state()
        snapshot = build_snapshot(state)
        await hub.broadcast(snapshot)
    return snapshot
