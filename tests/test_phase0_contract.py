"""阶段 0 契约测试：状态、模拟事件、重置和 WebSocket 广播。"""

import pytest
from fastapi.testclient import TestClient

from app.main import app


@pytest.fixture
def client():
    with TestClient(app) as test_client:
        test_client.post("/api/session/reset")
        yield test_client


def test_health(client):
    response = client.get("/api/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"


def test_snapshot_contract(client):
    data = client.get("/api/state").json()

    assert data["type"] == "snapshot"
    assert data["protocol_version"] == 1
    assert data["session"]["seat_count"] == 25
    assert data["session"]["occupied_seats"] == 0
    assert data["session"]["grid"] == {"rows": 5, "cols": 5}
    assert len(data["seats"]) == 25
    assert [seat["index"] for seat in data["seats"]] == list(range(1, 26))
    assert data["session"]["event_counts"] == {"like": 0, "comment": 0, "gift": 0}
    assert data["employees"] == []


def test_like_repeat_counts(client):
    response = client.post(
        "/api/mock/event",
        json={"kind": "like", "user_id": "u1", "nickname": "摸鱼小王", "repeat": 10},
    )
    assert response.status_code == 200
    data = response.json()

    assert data["applied_count"] == 10
    assert data["snapshot"]["session"]["event_counts"]["like"] == 10
    assert data["snapshot"]["session"]["last_event"]["nickname"] == "摸鱼小王"
    assert data["snapshot"]["version"] > 0


def test_comment_and_gift_defaults(client):
    comment = client.post(
        "/api/mock/event",
        json={"kind": "comment", "user_id": "u2", "nickname": "小李"},
    ).json()
    assert comment["snapshot"]["session"]["last_event"]["text"] == "入职"
    assert comment["snapshot"]["session"]["event_counts"]["comment"] == 1

    gift = client.post(
        "/api/mock/event",
        json={"kind": "gift", "user_id": "u3", "nickname": "阿花"},
    ).json()
    assert gift["snapshot"]["session"]["last_event"]["gift_id"] == "gift_join"
    assert gift["snapshot"]["session"]["event_counts"]["gift"] == 1


def test_reset_session(client):
    client.post(
        "/api/mock/event",
        json={"kind": "like", "user_id": "u1", "nickname": "摸鱼小王"},
    )
    reset = client.post("/api/session/reset").json()

    assert reset["session"]["event_counts"] == {"like": 0, "comment": 0, "gift": 0}
    assert reset["session"]["last_event"] is None
    assert reset["version"] == 0


@pytest.mark.parametrize(
    "payload",
    [
        {"kind": "follow"},
        {"kind": "like", "repeat": 0},
        {"kind": "like", "repeat": 11},
    ],
)
def test_invalid_mock_event(client, payload):
    assert client.post("/api/mock/event", json=payload).status_code == 422


def test_websocket_receives_snapshot_after_event(client):
    with client.websocket_connect("/ws") as websocket:
        initial = websocket.receive_json()
        assert initial["type"] == "snapshot"

        client.post(
            "/api/mock/event",
            json={"kind": "gift", "user_id": "u4", "nickname": "小周", "gift_id": "gift_coffee"},
        )
        updated = websocket.receive_json()

        assert updated["type"] == "snapshot"
        assert updated["session"]["event_counts"]["gift"] == 1
        assert updated["session"]["last_event"]["gift_id"] == "gift_coffee"
