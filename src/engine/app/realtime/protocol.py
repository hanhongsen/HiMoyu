"""WebSocket 协议：阶段 0 使用“全量快照”契约。

25 名员工的数据量很小，全量快照足以保证客户端与服务端一致，
后续动作、巡查和事件只在此基础上增加字段。
"""

from __future__ import annotations

from app import config
from app.domain.models import OfficeState, utc_now_iso

PROTOCOL_VERSION = 1


def build_snapshot(state: OfficeState) -> dict:
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
            "grid": {"rows": config.SEAT_ROWS, "cols": config.SEAT_COLS},
            "event_counts": dict(state.event_counts),
            "last_event": state.last_event,
        },
        "seats": [seat.to_dict() for seat in state.seats],
        "employees": [],
    }
