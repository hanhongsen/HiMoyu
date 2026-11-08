"""本地模拟互动接口。

阶段 0 只把原始事件计入场次并广播快照；
入职、点赞累计、礼物映射和整蛊在后续阶段接入。
"""

from __future__ import annotations

from typing import Literal

from fastapi import APIRouter
from pydantic import BaseModel, Field

from app.ingestion.events import MockEvent
from app.ingestion.mock_source import make_event
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
    repeat: int = Field(default=1, ge=1, le=10)


@router.post("/event")
async def post_mock_event(payload: MockEventIn) -> dict:
    state = get_state()
    applied: list[dict] = []

    for _ in range(payload.repeat):
        event: MockEvent = make_event(
            kind=payload.kind,
            user_id=payload.user_id,
            nickname=payload.nickname,
            text=payload.text,
            gift_id=payload.gift_id,
        )
        state.record_event(event.to_dict())
        applied.append(event.to_dict())

    snapshot = build_snapshot(state)
    await hub.broadcast(snapshot)
    return {"ok": True, "applied_count": len(applied), "applied": applied, "snapshot": snapshot}
