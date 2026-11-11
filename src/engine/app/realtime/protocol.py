"""WebSocket 协议：阶段 2B 升级快照契约。

阶段 2B v3 新增：
- seats[].action：当前员工动作（"sleep"/"phone"/"snack"/"work"，空工位 null）
- seats[].action_remaining_s：临时动作剩余秒数（持续动作或空工位 null）

向后兼容：旧 Godot 客户端只读取 employee_id/nickname，忽略新字段即可。
"""

from __future__ import annotations

from datetime import datetime, timezone

from app import config
from app.domain.models import OfficeState, utc_now_iso

PROTOCOL_VERSION = 3


def build_snapshot(state: OfficeState) -> dict:
    now = datetime.now(timezone.utc)

    # 员工公开列表（按 seat_index 排序，不暴露 user_id）
    employees_sorted = sorted(
        [emp.to_public_dict() for emp in state.employees.values()],
        key=lambda e: e["seat_index"],
    )

    # 排队预览（只有 queue_id 和 nickname，不暴露 user_id）
    queue_preview = [
        {"queue_id": e.queue_id, "nickname": e.nickname, "joined_at": e.joined_at}
        for e in state.queue
    ]

    # 工位快照：从 SeatState.to_dict() 拿到基础字段，再动态计算 action_remaining_s
    seat_dicts = []
    for seat in state.seats:
        d = seat.to_dict()
        # action_remaining_s 由 Employee 状态动态投影（只读操作，不修改 state）
        remaining = None
        if seat.employee_id and seat.action and seat.action != "sleep":
            emp = state.employees.get(seat.employee_id)
            if emp and emp.action_until:
                try:
                    until = datetime.fromisoformat(emp.action_until)
                    remaining = max(0.0, (until - now).total_seconds())
                except (ValueError, TypeError):
                    remaining = None
        d["action_remaining_s"] = remaining
        seat_dicts.append(d)

    return {
        "type": "snapshot",
        "protocol_version": PROTOCOL_VERSION,
        "version": state.version,
        "server_time": utc_now_iso(),
        "session": {
            "session_id": state.session_id,
            "started_at": state.started_at,
            "seat_count": len(state.seats),
            "occupied_seats": state.occupied_seats,
            "free_seats": state.free_seats,
            "grid": {"rows": config.SEAT_ROWS, "cols": config.SEAT_COLS},
            "event_counts": dict(state.event_counts),
            "last_event": state.last_event,
            "queue_count": state.queue_count,
            "queue_preview": queue_preview,
        },
        "seats": seat_dicts,
        "employees": employees_sorted,
    }
