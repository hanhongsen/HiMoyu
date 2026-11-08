"""阶段 0 的模拟事件源。

后续第二阶段会在这里增加平台事件适配器；
第一阶段只有本地模拟，不发起任何抖音网络请求。
"""

from __future__ import annotations

from app.ingestion.events import MockEvent, build_mock_event

SUPPORTED_KINDS = ("like", "comment", "gift")

DEFAULT_COMMENT_TEXT = "入职"
DEFAULT_GIFT_ID = "gift_join"


def make_event(
    *,
    kind: str,
    user_id: str,
    nickname: str,
    text: str | None = None,
    gift_id: str | None = None,
) -> MockEvent:
    if kind == "comment" and not text:
        text = DEFAULT_COMMENT_TEXT
    if kind == "gift" and not gift_id:
        gift_id = DEFAULT_GIFT_ID
    return build_mock_event(
        kind=kind,
        user_id=user_id,
        nickname=nickname,
        text=text if kind == "comment" else None,
        gift_id=gift_id if kind == "gift" else None,
    )
