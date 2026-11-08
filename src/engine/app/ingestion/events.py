"""本地模拟事件模型。"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from uuid import uuid4


@dataclass(frozen=True)
class MockEvent:
    event_id: str
    kind: str
    user_id: str
    nickname: str
    text: str | None = None
    gift_id: str | None = None
    received_at: str = ""

    def to_dict(self) -> dict:
        return {
            "event_id": self.event_id,
            "kind": self.kind,
            "user_id": self.user_id,
            "nickname": self.nickname,
            "text": self.text,
            "gift_id": self.gift_id,
            "received_at": self.received_at,
        }


def build_mock_event(
    *,
    kind: str,
    user_id: str,
    nickname: str,
    text: str | None = None,
    gift_id: str | None = None,
) -> MockEvent:
    return MockEvent(
        event_id=uuid4().hex[:10],
        kind=kind,
        user_id=user_id,
        nickname=nickname,
        text=text,
        gift_id=gift_id,
        received_at=datetime.now(timezone.utc).isoformat(timespec="seconds"),
    )
