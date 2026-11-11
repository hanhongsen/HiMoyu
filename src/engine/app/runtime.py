"""当前场次的进程内状态。

阶段 0 先不落 SQLite；阶段 2 接入持久化时由 storage/repository 接管。
阶段 2B 新增：state_lock 保护 state 修改 + broadcast 的原子性。
"""

from __future__ import annotations

import asyncio

from app.domain.models import OfficeState

_state = OfficeState.new()

# 状态锁：保护 state 修改 + broadcast 的原子序列。
# 在 asyncio 单线程模型下确保后台 expirer 和用户请求协程不会
# 在 await hub.broadcast() 窗口交错修改同一个 state。
state_lock = asyncio.Lock()


def get_state() -> OfficeState:
    return _state


def reset_state() -> OfficeState:
    global _state
    _state = OfficeState.new()
    return _state
