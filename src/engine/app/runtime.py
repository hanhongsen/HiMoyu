"""当前场次的进程内状态。

阶段 0 先不落 SQLite；阶段 2 接入持久化时由 storage/repository 接管。
"""

from __future__ import annotations

from app.domain.models import OfficeState

_state = OfficeState.new()


def get_state() -> OfficeState:
    return _state


def reset_state() -> OfficeState:
    global _state
    _state = OfficeState.new()
    return _state
