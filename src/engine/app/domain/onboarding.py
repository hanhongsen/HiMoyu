"""员工入职规则引擎（阶段 2A）。

统一处理三种入职触发方式：点赞累计、评论关键词、模拟入职礼物。
所有入口最终调用 OfficeState.try_enter()，不各自独立写工位分配逻辑。
"""

from __future__ import annotations

from app import config
from app.domain.models import OfficeState


class EntryResult:
    """入职判定结果。"""

    __slots__ = (
        "should_try_enter",   # 是否达到入职条件、需要调用 try_enter()
        "method",             # "like" / "comment" / "gift"
        "likes_added",        # 本次事件累计的点赞数（调试用）
        "likes_total",         # 累计后总点赞数（调试用）
        "likes_before_total",  # 累计前的总点赞数（用于判断"刚达到阈值"）
        "note",               # 提示信息（调试用）
    )

    def __init__(
        self,
        *,
        should_try_enter: bool,
        method: str,
        likes_added: int = 0,
        likes_total: int = 0,
        likes_before_total: int = 0,
        note: str = "",
    ) -> None:
        self.should_try_enter = should_try_enter
        self.method = method
        self.likes_added = likes_added
        self.likes_total = likes_total
        self.likes_before_total = likes_before_total
        self.note = note


def _clamp_nickname(nickname: str) -> str:
    nick = (nickname or "").strip()
    if len(nick) > config.NICKNAME_MAX_LENGTH:
        nick = nick[:config.NICKNAME_MAX_LENGTH]
    return nick or "观众"


def handle_like(*, state: OfficeState, user_id: str, nickname: str, repeat: int = 1) -> EntryResult | None:
    """处理点赞事件。

    返回 None 表示还未达到阈值；返回 EntryResult 表示达到阈值、需要调用 try_enter()。
    """
    # 已经在职或排队 → 不累计点赞
    if state.is_user_in_office(user_id) or state.is_user_in_queue(user_id):
        return None

    added = repeat
    before = state.user_likes.get(user_id, 0)
    after = before + added
    state.user_likes[user_id] = after

    # 首次达到或刚好超过阈值
    reached = before < config.LIKE_ENTRY_THRESHOLD <= after

    if not reached:
        return None

    return EntryResult(
        should_try_enter=True,
        method="like",
        likes_added=added,
        likes_total=after,
        likes_before_total=before,
        note=f"点赞累计 {after} >= 阈值 {config.LIKE_ENTRY_THRESHOLD}",
    )


def handle_comment(*, state: OfficeState, user_id: str, nickname: str, text: str | None) -> EntryResult | None:
    """处理评论事件：去空格后精确匹配关键词。"""
    if state.is_user_in_office(user_id) or state.is_user_in_queue(user_id):
        return None

    clean = (text or "").strip()
    if clean != config.COMMENT_ENTRY_KEYWORD:
        return None

    return EntryResult(
        should_try_enter=True,
        method="comment",
        note=f"评论命中关键词：{clean}",
    )


def handle_gift(*, state: OfficeState, user_id: str, nickname: str, gift_id: str | None) -> EntryResult | None:
    """处理礼物事件：只有指定的入职礼物触发。"""
    if state.is_user_in_office(user_id) or state.is_user_in_queue(user_id):
        return None

    if gift_id != config.ENTRY_GIFT_ID:
        return None

    return EntryResult(
        should_try_enter=True,
        method="gift",
        note=f"收到入职礼物：{gift_id}",
    )


def dispatch_entry(*, state: OfficeState, event_kind: str, user_id: str, nickname: str,
                   text: str | None = None, gift_id: str | None = None,
                   repeat: int = 1) -> tuple[EntryResult | None, dict | None]:
    """统一入口：识别事件类型、判定是否达到入职条件、调用 try_enter()。

    返回：
        (entry_result, enter_result_dict)
        entry_result：EntryResult（如果触发了入职判定）或 None
        enter_result_dict：try_enter() 的返回 dict（包含 joined/queued/already_in_office/already_in_queue）
    """
    # 昵称安全处理
    nickname = _clamp_nickname(nickname)

    # 快速去重检查（在 handle_xxx 之前先查），让返回值一致
    if state.is_user_in_office(user_id):
        emp_id = state.user_to_employee[user_id]
        return None, {"action": "already_in_office", "employee_id": emp_id}
    if state.is_user_in_queue(user_id):
        return None, {"action": "already_in_queue", "queue_index": state.user_in_queue[user_id]}

    entry_result: EntryResult | None = None

    if event_kind == "like":
        entry_result = handle_like(
            state=state,
            user_id=user_id,
            nickname=nickname,
            repeat=repeat,
        )
    elif event_kind == "comment":
        entry_result = handle_comment(
            state=state,
            user_id=user_id,
            nickname=nickname,
            text=text,
        )
    elif event_kind == "gift":
        entry_result = handle_gift(
            state=state,
            user_id=user_id,
            nickname=nickname,
            gift_id=gift_id,
        )

    if entry_result is None or not entry_result.should_try_enter:
        return entry_result, None

    # 达到入职条件 → 调用统一的 try_enter()
    enter_result = state.try_enter(
        user_id=user_id,
        nickname=nickname,
        method=entry_result.method,
    )

    return entry_result, enter_result
