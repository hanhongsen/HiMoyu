"""WebSocket 协议：阶段 2A 扩展快照契约。

在阶段 0 基础上增加：
- employees[]：已入职员工的公开数据（不暴露 user_id）
- queue_count / queue_preview：排队信息（queue_preview 仅给模拟台使用，Godot 客户端只需 queue_count）
"""

from __future__ import annotations

from app import config
from app.domain.models import OfficeState, utc_now_iso

PROTOCOL_VERSION = 2


def build_snapshot(state: OfficeState) -> dict:
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
        "seats": [seat.to_dict() for seat in state.seats],
        "employees": employees_sorted,
    }
