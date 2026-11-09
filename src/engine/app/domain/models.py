"""阶段 2A 扩展后的状态模型。

新增 Employee 数据模型、员工入职规则、工位分配、排队、离场回收。
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timezone
from uuid import uuid4

from app import config


def utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


# ---------- 员工数据 ----------

@dataclass
class Employee:
    employee_id: str
    user_id: str            # 平台用户稳定 ID（后台识别用，不暴露给 Godot）
    nickname: str           # 展示昵称（Godot 画面和快照展示用）
    seat_index: int         # 1–25，对应工位编号
    joined_at: str
    entry_method: str       # "like" / "comment" / "gift"

    def to_public_dict(self) -> dict:
        """Godot 和模拟台可见的公开快照字段（不暴露 user_id）。"""
        return {
            "employee_id": self.employee_id,
            "seat_index": self.seat_index,
            "nickname": self.nickname,
            "joined_at": self.joined_at,
            "entry_method": self.entry_method,
        }


@dataclass
class QueueEntry:
    """排队队列中的用户（未占用工位）。"""
    queue_id: str
    user_id: str
    nickname: str
    joined_at: str

    def to_dict(self) -> dict:
        return {
            "queue_id": self.queue_id,
            "user_id": self.user_id,  # 注意：队列信息只在后台和模拟台内部使用
            "nickname": self.nickname,
            "joined_at": self.joined_at,
        }


# ---------- 工位 ----------

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


# ---------- 场次状态 ----------

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

    # ---------- 阶段 2A 新增 ----------

    # 已入职员工 {employee_id: Employee}
    employees: dict[str, Employee] = field(default_factory=dict)

    # 已入职 user_id → employee_id 映射（用于快速去重）
    user_to_employee: dict[str, str] = field(default_factory=dict)

    # 用户点赞累计 {user_id: total_likes}
    user_likes: dict[str, int] = field(default_factory=dict)

    # 排队队列（按达到入职条件的先后顺序）
    queue: list[QueueEntry] = field(default_factory=list)

    # 排队 user_id → queue_index 映射（用于快速去重）
    user_in_queue: dict[str, int] = field(default_factory=dict)

    # 事件去重集合 {event_id}（防重复投递）
    _seen_events: set[str] = field(default_factory=set)

    @classmethod
    def new(cls) -> "OfficeState":
        return cls(
            session_id=uuid4().hex[:12],
            started_at=utc_now_iso(),
            seats=[SeatState(index=index + 1) for index in range(config.SEAT_COUNT)],
        )

    # ---------- 查询 ----------

    @property
    def occupied_seats(self) -> int:
        return sum(1 for seat in self.seats if seat.employee_id is not None)

    @property
    def free_seats(self) -> int:
        return len(self.seats) - self.occupied_seats

    @property
    def queue_count(self) -> int:
        return len(self.queue)

    def is_user_in_office(self, user_id: str) -> bool:
        return user_id in self.user_to_employee

    def is_user_in_queue(self, user_id: str) -> bool:
        return user_id in self.user_in_queue

    def find_free_seat_index(self) -> int | None:
        """返回第一个空闲工位的 index（1–25），全部占满返回 None。"""
        for seat in self.seats:
            if seat.employee_id is None:
                return seat.index
        return None

    # ---------- 入职工人 ----------

    def _clamp_nickname(self, nickname: str) -> str:
        """昵称安全处理：去除空白 + 长度限制。"""
        nick = (nickname or "").strip()
        if len(nick) > config.NICKNAME_MAX_LENGTH:
            nick = nick[:config.NICKNAME_MAX_LENGTH]
        return nick or "观众"

    def try_enter(self, *, user_id: str, nickname: str, method: str) -> dict:
        """尝试让一个用户入职。

        返回值：
            {"action": "joined", "employee": {...}, "seat_index": int}  —— 成功入职
            {"action": "queued", "queue_index": int}                     —— 进入队列
            {"action": "already_in_office", "employee_id": str}          —— 已在职
            {"action": "already_in_queue", "queue_index": int}           —— 已排队
        """
        # 1. 去重：已在职
        if self.is_user_in_office(user_id):
            emp_id = self.user_to_employee[user_id]
            return {
                "action": "already_in_office",
                "employee_id": emp_id,
            }

        # 2. 去重：已在队列
        if self.is_user_in_queue(user_id):
            return {
                "action": "already_in_queue",
                "queue_index": self.user_in_queue[user_id],
            }

        # 3. 找空闲工位
        free_index = self.find_free_seat_index()

        if free_index is None:
            # 满员 → 进入排队
            entry = QueueEntry(
                queue_id=uuid4().hex[:10],
                user_id=user_id,
                nickname=self._clamp_nickname(nickname),
                joined_at=utc_now_iso(),
            )
            self.queue.append(entry)
            self.user_in_queue[user_id] = len(self.queue) - 1
            self.version += 1
            return {
                "action": "queued",
                "queue_index": len(self.queue) - 1,
            }

        # 4. 分配工位
        emp_id = config.EMPLOYEE_ID_PREFIX + uuid4().hex[:10]
        employee = Employee(
            employee_id=emp_id,
            user_id=user_id,
            nickname=self._clamp_nickname(nickname),
            seat_index=free_index,
            joined_at=utc_now_iso(),
            entry_method=method,
        )
        self.employees[emp_id] = employee
        self.user_to_employee[user_id] = emp_id

        seat = self.seats[free_index - 1]
        seat.employee_id = emp_id
        seat.nickname = employee.nickname
        self.version += 1

        return {
            "action": "joined",
            "employee": employee.to_public_dict(),
            "seat_index": free_index,
        }

    def leave_employee_by_seat(self, seat_index: int) -> dict:
        """让指定工位的员工离场。释放工位后，如果队列有人，队首自动补位。

        返回：
            {"left": {...}, "promoted": {...} | None}
        """
        if seat_index < 1 or seat_index > len(self.seats):
            return {"error": f"seat {seat_index} 超出范围"}

        seat = self.seats[seat_index - 1]
        if seat.employee_id is None:
            return {"left": None, "promoted": None}

        emp_id = seat.employee_id
        employee = self.employees.pop(emp_id)
        self.user_to_employee.pop(employee.user_id, None)

        # 清空工位
        seat.employee_id = None
        seat.nickname = None
        self.version += 1

        # 队首补位
        promoted = None
        if self.queue:
            entry = self.queue.pop(0)
            self.user_in_queue.pop(entry.user_id, None)
            # 重建 user_in_queue 索引
            self.user_in_queue = {
                e.user_id: i for i, e in enumerate(self.queue)
            }
            result = self.try_enter(
                user_id=entry.user_id,
                nickname=entry.nickname,
                method="queue_promote",
            )
            if result.get("action") == "joined":
                promoted = result["employee"]

        return {
            "left": employee.to_public_dict(),
            "promoted": promoted,
        }

    def reset_for_new_session(self) -> None:
        """清空所有场次相关数据（保留 25 个空工位结构）。"""
        self.employees.clear()
        self.user_to_employee.clear()
        self.user_likes.clear()
        self.queue.clear()
        self.user_in_queue.clear()
        self._seen_events.clear()
        for seat in self.seats:
            seat.employee_id = None
            seat.nickname = None
        self.version += 1

    # ---------- 事件记录（保留阶段 0 接口，新增去重） ----------

    def record_event(self, event: dict, count: int = 1) -> None:
        """保留阶段 0 原始计数接口，同时支持 repeat 批量累计和事件去重。

        count：本次事件代表的实际次数（like 可能 repeat=10）。
        """
        event_id = event.get("event_id")
        if event_id and event_id in self._seen_events:
            return  # 重复事件，跳过
        if event_id:
            self._seen_events.add(event_id)

        kind = event["kind"]
        self.event_counts[kind] = self.event_counts.get(kind, 0) + count
        self.last_event = event
        self.version += 1
