"""阶段 0 的最小状态模型。

这里只保留“场次 + 25 个工位 + 原始事件计数”，用于打通
模拟事件 → 规则引擎 → WebSocket → Godot 的链路。
入职、积分、动作、巡查、事件和报告在后续阶段进入本目录。
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timezone
from uuid import uuid4

from app import config


def utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


@dataclass
class SeatState:
    index: int
    employee_id: str | None = None
    nickname: str | None = None

    def to_dict(self) -> dict:
        return {
            "index": self.index,
            "employee_id": self.employee_id,
            "nickname": self.nickname,
        }


@dataclass
class OfficeState:
    session_id: str
    started_at: str
    seats: list[SeatState]
    version: int = 0
    event_counts: dict[str, int] = field(
        default_factory=lambda: {"like": 0, "comment": 0, "gift": 0}
    )
    last_event: dict | None = None

    @classmethod
    def new(cls) -> "OfficeState":
        return cls(
            session_id=uuid4().hex[:12],
            started_at=utc_now_iso(),
            seats=[SeatState(index=index + 1) for index in range(config.SEAT_COUNT)],
        )

    @property
    def occupied_seats(self) -> int:
        return sum(1 for seat in self.seats if seat.employee_id is not None)

    def record_event(self, event: dict) -> None:
        """阶段 0 占位：只计数并记录最近事件。

        阶段 2 起由 onboarding / actions 模块接管，这里不实现入职规则。
        """
        kind = event["kind"]
        self.event_counts[kind] = self.event_counts.get(kind, 0) + 1
        self.last_event = event
        self.version += 1
