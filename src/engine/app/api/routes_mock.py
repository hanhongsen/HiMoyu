"""本地模拟互动接口（阶段 2B 扩展版）。

阶段 2A：调用 onboarding.dispatch_entry() 判定入职条件，
         调用 state.try_enter() / state.leave_employee_by_seat() 操作员工。
阶段 2B：新增礼物→动作映射、手动动作接口、后端动作状态管理。
"""

from __future__ import annotations

import logging
from typing import Literal

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from app import config
from app.domain import onboarding
from app.domain.onboarding import dispatch_entry
from app.ingestion.events import build_mock_event
from app.realtime.hub import hub
from app.realtime.protocol import build_snapshot
from app.runtime import get_state, state_lock

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/mock", tags=["mock"])


# ---------- 阶段 2A / 2B 共用的事件模型 ----------

class MockEventIn(BaseModel):
    kind: Literal["like", "comment", "gift"]
    user_id: str = Field(default="demo-user", max_length=64)
    nickname: str = Field(default="模拟观众", max_length=32)
    text: str | None = Field(default=None, max_length=32)
    gift_id: str | None = Field(default=None, max_length=32)
    repeat: int = Field(default=1, ge=1, le=1000)  # 允许模拟批量点赞
    event_id: str | None = Field(default=None, max_length=32)
    # 阶段 2B：礼物事件可指定目标工位（1-25），未指定则默认对送礼者本人生效
    seat_index: int | None = Field(default=None, ge=1, le=25)


# ---------- 阶段 2B 新增：手动动作接口模型 ----------

class ActionCommandIn(BaseModel):
    seat_index: int = Field(ge=1, le=25)
    action: Literal["sleep", "phone", "snack", "work"]
    duration_s: float | None = Field(default=None)  # None = 用 config 默认值
    source: str = Field(default="manual", max_length=32)


# ---------- 礼物 → 动作辅助函数 ----------

def _apply_gift_action_if_any(state, payload: MockEventIn) -> dict | None:
    """如果 payload 是可映射动作的礼物，对目标员工 apply_action。

    返回 None 表示不触发任何动作；返回 dict 表示 apply_action 的结果。
    任何错误只记日志不抛异常（礼物已经正常 record_event 了）。
    """
    if payload.kind != "gift":
        return None
    if not payload.gift_id:
        return None
    if payload.gift_id not in config.GIFT_TO_ACTION:
        return None  # 入职礼物等不映射动作

    action = config.GIFT_TO_ACTION[payload.gift_id]
    # 确定目标员工 employee_id
    target_emp_id: str | None = None

    if payload.seat_index is not None:
        # 指定了工位 → 找该工位的员工
        seat = state.seats[payload.seat_index - 1]
        target_emp_id = seat.employee_id
    else:
        # 未指定工位 → 默认对送礼者本人（送礼者必须已在职）
        if state.is_user_in_office(payload.user_id):
            target_emp_id = state.user_to_employee[payload.user_id]

    if target_emp_id is None:
        logger.info("[2B] gift=%s no valid target (seat=%s donor_in_office=%s), skip action",
                    payload.gift_id, payload.seat_index,
                    state.is_user_in_office(payload.user_id))
        return None

    result = state.apply_action(
        employee_id=target_emp_id,
        action=action,
        source=f"gift:{payload.gift_id}",
    )
    if not result.get("ok"):
        logger.warning("[2B] apply_action failed: %s", result.get("detail"))
    return result


# ---------- 阶段 2A / 2B 共用的事件端点 ----------

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

    async with state_lock:
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

        # 阶段 2B：礼物→动作（如果礼物可映射且有有效目标）
        action_result = _apply_gift_action_if_any(state, payload)
        if action_result:
            method_results.append({"action_result": action_result})

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
            "seat_index": payload.seat_index,
        },
        "snapshot": snapshot,
    }


# ---------- 员工离场（阶段 2A 本地测试用，阶段 2B 保持不变） ----------

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

    async with state_lock:
        result = state.leave_employee_by_seat(seat_index)

        if result.get("left") is None:
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


# ---------- 阶段 2B 新增：手动动作接口 ----------

@router.post("/action")
async def post_action(payload: ActionCommandIn) -> dict:
    """手动为指定工位的员工设置动作状态。"""
    state = get_state()

    seat = state.seats[payload.seat_index - 1]
    if seat.employee_id is None:
        snapshot = build_snapshot(state)
        return {"ok": False, "detail": f"工位 {payload.seat_index} 当前空闲", "snapshot": snapshot}

    async with state_lock:
        result = state.apply_action(
            employee_id=seat.employee_id,
            action=payload.action,
            source=payload.source,
            duration_s=payload.duration_s,
        )

        if not result.get("ok"):
            snapshot = build_snapshot(state)
            return {"ok": False, "detail": result.get("detail", "unknown error"), "snapshot": snapshot}

        snapshot = build_snapshot(state)
        await hub.broadcast(snapshot)

    return {
        "ok": True,
        "action": result,
        "snapshot": snapshot,
    }
