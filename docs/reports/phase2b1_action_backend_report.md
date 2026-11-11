# HiMoyu 阶段 2B-1 · 员工动作状态后端系统 开发报告

> 完成日期：2026-11-10
> 阶段：2B-1（仅后端）
> pytest：**65/65 通过**（2.20s，零回归）

---

## 1. 本阶段完成了哪些功能

1. **Python 后端动作状态管理系统**：为 Employee 增加 action / action_started_at / action_until / action_source 四个字段，支持 sleep / phone / snack / work 四种动作。
2. **OfficeState.apply_action()**：权威的动作设置方法，检查合法性、计算持续时间、同步 SeatState 快照、返回操作结果。
3. **OfficeState.expire_actions()**：批量检查到期动作、自动恢复 sleep、返回是否有变化。支持可注入 now 参数以便测试。
4. **FastAPI lifespan 后台过期检查**：启动时创建 asyncio.Task，每 0.5s 检查一次动作到期，仅在实际变化时广播。应用关闭时正确 cancel + await。
5. **asyncio.Lock 状态锁**：保护所有 "修改 state + broadcast" 序列，避免后台 expirer 和用户请求协程交错。
6. **WebSocket 协议升级 v3**：seats[] 新增 `action` + `action_remaining_s` 字段。向后兼容（旧 Godot 忽略新字段正常运行）。
7. **MockEventIn 扩展 seat_index**：礼物事件可指定目标工位。
8. **礼物→动作自动触发**：gift_phone → phone / gift_snack → snack / gift_file → work。支持指定工位或默认对送礼者本人。
9. **新增手动动作接口**：`POST /api/mock/action`，支持手动控制任意工位员工动作。
10. **完整的动作系统测试套件**：37 个新增测试覆盖数据模型、过期恢复、协议 v3、API 四个维度。

---

## 2. 修改了哪些文件 + 具体改动

| 文件 | 操作 | 改动量 | 具体内容 |
|---|---|---|---|
| `src/engine/app/config.py` | 修改 | +28 行 | 新增 `VALID_ACTIONS` / `ACTION_DEFAULTS` / `GIFT_TO_ACTION` / `EXPIRE_CHECK_INTERVAL` |
| `src/engine/app/domain/models.py` | 修改 | +120 行 | Employee +4 字段；SeatState +1 字段 + to_dict 扩展；OfficeState 加 `apply_action()` + `expire_actions()`；try_enter/leave/reset 里同步 SeatState.action；新增 `utc_now()` 工具函数 |
| `src/engine/app/realtime/protocol.py` | 重写 | ~60 行 | PROTOCOL_VERSION=3；build_snapshot 为每个 seat 计算 action_remaining_s（动态只读投影，不修改 state） |
| `src/engine/app/main.py` | 重写 | ~70 行 | 新增 FastAPI lifespan 上下文管理器，启动 `_expire_loop()` asyncio.Task，关闭时正确清理 |
| `src/engine/app/runtime.py` | 修改 | +8 行 | 新增全局 `state_lock = asyncio.Lock()` |
| `src/engine/app/api/routes_mock.py` | 重写 | ~180 行 | MockEventIn 加 seat_index；`_apply_gift_action_if_any()` 礼物→动作映射；所有 state 修改+broadcast 包 `async with state_lock`；新增 `POST /api/mock/action` |
| `src/engine/app/api/routes_state.py` | 修改 | 小幅 | reset 端点加 state_lock 保护 |
| `tests/test_phase0_contract.py` | 修改 | +460 行 | protocol_version 断言 2→3；新增 37 个测试（TestActionModel 12 / TestActionExpiry 7 / TestSnapshotProtocolV3 7 / TestActionAPI 11） |
| `docs/DEVELOPMENT_STATUS.md` | 修改 | +15 行 | 更新阶段、新增模块条目、协议版本、pytest 结果、下一步待办 |

**未修改的冻结区域**：所有 Godot 代码（employee_3d.gd / office_full_25.gd / workstation_3d.gd / mesh_kit.gd / ws_client.gd / .tscn 场景文件）、浏览器模拟台 HTML/CSS/JS。

---

## 3. WebSocket v3 快照结构示例

```json
{
  "type": "snapshot",
  "protocol_version": 3,
  "version": 7,
  "server_time": "2026-11-10T12:00:00+00:00",
  "session": { "...": "..." },
  "seats": [
    {
      "index": 1,
      "employee_id": "emp_a1b2c3d4e5",
      "nickname": "摸鱼小王",
      "action": "phone",
      "action_remaining_s": 11.3
    },
    {
      "index": 2,
      "employee_id": "emp_f6g7h8i9j0",
      "nickname": "阿花",
      "action": "work",
      "action_remaining_s": null
    },
    {
      "index": 3,
      "employee_id": null,
      "nickname": null,
      "action": null,
      "action_remaining_s": null
    }
    // ... 共 25 个
  ],
  "employees": [ /* 同 v2，新增 action + action_source 字段 */ ]
}
```

---

## 4. 三种动作如何管理

| 动作 | action 值 | 触发方式 | 持续时间 | 恢复规则 |
|---|---|---|---|---|
| phone | `"phone"` | gift_phone / /api/mock/action | 8–15s（随机） | `action_until` 到期后 expire_actions() 自动恢复 sleep |
| snack | `"snack"` | gift_snack / /api/mock/action | 10–18s（随机） | 同上 |
| work | `"work"` | gift_file / /api/mock/action | **持续**（`action_until=None`） | 不会自动恢复，只能被新动作覆盖 |
| sleep | `"sleep"` | 默认 / /api/mock/action | 持续直到被覆盖 | 默认状态，永远不会"过期" |

新动作覆盖旧动作时，直接替换 Employee 的 action 相关字段，不建立队列。

---

## 5. 后端如何自动检查动作到期并恢复 sleep

```
FastAPI lifespan startup:
  asyncio.create_task(_expire_loop())  # 单次创建，生命周期跟随应用

_expire_loop():
  while True:
    await asyncio.sleep(0.5)            # 固定间隔
    async with state_lock:
      state = get_state()
      if state.expire_actions():       # O(N) 遍历 25 人，检查 until 是否过期
          snapshot = build_snapshot(state)
          await hub.broadcast(snapshot)  # 只有变化才广播
      # 无变化 → 不广播，回到 sleep
```

关键约束：
- 后台任务**只有一个**（`_expire_task` 句柄全局唯一）
- **只有实际变化才广播**（`expire_actions()` 返回 bool）
- 生命周期正确：TestClient 上下文管理 → lifespan → startup/shutdown 完整触发
- 零新依赖：只用 Python 标准库的 asyncio，没有 APScheduler 等外部框架

---

## 6. 礼物触发动作的目标选择规则

```
MockEventIn:
  user_id: str          # 送礼者
  nickname: str
  gift_id: str          # gift_phone / gift_snack / gift_file 等
  seat_index: int | None  # 可选目标工位（1-25）

路由逻辑 (_apply_gift_action_if_any):
  if gift_id not in GIFT_TO_ACTION → skip（入职礼物等不触发动作）

  if seat_index is not None:
      target = seats[seat_index-1].employee_id    # 指定工位的员工
  else:
      target = user_to_employee[user_id]           # 默认送礼者本人（必须已在职）

  if target is None → 日志记录"无有效目标"，事件继续（gift 计数正常 +1）
  else → state.apply_action(target, GIFT_TO_ACTION[gift_id], source="gift:{gift_id}")
```

时序保证：dispatch_entry（入职逻辑）先于礼物→动作。所以如果 donor 同时达成了入职条件（不太常见但理论上可能），他会先入职成功，礼物→动作就能找到在职的 employee_id。

---

## 7. /api/mock/action 实际请求和返回示例

**请求：**
```json
POST http://127.0.0.1:8000/api/mock/action
Content-Type: application/json

{
  "seat_index": 3,
  "action": "phone",
  "duration_s": 12.5,
  "source": "manual"
}
```

**成功返回：**
```json
{
  "ok": true,
  "action": {
    "ok": true,
    "employee_id": "emp_a1b2c3d4e5",
    "action": "phone",
    "old_action": "sleep"
  },
  "snapshot": { /* 完整 v3 快照 */ }
}
```

**空工位返回：**
```json
{
  "ok": false,
  "detail": "工位 5 当前空闲",
  "snapshot": { /* 最新快照 */ }
}
```

---

## 8. pytest 完整结果

```
============================= test session starts =============================
platform win32 -- Python 3.14.5, pytest-9.2.0, pluggy-1.7.0
collected 65 items

test_phase0_contract.py::test_health PASSED
test_phase0_contract.py::test_snapshot_contract PASSED        [protocol v3]
test_phase0_contract.py::test_like_repeat_counts PASSED
test_phase0_contract.py::test_comment_and_gift_defaults PASSED
test_phase0_contract.py::test_reset_session PASSED
test_phase0_contract.py::test_invalid_mock_event[payload0] PASSED
test_phase0_contract.py::test_invalid_mock_event[payload1] PASSED
test_phase0_contract.py::test_invalid_mock_event[payload2] PASSED
test_phase0_contract.py::test_websocket_receives_snapshot_after_event PASSED
TestLikeEntry (4/4) PASSED
TestCommentEntry (3/3) PASSED
TestGiftEntry (2/2) PASSED
TestSeatAllocation (4/4) PASSED
TestLeaveAndPromote (4/4) PASSED
TestIdempotency (1/1) PASSED
TestPrivacy (1/1) PASSED
TestActionModel (12/12) PASSED          [新增]
TestActionExpiry (7/7) PASSED           [新增]
TestSnapshotProtocolV3 (7/7) PASSED    [新增]
TestActionAPI (11/11) PASSED            [新增]

======================= 65 passed, 2 warnings in 2.20s ========================
```

**28 个原有阶段 2A 测试零回归**，37 个新增动作系统测试全部通过。

---

## 9. 遗留问题 / 已知限制

| # | 问题 | 影响 | 处理计划 |
|---|---|---|---|
| 1 | 后台 expirer 在 expire 后 broadcast 的快照里，SeatState.action 是 `None`（表示默认 sleep）而不是 `"sleep"` | Godot 端读取时需要同时处理 `None` 和 `"sleep"` → 都解释为默认 | 阶段 2B-2 Godot 端 `if seat.action in (None, "sleep"): set_action(SLEEP)` |
| 2 | 测试里直接操作 runtime.get_state() 绕过了 TestClient 的 session reset | 不影响正确性（测试在单独进程），但 TestSnapshotProtocolV3 类的测试之间有隐式 state 共享 | 后续可考虑用显式 fixture reset state |
| 3 | expire_loop 异常捕获后继续循环 | 如果 state_lock 本身状态异常，锁可能一直处于 held 状态 | 目前单线程协程不会真正死锁；若后续改为多线程需要更严谨处理 |
| 4 | 礼物+入职事件同时发生的边界场景未专门测试 | 理论上 dispatch_entry 在礼物→动作之前执行，如果入职条件被同时触发，donor 会在同一个请求里先入职再被设动作 | 实际业务中 gift_phone 不是入职礼物，这个场景不会自然发生 |

---

## 10. 待提交文件清单（Git status）

**未提交：** 全部 9 个修改文件 + 2 个新文件

```
M  src/engine/app/config.py
M  src/engine/app/domain/models.py
M  src/engine/app/realtime/protocol.py
M  src/engine/app/main.py
M  src/engine/app/runtime.py
M  src/engine/app/api/routes_mock.py
M  src/engine/app/api/routes_state.py
M  tests/test_phase0_contract.py
M  docs/DEVELOPMENT_STATUS.md
?? docs/reports/phase2b1_action_backend_report.md   (本报告)
```

**建议提交信息：**
```
feat(2B-1): implement employee action state system with WebSocket protocol v3

- Add action fields to Employee (action, started_at, until, source)
- OfficeState.apply_action() for authoritative action management
- OfficeState.expire_actions() for batched expiry check
- FastAPI lifespan background expirer loop (0.5s interval, broadcast-on-change)
- asyncio.Lock protects state modify + broadcast atomicity
- WebSocket protocol v3: seats[].action + seats[].action_remaining_s
- Gift→action mapping (gift_phone→phone, gift_snack→snack, gift_file→work)
- POST /api/mock/action endpoint for manual control
- MockEventIn.seat_index for targeting specific station
- 65/65 pytest passed (28 original + 37 new action tests)
- Zero regression, backward compatible with v2 clients
```

---

## 11. 手动验证 curl 命令

```powershell
# ========== 基础设置 ==========
# 1. 重置场次
curl -X POST http://127.0.0.1:8000/api/session/reset

# 2. 让 u1 入职（工位 1）
curl -X POST http://127.0.0.1:8000/api/mock/event ^
     -H "Content-Type: application/json" ^
     -d "{\"kind\":\"comment\",\"user_id\":\"u1\",\"nickname\":\"小王\",\"text\":\"入职\"}"

# ========== 手动动作接口 ==========
# 3. 手动触发 phone
curl -X POST http://127.0.0.1:8000/api/mock/action ^
     -H "Content-Type: application/json" ^
     -d "{\"seat_index\":1,\"action\":\"phone\"}"

# 4. 手动触发 work（持续动作，不会自动恢复）
curl -X POST http://127.0.0.1:8000/api/mock/action ^
     -H "Content-Type: application/json" ^
     -d "{\"seat_index\":1,\"action\":\"work\"}"

# 5. 显式恢复 sleep
curl -X POST http://127.0.0.1:8000/api/mock/action ^
     -H "Content-Type: application/json" ^
     -d "{\"seat_index\":1,\"action\":\"sleep\"}"

# ========== 礼物触发动作 ==========
# 6. donor 送 gift_phone（donor 本人已在职 → donor 触发 phone）
curl -X POST http://127.0.0.1:8000/api/mock/event ^
     -H "Content-Type: application/json" ^
     -d "{\"kind\":\"gift\",\"user_id\":\"u1\",\"nickname\":\"小王\",\"gift_id\":\"gift_phone\"}"

# 7. donor 送 gift_phone 指定 seat_index=1（donor 自己的工位，等价于上条）
curl -X POST http://127.0.0.1:8000/api/mock/event ^
     -H "Content-Type: application/json" ^
     -d "{\"kind\":\"gift\",\"user_id\":\"u1\",\"nickname\":\"小王\",\"gift_id\":\"gift_snack\",\"seat_index\":1}"

# ========== 边界测试 ==========
# 8. 空工位触发动作 → ok=False
curl -X POST http://127.0.0.1:8000/api/mock/action ^
     -H "Content-Type: application/json" ^
     -d "{\"seat_index\":5,\"action\":\"phone\"}"

# 9. 查看完整快照（确认 action 字段）
curl http://127.0.0.1:8000/api/state | python -m json.tool

# 10. 查看协议版本
curl -s http://127.0.0.1:8000/api/state | python -c "import sys,json; d=json.load(sys.stdin); print(f'protocol_version={d[\"protocol_version\"]}')"
```

---

**阶段 2B-1 后端开发完成，等待验收后进入阶段 2B-2（Godot 动作动画）。**
