"""WebSocket 入口：连接后先发送全量快照，随后处理心跳。"""

from __future__ import annotations

import json

from fastapi import APIRouter, WebSocket, WebSocketDisconnect

from app.domain.models import utc_now_iso
from app.realtime.hub import hub
from app.realtime.protocol import build_snapshot
from app.runtime import get_state

router = APIRouter()


@router.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket) -> None:
    await hub.connect(websocket)
    await websocket.send_json(build_snapshot(get_state()))

    try:
        while True:
            raw = await websocket.receive_text()
            try:
                message = json.loads(raw)
            except json.JSONDecodeError:
                continue
            if isinstance(message, dict) and message.get("type") == "ping":
                await websocket.send_json({"type": "pong", "server_time": utc_now_iso()})
    except WebSocketDisconnect:
        hub.disconnect(websocket)
    except Exception:
        hub.disconnect(websocket)
        raise
