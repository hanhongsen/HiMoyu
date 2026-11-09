"""本地模拟互动接口（阶段 2A 扩展版）。

调用 onboarding.dispatch_entry() 判定入职条件，
调用 state.try_enter() / state.leave_employee_by_seat() 操作员工。
"""

from __future__ import annotations

from typing import Literal

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from app import config
from app.domain import onboarding
from app.domain.onboarding import dispatch_entry
from app.ingestion.events import build_mock_event
from app.realtime.hub import hub
from app.realtime.protocol import build_snapshot
from app.runtime import get_state

router = APIRouter(prefix="/api/mock", tags=["mock"])


class MockEventIn(BaseModel):
    kind: Literal["like", "comment", "gift"]
    user_id: str = Field(default="demo-user", max_length=64)
    nickname: str = Field(default="模拟观众", max_length=32)
    text: str | None = Field(default=None, max_length=32)
    gift_id: str | None = Field(default=None, max_length=32)
    repeat: int = Field(default=1, ge=1, le=1000)  # 允许模拟批量点赞
    event_id: str | None = Field(default=None, max_length=32)


@router.post("/event")
async def post_mock_event(payload: MockEventIn) -> dict:
    state = get_state()

    # 事件计数：like 按 repeat 次累计，comment/gift 固定 1 次
    count = payload.repeat if payload.kind == "like" else 1
    state.record_event(
        build_mock_event(
            kind=payload.kind,
            user_id=payload.user_id,
            nickname=payload.nickname,
            text=payload.text,
            gift_id=payload.gift_id,
            event_id=payload.event_id,
        ).to_dict(),
        count=count,
    )

    # 幂等检查
    if payload.event_id:
        if payload.event_id in state._seen_events:
            snapshot = build_snapshot(state)
            return {"ok": True, "idempotent": True, "event_id": payload.event_id, "snapshot": snapshot}

    # 批量事件：like 按 repeat 数累计，comment/gift 只判一次
    method_results: list[dict] = []

    entry_result, enter_result = dispatch_entry(
        state=state,
        event_kind=payload.kind,
        user_id=payload.user_id,
        nickname=payload.nickname,
        text=payload.text,
        gift_id=payload.gift_id,
        repeat=payload.repeat if payload.kind == "like" else 1,
    )
    if enter_result:
        method_results.append(enter_result)

    # 去重：记录 event_id
    if payload.event_id:
        state._seen_events.add(payload.event_id)

    snapshot = build_snapshot(state)
    await hub.broadcast(snapshot)

    return {
        "ok": True,
        "applied_count": 1,
        "entry_results": method_results,
        "event": {
            "kind": payload.kind,
            "user_id": payload.user_id,
            "nickname": payload.nickname,
            "text": payload.text,
            "gift_id": payload.gift_id,
            "repeat": payload.repeat,
        },
        "snapshot": snapshot,
    }


# ---------- 员工离场（本地测试用） ----------

@router.post("/leave")
async def leave_employee(payload: dict) -> dict:
    seat_index = payload.get("seat_index")
    if seat_index is None:
        raise HTTPException(status_code=400, detail="seat_index is required")

    try:
        seat_index = int(seat_index)
    except (TypeError, ValueError):
        raise HTTPException(status_code=400, detail="seat_index must be integer")

    if seat_index < 1 or seat_index > config.SEAT_COUNT:
        raise HTTPException(status_code=400, detail=f"seat_index must be 1-{config.SEAT_COUNT}")

    state = get_state()
    result = state.leave_employee_by_seat(seat_index)

    if result.get("left") is None:
        # 工位为空或范围问题
        snapshot = build_snapshot(state)
        return {"ok": False, "detail": f"工位 {seat_index} 当前空闲", "snapshot": snapshot}

    snapshot = build_snapshot(state)
    await hub.broadcast(snapshot)

    return {
        "ok": True,
        "left": result["left"],
        "promoted": result["promoted"],
        "snapshot": snapshot,
    }
