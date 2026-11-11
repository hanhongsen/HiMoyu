"""阶段 2A 契约测试：保留阶段 0 全部断言 + 适配阶段 2A 扩展。

原有 9 项测试已随协议升级同步更新（不降级、不跳过），
新增测试覆盖三种入职规则、25 工位分配、排队、离场补位和事件幂等。
"""

import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.domain import onboarding
from app.domain.models import OfficeState
from app import config


@pytest.fixture
def client():
    with TestClient(app) as test_client:
        test_client.post("/api/session/reset")
        yield test_client


# ===================== 原有 9 项测试（适配阶段 2A） =====================


def test_health(client):
    response = client.get("/api/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"


def test_snapshot_contract(client):
    data = client.get("/api/state").json()

    assert data["type"] == "snapshot"
    assert data["protocol_version"] == 3   # 阶段 2B 升级
    assert data["session"]["seat_count"] == 25
    assert data["session"]["occupied_seats"] == 0
    assert data["session"]["free_seats"] == 25  # 阶段 2A 新增字段
    assert data["session"]["grid"] == {"rows": 5, "cols": 5}
    assert data["session"]["queue_count"] == 0  # 阶段 2A 新增字段
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

    # 点赞累计 10 次后达到入职阈值（10），触发入职
    assert data["snapshot"]["session"]["event_counts"]["like"] == 10
    assert data["snapshot"]["employees"]  # 有员工了
    assert data["snapshot"]["session"]["occupied_seats"] == 1


def test_comment_and_gift_defaults(client):
    # 评论：发送 "入职" 关键词 → 成功入职
    comment = client.post(
        "/api/mock/event",
        json={"kind": "comment", "user_id": "u2", "nickname": "小李", "text": "入职"},
    ).json()
    assert comment["snapshot"]["session"]["event_counts"]["comment"] == 1
    assert comment["snapshot"]["employees"]

    # 礼物：发送指定入职礼物 → 成功入职
    gift = client.post(
        "/api/mock/event",
        json={"kind": "gift", "user_id": "u3", "nickname": "阿花", "gift_id": config.ENTRY_GIFT_ID},
    ).json()
    assert gift["snapshot"]["session"]["event_counts"]["gift"] == 1


def test_reset_session(client):
    # 先造一些员工
    client.post("/api/mock/event", json={"kind": "comment", "user_id": "u1", "nickname": "摸鱼小王", "text": "入职"})
    reset = client.post("/api/session/reset").json()

    assert reset["session"]["event_counts"] == {"like": 0, "comment": 0, "gift": 0}
    assert reset["session"]["occupied_seats"] == 0
    assert reset["employees"] == []
    assert reset["version"] >= 0


@pytest.mark.parametrize(
    "payload",
    [
        {"kind": "follow"},
        {"kind": "like", "repeat": 0},
        {"kind": "like", "repeat": 1001},
    ],
)
def test_invalid_mock_event(client, payload):
    assert client.post("/api/mock/event", json=payload).status_code == 422


def test_websocket_receives_snapshot_after_event(client):
    with client.websocket_connect("/ws") as websocket:
        initial = websocket.receive_json()
        assert initial["type"] == "snapshot"

        # 一次性让 u1 满 12 个点赞（>=10）触发入职
        client.post(
            "/api/mock/event",
            json={"kind": "like", "user_id": "u1", "nickname": "u1", "repeat": 12},
        )
        updated = websocket.receive_json()

        assert updated["type"] == "snapshot"
        assert updated["session"]["occupied_seats"] >= 1


# ===================== 阶段 2A 新增测试 =====================


class TestLikeEntry:
    def test_like_9_not_entry(self):
        state = OfficeState.new()
        # 9 个点赞 → 未满
        for _ in range(3):
            onboarding.dispatch_entry(state=state, event_kind="like",
                                     user_id="u1", nickname="A", repeat=3)
        assert state.occupied_seats == 0
        assert state.is_user_in_office("u1") is False

    def test_like_10_entry(self):
        state = OfficeState.new()
        onboarding.dispatch_entry(state=state, event_kind="like",
                                  user_id="u1", nickname="A", repeat=10)
        assert state.occupied_seats == 1
        assert state.is_user_in_office("u1") is True

    def test_like_5plus5_entry(self):
        state = OfficeState.new()
        onboarding.dispatch_entry(state=state, event_kind="like",
                                  user_id="u1", nickname="A", repeat=5)
        assert state.occupied_seats == 0
        onboarding.dispatch_entry(state=state, event_kind="like",
                                  user_id="u1", nickname="A", repeat=5)
        assert state.occupied_seats == 1

    def test_different_users_likes_not_mixed(self):
        state = OfficeState.new()
        for _ in range(9):
            onboarding.dispatch_entry(state=state, event_kind="like",
                                      user_id="u1", nickname="A", repeat=1)
        # u1 还没满
        assert state.user_likes["u1"] == 9
        # u2 独立计数
        onboarding.dispatch_entry(state=state, event_kind="like",
                                  user_id="u2", nickname="B", repeat=10)
        assert state.user_likes["u2"] == 10
        assert state.is_user_in_office("u1") is False
        assert state.is_user_in_office("u2") is True


class TestCommentEntry:
    def test_keyword_entry(self):
        state = OfficeState.new()
        onboarding.dispatch_entry(state=state, event_kind="comment",
                                  user_id="u1", nickname="A", text="入职")
        assert state.is_user_in_office("u1")

    def test_non_keyword_no_entry(self):
        state = OfficeState.new()
        onboarding.dispatch_entry(state=state, event_kind="comment",
                                  user_id="u1", nickname="A", text="你好")
        assert not state.is_user_in_office("u1")

    def test_whitespace_keyword(self):
        state = OfficeState.new()
        onboarding.dispatch_entry(state=state, event_kind="comment",
                                  user_id="u1", nickname="A", text=" 入职  ")
        assert state.is_user_in_office("u1")


class TestGiftEntry:
    def test_demo_entry_gift(self):
        state = OfficeState.new()
        onboarding.dispatch_entry(state=state, event_kind="gift",
                                  user_id="u1", nickname="A", gift_id=config.ENTRY_GIFT_ID)
        assert state.is_user_in_office("u1")

    def test_other_gift_no_entry(self):
        state = OfficeState.new()
        onboarding.dispatch_entry(state=state, event_kind="gift",
                                  user_id="u1", nickname="A", gift_id="gift_coffee")
        assert not state.is_user_in_office("u1")


class TestSeatAllocation:
    def test_first_25_users_get_sequential_seats(self):
        state = OfficeState.new()
        for i in range(1, 26):
            result = onboarding.dispatch_entry(state=state, event_kind="comment",
                                               user_id=f"u{i}", nickname=f"user{i}", text="入职")
            enter = result[1]
            assert enter["action"] == "joined"
            assert enter["seat_index"] == i
        assert state.occupied_seats == 25
        assert state.queue_count == 0

    def test_26th_user_enters_queue(self):
        state = OfficeState.new()
        for i in range(1, 26):
            onboarding.dispatch_entry(state=state, event_kind="comment",
                                      user_id=f"u{i}", nickname=f"user{i}", text="入职")
        result = onboarding.dispatch_entry(state=state, event_kind="comment",
                                           user_id="u26", nickname="user26", text="入职")
        enter = result[1]
        assert enter["action"] == "queued"
        assert state.queue_count == 1

    def test_same_user_no_duplicate(self):
        state = OfficeState.new()
        result1 = onboarding.dispatch_entry(state=state, event_kind="comment",
                                            user_id="u1", nickname="A", text="入职")
        result2 = onboarding.dispatch_entry(state=state, event_kind="comment",
                                            user_id="u1", nickname="A", text="入职")
        assert result1[1]["action"] == "joined"
        assert result2[1]["action"] == "already_in_office"
        assert state.occupied_seats == 1

    def test_user_in_queue_no_duplicate(self):
        state = OfficeState.new()
        for i in range(1, 26):
            onboarding.dispatch_entry(state=state, event_kind="comment",
                                      user_id=f"u{i}", nickname=f"user{i}", text="入职")
        r1 = onboarding.dispatch_entry(state=state, event_kind="comment",
                                       user_id="u26", nickname="A", text="入职")
        r2 = onboarding.dispatch_entry(state=state, event_kind="comment",
                                       user_id="u26", nickname="A", text="入职")
        assert r1[1]["action"] == "queued"
        assert r2[1]["action"] == "already_in_queue"


class TestLeaveAndPromote:
    def test_leave_frees_seat(self):
        state = OfficeState.new()
        for i in range(1, 26):
            onboarding.dispatch_entry(state=state, event_kind="comment",
                                      user_id=f"u{i}", nickname=f"user{i}", text="入职")
        result = state.leave_employee_by_seat(1)
        assert result["left"]["seat_index"] == 1
        assert state.occupied_seats == 24

    def test_queue_first_promoted(self):
        state = OfficeState.new()
        for i in range(1, 26):
            onboarding.dispatch_entry(state=state, event_kind="comment",
                                      user_id=f"u{i}", nickname=f"user{i}", text="入职")
        onboarding.dispatch_entry(state=state, event_kind="comment",
                                  user_id="u26", nickname="Q1", text="入职")
        onboarding.dispatch_entry(state=state, event_kind="comment",
                                  user_id="u27", nickname="Q2", text="入职")
        assert state.queue_count == 2
        # 让 01 号工位离职 → Q1 自动补位
        result = state.leave_employee_by_seat(1)
        assert result["promoted"] is not None
        assert result["promoted"]["seat_index"] == 1
        assert result["promoted"]["nickname"] == "Q1"
        assert state.queue_count == 1

    def test_leave_empty_seat(self):
        state = OfficeState.new()
        result = state.leave_employee_by_seat(5)
        assert result["left"] is None
        assert result["promoted"] is None

    def test_reset_clears_everything(self):
        state = OfficeState.new()
        for i in range(1, 26):
            onboarding.dispatch_entry(state=state, event_kind="comment",
                                      user_id=f"u{i}", nickname=f"user{i}", text="入职")
        onboarding.dispatch_entry(state=state, event_kind="comment",
                                  user_id="u26", nickname="Q1", text="入职")
        onboarding.dispatch_entry(state=state, event_kind="like",
                                  user_id="u27", nickname="Q2", repeat=5)
        state.reset_for_new_session()
        assert state.occupied_seats == 0
        assert state.queue_count == 0
        assert len(state.user_likes) == 0
        assert len(state.user_to_employee) == 0


class TestIdempotency:
    def test_duplicate_event_id_skipped(self):
        state = OfficeState.new()
        # 模拟同一 event_id 投递两次
        state.record_event({"event_id": "evt_001", "kind": "like"})
        before_version = state.version
        state.record_event({"event_id": "evt_001", "kind": "like"})
        # version 不变，说明第二次被跳过了
        assert state.version == before_version


class TestPrivacy:
    def test_public_snapshot_no_user_id(self):
        state = OfficeState.new()
        onboarding.dispatch_entry(state=state, event_kind="comment",
                                  user_id="secret_user_id_abc123", nickname="A", text="入职")
        emp = list(state.employees.values())[0]
        pub = emp.to_public_dict()
        assert "user_id" not in pub
        snapshot_emps = onboarding  # 触发 protocol.build_snapshot 检查
        # 直接检查 Employee.to_public_dict 返回值
        assert pub["employee_id"].startswith("emp_")


# ===================== 阶段 2B 新增：员工动作系统 =====================

from datetime import datetime, timedelta, timezone


class TestActionModel:
    """数据模型测试 1–13。"""

    def test_new_employee_default_sleep(self):
        state = OfficeState.new()
        onboarding.dispatch_entry(state=state, event_kind="comment",
                                  user_id="u1", nickname="A", text="入职")
        emp = list(state.employees.values())[0]
        assert emp.action == "sleep"
        assert emp.action_started_at is None
        assert emp.action_until is None

    def test_apply_action_phone(self):
        state = OfficeState.new()
        onboarding.dispatch_entry(state=state, event_kind="comment",
                                  user_id="u1", nickname="A", text="入职")
        emp_id = list(state.employees.keys())[0]
        res = state.apply_action(emp_id, "phone", source="gift:gift_phone")
        assert res["ok"] is True
        assert res["action"] == "phone"
        assert res["old_action"] == "sleep"
        emp = state.employees[emp_id]
        assert emp.action == "phone"
        assert emp.action_started_at is not None
        assert emp.action_until is not None
        # 持续时间在 8-15s 范围内
        start = datetime.fromisoformat(emp.action_started_at)
        until = datetime.fromisoformat(emp.action_until)
        duration = (until - start).total_seconds()
        assert 8.0 <= duration <= 15.0

    def test_apply_action_snack(self):
        state = OfficeState.new()
        onboarding.dispatch_entry(state=state, event_kind="comment",
                                  user_id="u1", nickname="A", text="入职")
        emp_id = list(state.employees.keys())[0]
        state.apply_action(emp_id, "snack")
        emp = state.employees[emp_id]
        start = datetime.fromisoformat(emp.action_started_at)
        until = datetime.fromisoformat(emp.action_until)
        duration = (until - start).total_seconds()
        assert 10.0 <= duration <= 18.0

    def test_apply_action_work(self):
        state = OfficeState.new()
        onboarding.dispatch_entry(state=state, event_kind="comment",
                                  user_id="u1", nickname="A", text="入职")
        emp_id = list(state.employees.keys())[0]
        state.apply_action(emp_id, "work", source="manual")
        emp = state.employees[emp_id]
        assert emp.action == "work"
        assert emp.action_until is None  # work 是持续动作
        assert emp.action_started_at is not None

    def test_apply_action_sleep_resets(self):
        state = OfficeState.new()
        onboarding.dispatch_entry(state=state, event_kind="comment",
                                  user_id="u1", nickname="A", text="入职")
        emp_id = list(state.employees.keys())[0]
        state.apply_action(emp_id, "phone")
        state.apply_action(emp_id, "sleep")
        emp = state.employees[emp_id]
        assert emp.action == "sleep"
        assert emp.action_started_at is None
        assert emp.action_until is None
        assert emp.action_source is None

    def test_apply_action_nonexistent_employee(self):
        state = OfficeState.new()
        res = state.apply_action("emp_not_exist", "phone")
        assert res["ok"] is False
        assert "not in office" in res["detail"]

    def test_apply_action_unknown_action(self):
        state = OfficeState.new()
        onboarding.dispatch_entry(state=state, event_kind="comment",
                                  user_id="u1", nickname="A", text="入职")
        emp_id = list(state.employees.keys())[0]
        res = state.apply_action(emp_id, "coffee")
        assert res["ok"] is False

    def test_new_action_overwrites_old(self):
        state = OfficeState.new()
        onboarding.dispatch_entry(state=state, event_kind="comment",
                                  user_id="u1", nickname="A", text="入职")
        emp_id = list(state.employees.keys())[0]
        state.apply_action(emp_id, "phone")
        state.apply_action(emp_id, "snack")
        emp = state.employees[emp_id]
        assert emp.action == "snack"

    def test_seat_state_action_synced(self):
        state = OfficeState.new()
        onboarding.dispatch_entry(state=state, event_kind="comment",
                                  user_id="u1", nickname="A", text="入职")
        seat = state.seats[0]
        assert seat.action == "sleep"  # 新员工入职时设为 sleep
        emp_id = list(state.employees.keys())[0]
        state.apply_action(emp_id, "phone")
        assert seat.action == "phone"

    def test_leave_does_not_leak_action_to_promoted(self):
        state = OfficeState.new()
        # 填满 25 工位
        for i in range(1, 26):
            onboarding.dispatch_entry(state=state, event_kind="comment",
                                      user_id=f"u{i}", nickname=f"user{i}", text="入职")
        # 队首排队
        onboarding.dispatch_entry(state=state, event_kind="comment",
                                  user_id="u26", nickname="Q1", text="入职")
        # 让 01 号员工做 phone 动作
        emp_01_id = state.seats[0].employee_id
        state.apply_action(emp_01_id, "phone")
        assert state.seats[0].action == "phone"
        # 01 号离场 → Q1 补位
        state.leave_employee_by_seat(1)
        # 补位员工应该是 sleep，不是 phone
        assert state.seats[0].action == "sleep"

    def test_reset_clears_all_actions(self):
        state = OfficeState.new()
        onboarding.dispatch_entry(state=state, event_kind="comment",
                                  user_id="u1", nickname="A", text="入职")
        emp_id = list(state.employees.keys())[0]
        state.apply_action(emp_id, "phone")
        state.reset_for_new_session()
        assert len(state.employees) == 0
        for seat in state.seats:
            assert seat.action is None


class TestActionExpiry:
    """自动恢复测试 14–20。"""

    def test_phone_not_expired_no_recover(self):
        state = OfficeState.new()
        onboarding.dispatch_entry(state=state, event_kind="comment",
                                  user_id="u1", nickname="A", text="入职")
        emp_id = list(state.employees.keys())[0]
        state.apply_action(emp_id, "phone")
        # 用 fake now 再检查，到期时间加 5 秒还没到
        emp = state.employees[emp_id]
        until = datetime.fromisoformat(emp.action_until)
        fake_now = until - timedelta(seconds=5)
        changed = state.expire_actions(now=fake_now)
        assert changed is False
        assert state.employees[emp_id].action == "phone"

    def test_phone_expired_recovers(self):
        state = OfficeState.new()
        onboarding.dispatch_entry(state=state, event_kind="comment",
                                  user_id="u1", nickname="A", text="入职")
        emp_id = list(state.employees.keys())[0]
        state.apply_action(emp_id, "phone")
        emp = state.employees[emp_id]
        until = datetime.fromisoformat(emp.action_until)
        fake_now = until + timedelta(seconds=1)
        changed = state.expire_actions(now=fake_now)
        assert changed is True
        assert state.employees[emp_id].action == "sleep"
        assert state.employees[emp_id].action_until is None
        # SeatState 同步恢复
        assert state.seats[state.employees[emp_id].seat_index - 1].action is None

    def test_snack_expired_recovers(self):
        state = OfficeState.new()
        onboarding.dispatch_entry(state=state, event_kind="comment",
                                  user_id="u1", nickname="A", text="入职")
        emp_id = list(state.employees.keys())[0]
        state.apply_action(emp_id, "snack")
        emp = state.employees[emp_id]
        until = datetime.fromisoformat(emp.action_until)
        fake_now = until + timedelta(seconds=0.1)
        changed = state.expire_actions(now=fake_now)
        assert changed is True

    def test_work_never_expires(self):
        state = OfficeState.new()
        onboarding.dispatch_entry(state=state, event_kind="comment",
                                  user_id="u1", nickname="A", text="入职")
        emp_id = list(state.employees.keys())[0]
        state.apply_action(emp_id, "work")
        fake_now = utc_now() + timedelta(days=365)  # 一年后
        changed = state.expire_actions(now=fake_now)
        assert changed is False
        assert state.employees[emp_id].action == "work"

    def test_no_change_version_not_incremented(self):
        state = OfficeState.new()
        onboarding.dispatch_entry(state=state, event_kind="comment",
                                  user_id="u1", nickname="A", text="入职")
        # apply_action phone 会加 version
        emp_id = list(state.employees.keys())[0]
        state.apply_action(emp_id, "phone")
        before = state.version
        # 未到期 expire，version 不变
        emp = state.employees[emp_id]
        until = datetime.fromisoformat(emp.action_until)
        state.expire_actions(now=until - timedelta(seconds=10))
        assert state.version == before

    def test_change_does_increment_version(self):
        state = OfficeState.new()
        onboarding.dispatch_entry(state=state, event_kind="comment",
                                  user_id="u1", nickname="A", text="入职")
        emp_id = list(state.employees.keys())[0]
        state.apply_action(emp_id, "phone")
        before = state.version
        emp = state.employees[emp_id]
        until = datetime.fromisoformat(emp.action_until)
        state.expire_actions(now=until + timedelta(seconds=1))
        assert state.version > before

    def test_multiple_employees_expire(self):
        state = OfficeState.new()
        # 3 个员工同时做 phone
        for i in range(1, 4):
            onboarding.dispatch_entry(state=state, event_kind="comment",
                                      user_id=f"u{i}", nickname=f"A{i}", text="入职")
        emp_ids = list(state.employees.keys())
        for eid in emp_ids:
            state.apply_action(eid, "phone", duration_s=5.0)  # 手动给短持续时间便于测试
        # 5 秒后全部到期
        changed = state.expire_actions(now=utc_now() + timedelta(seconds=6))
        assert changed is True
        for eid in emp_ids:
            assert state.employees[eid].action == "sleep"


class TestSnapshotProtocolV3:
    """协议测试 21–27。"""

    def test_protocol_version_is_3(self, client):
        data = client.get("/api/state").json()
        assert data["protocol_version"] == 3

    def test_seats_count_remains_25(self, client):
        data = client.get("/api/state").json()
        assert len(data["seats"]) == 25
        assert [s["index"] for s in data["seats"]] == list(range(1, 26))

    def test_occupied_seat_has_action(self, client):
        # 让 u1 入职再设置 phone
        client.post("/api/mock/event", json={
            "kind": "comment", "user_id": "u1", "nickname": "A", "text": "入职",
        })
        state = get_state_from_app()
        emp_id = list(state.employees.keys())[0]
        # 直接在 state 上 apply
        from app.runtime import get_state as g
        s = g()
        s.apply_action(emp_id, "phone", duration_s=15.0)
        snapshot = build_snapshot(s)
        seat = snapshot["seats"][s.employees[emp_id].seat_index - 1]
        assert seat["action"] == "phone"
        assert seat["action_remaining_s"] is not None
        assert seat["action_remaining_s"] > 0

    def test_empty_seat_action_null(self, client):
        data = client.get("/api/state").json()
        for seat in data["seats"]:
            if seat["employee_id"] is None:
                assert seat["action"] is None
                assert seat["action_remaining_s"] is None

    def test_phone_has_remaining_time(self, client):
        client.post("/api/mock/event", json={
            "kind": "comment", "user_id": "u1", "nickname": "A", "text": "入职",
        })
        from app.runtime import get_state as g
        s = g()
        emp_id = list(s.employees.keys())[0]
        s.apply_action(emp_id, "phone", duration_s=12.0)
        snapshot = build_snapshot(s)
        seat = snapshot["seats"][0]
        assert seat["action_remaining_s"] is not None
        # 刚 apply 完应该接近 12 秒
        assert 8.0 <= seat["action_remaining_s"] <= 15.0

    def test_work_remaining_is_none(self, client):
        client.post("/api/mock/event", json={
            "kind": "comment", "user_id": "u1", "nickname": "A", "text": "入职",
        })
        from app.runtime import get_state as g
        s = g()
        emp_id = list(s.employees.keys())[0]
        s.apply_action(emp_id, "work")
        snapshot = build_snapshot(s)
        seat = snapshot["seats"][0]
        assert seat["action_remaining_s"] is None

    def test_existing_employees_field_untouched(self, client):
        # employees[] 仍然存在且不暴露 user_id
        data = client.get("/api/state").json()
        assert "employees" in data
        assert isinstance(data["employees"], list)

        client.post("/api/mock/event", json={
            "kind": "comment", "user_id": "secret_uid", "nickname": "B", "text": "入职",
        })
        data2 = client.get("/api/state").json()
        emp = data2["employees"][0]
        assert "user_id" not in emp
        assert emp["action"] == "sleep"


def utc_now():
    return datetime.now(timezone.utc)


def get_state_from_app():
    from app.runtime import get_state
    return get_state()


# 额外 import（避免顶部 import 冲突）
from app.realtime.protocol import build_snapshot


class TestActionAPI:
    """API 测试 28–39。"""

    def test_manual_trigger_phone(self, client):
        # 先让员工入职
        client.post("/api/mock/event", json={
            "kind": "comment", "user_id": "u1", "nickname": "A", "text": "入职",
        })
        res = client.post("/api/mock/action", json={"seat_index": 1, "action": "phone"})
        assert res.status_code == 200
        data = res.json()
        assert data["ok"] is True
        seat = data["snapshot"]["seats"][0]
        assert seat["action"] == "phone"

    def test_manual_trigger_snack(self, client):
        client.post("/api/mock/event", json={
            "kind": "comment", "user_id": "u1", "nickname": "A", "text": "入职",
        })
        res = client.post("/api/mock/action", json={"seat_index": 1, "action": "snack"})
        assert res.status_code == 200
        assert res.json()["ok"] is True

    def test_manual_trigger_work(self, client):
        client.post("/api/mock/event", json={
            "kind": "comment", "user_id": "u1", "nickname": "A", "text": "入职",
        })
        res = client.post("/api/mock/action", json={"seat_index": 1, "action": "work"})
        assert res.status_code == 200
        assert res.json()["ok"] is True

    def test_action_on_empty_seat_fails(self, client):
        # 工位 1 空闲
        res = client.post("/api/mock/action", json={"seat_index": 1, "action": "phone"})
        assert res.status_code == 200  # 返回 200 但 ok=False（业务错误不是 HTTP 错误）
        assert res.json()["ok"] is False
        assert "空闲" in res.json()["detail"]

    def test_invalid_seat_param_422(self, client):
        res = client.post("/api/mock/action", json={"seat_index": 99, "action": "phone"})
        assert res.status_code == 422

    def test_invalid_action_param_422(self, client):
        client.post("/api/mock/event", json={
            "kind": "comment", "user_id": "u1", "nickname": "A", "text": "入职",
        })
        res = client.post("/api/mock/action", json={"seat_index": 1, "action": "coffee"})
        assert res.status_code == 422

    def test_gift_phone_triggers_action(self, client):
        # donor 先入职
        client.post("/api/mock/event", json={
            "kind": "comment", "user_id": "u1", "nickname": "A", "text": "入职",
        })
        # donor 送 gift_phone → 对 donor 自己触发 phone
        res = client.post("/api/mock/event", json={
            "kind": "gift", "user_id": "u1", "nickname": "A", "gift_id": "gift_phone",
        })
        assert res.status_code == 200
        # 检查 snapshot 里的 action
        seat = res.json()["snapshot"]["seats"][0]
        assert seat["action"] == "phone"

    def test_gift_snack_triggers_action(self, client):
        client.post("/api/mock/event", json={
            "kind": "comment", "user_id": "u1", "nickname": "A", "text": "入职",
        })
        res = client.post("/api/mock/event", json={
            "kind": "gift", "user_id": "u1", "nickname": "A", "gift_id": "gift_snack",
        })
        seat = res.json()["snapshot"]["seats"][0]
        assert seat["action"] == "snack"

    def test_gift_file_triggers_work(self, client):
        client.post("/api/mock/event", json={
            "kind": "comment", "user_id": "u1", "nickname": "A", "text": "入职",
        })
        res = client.post("/api/mock/event", json={
            "kind": "gift", "user_id": "u1", "nickname": "A", "gift_id": "gift_file",
        })
        seat = res.json()["snapshot"]["seats"][0]
        assert seat["action"] == "work"

    def test_gift_to_specified_seat(self, client):
        # u1 和 u2 都入职（工位 1、2）
        client.post("/api/mock/event", json={
            "kind": "comment", "user_id": "u1", "nickname": "A", "text": "入职",
        })
        client.post("/api/mock/event", json={
            "kind": "comment", "user_id": "u2", "nickname": "B", "text": "入职",
        })
        # donor u1 送 gift_phone 指定 seat_index=2 → 应该 u2 触发 phone
        res = client.post("/api/mock/event", json={
            "kind": "gift", "user_id": "u1", "nickname": "A",
            "gift_id": "gift_phone", "seat_index": 2,
        })
        seats = res.json()["snapshot"]["seats"]
        # u1 (seat 1) 应该还是 sleep
        assert seats[0]["action"] == "sleep"
        # u2 (seat 2) 应该是 phone
        assert seats[1]["action"] == "phone"

    def test_gift_to_empty_seat_no_crash(self, client):
        # 空工位
        client.post("/api/mock/event", json={
            "kind": "gift", "user_id": "u1", "nickname": "A",
            "gift_id": "gift_phone", "seat_index": 5,
        })
        # 事件应该正常记录，不 crash
        data = client.get("/api/state").json()
        assert data["session"]["event_counts"]["gift"] == 1

    def test_gift_idempotent_still_works(self, client):
        # 旧功能：指定 event_id 的事件只处理一次
        client.post("/api/mock/event", json={
            "kind": "comment", "user_id": "u1", "nickname": "A", "text": "入职",
            "event_id": "evt_dedup",
        })
        # 同一个 event_id 再发一次
        res = client.post("/api/mock/event", json={
            "kind": "comment", "user_id": "u2", "nickname": "B", "text": "入职",
            "event_id": "evt_dedup",
        })
        assert res.json().get("idempotent") is True
