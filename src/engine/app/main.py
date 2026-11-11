"""FastAPI 入口。"""

from __future__ import annotations

import asyncio
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi.responses import RedirectResponse
from fastapi.staticfiles import StaticFiles

from app import config
from app.api import routes_mock, routes_state, ws
from app.realtime.hub import hub
from app.realtime.protocol import build_snapshot
from app.runtime import get_state, state_lock

SIMULATOR_DIR = Path(__file__).resolve().parents[1] / "simulator"

# 后台过期检查任务句柄（用于 shutdown 时正确取消）
_expire_task: asyncio.Task | None = None


async def _expire_loop() -> None:
    """后台循环：每 EXPIRE_CHECK_INTERVAL 秒检查一次动作到期。

    只有当 expire_actions() 返回 True（有动作实际变化）时，
    才构建快照并广播给所有 WebSocket 客户端。
    """
    while True:
        try:
            await asyncio.sleep(config.EXPIRE_CHECK_INTERVAL)
            async with state_lock:
                state = get_state()
                if state.expire_actions():
                    snapshot = build_snapshot(state)
                    await hub.broadcast(snapshot)
        except asyncio.CancelledError:
            break
        except Exception as exc:
            # 单条循环异常不应杀死整个后台任务
            print(f"[HiMoyu-EXPIRE] loop error: {exc!r}")
            await asyncio.sleep(config.EXPIRE_CHECK_INTERVAL)


@asynccontextmanager
async def lifespan(app: FastAPI):
    # startup
    global _expire_task
    _expire_task = asyncio.create_task(_expire_loop(), name="hiMoyu-expire-loop")
    print(f"[HiMoyu] expire checker started (interval={config.EXPIRE_CHECK_INTERVAL}s)")
    yield
    # shutdown
    if _expire_task and not _expire_task.done():
        _expire_task.cancel()
        try:
            await _expire_task
        except asyncio.CancelledError:
            pass
        print("[HiMoyu] expire checker stopped cleanly")


app = FastAPI(title=config.APP_NAME, version=config.APP_VERSION, lifespan=lifespan)

app.include_router(routes_state.router)
app.include_router(routes_mock.router)
app.include_router(ws.router)
app.mount("/sim", StaticFiles(directory=str(SIMULATOR_DIR), html=True), name="simulator")


@app.get("/", include_in_schema=False)
async def index() -> RedirectResponse:
    return RedirectResponse(url="/sim/")
