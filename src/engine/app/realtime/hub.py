"""WebSocket 连接管理。"""

from __future__ import annotations

from fastapi import WebSocket


class ConnectionHub:
    def __init__(self) -> None:
        self._connections: list[WebSocket] = []

    async def connect(self, websocket: WebSocket) -> None:
        await websocket.accept()
        self._connections.append(websocket)

    def disconnect(self, websocket: WebSocket) -> None:
        if websocket in self._connections:
            self._connections.remove(websocket)

    async def broadcast(self, payload: dict) -> None:
        for websocket in list(self._connections):
            try:
                await websocket.send_json(payload)
            except Exception:
                self.disconnect(websocket)


hub = ConnectionHub()
