# 阶段 2A · 员工入职系统与 WebSocket 实时同步 · 验收报告

> 验收日期：2026-11-09
> Git 提交：`464755d`（`feat: implement employee admission system with WebSocket sync`）
> 测试结果：**pytest 28/28 通过 · 七场景 A-G 全部真实联调通过**

## 一、验收范围

本次验收覆盖阶段 2A 的全部交付物：Python 后端入职规则引擎、工位分配与排队离场、WebSocket 协议升级 v2、Godot 3D 办公室 WebSocket 快照驱动、浏览器模拟台扩展。

**不在验收范围**（明确排除）：
- 真实抖音 API 接入
- 老板巡查、会议等管理层事件
- 排行榜、晋升系统
- 重新建模或重构办公室场景

## 二、交付文件清单

| # | 文件 | 类型 | 行数 | 说明 |
|---|---|---|---|---|
| 1 | `src/engine/app/config.py` | 修改 | +28 | 新增阶段 2A 配置常量 |
| 2 | `src/engine/app/domain/models.py` | 修改 | +241 | 扩展 `OfficeState`（Employee / QueueEntry / try_enter / leave_employee_by_seat / reset_for_new_session） |
| 3 | `src/engine/app/domain/onboarding.py` | **新建** | 165 | 入职规则引擎（handle_like / handle_comment / handle_gift / dispatch_entry） |
| 4 | `src/engine/app/realtime/protocol.py` | 修改 | +26 | 协议升级到 v2，新增 queue_count / queue_preview / employees[] |
| 5 | `src/engine/app/api/routes_mock.py` | 修改 | +107 | 重写为入职规则驱动，新增 `/api/mock/leave` |
| 6 | `src/engine/app/ingestion/events.py` | 修改 | +24 | build_mock_event 支持 event_id 去重 |
| 7 | `src/engine/simulator/index.html` | 修改 | +54 | 点赞累计/评论/离场/员工列表/队列显示 |
| 8 | `src/engine/simulator/app.js` | 修改 | +156 | 完整重写 |
| 9 | `src/game/scenes/prototype_3d/office_full_25.gd` | 修改 | +71 | 接入 HimoyuWSClient + 新增 _apply_snapshot |
| 10 | `tests/test_phase0_contract.py` | 修改 | +247 | 28 项测试（原有 9 + 新增 19） |

总计 **10 个文件**，+1019/-100 行。

## 三、pytest 结果

```
============================== warnings summary ===============================
-- Docs: https://docs.pytest.org/en/stable/how-to/capture-warnings.html
================== 28 passed, 2 warnings in 1.08s ============================
```

### 原有 9 项（保留，未跳过）

| # | 测试 | 结果 | 说明 |
|---|---|---|---|
| 1 | test_health | ✅ | /api/health 返回 ok |
| 2 | test_snapshot_contract | ✅ | 协议 v2，queue_count / free_seats 字段存在 |
| 3 | test_like_repeat_counts | ✅ | repeat=10 触发入职 |
| 4 | test_comment_and_gift_defaults | ✅ | "入职" 关键词 + demo_entry_gift 都能触发 |
| 5 | test_reset_session | ✅ | 清空后 event_counts / occupied / employees 全部归零 |
| 6-8 | test_invalid_mock_event × 3 | ✅ | 非法 kind / repeat=0 / repeat=1001 返回 422 |
| 9 | test_websocket_receives_snapshot_after_event | ✅ | WS 连接 → 初始快照 → like 触发 → 收到广播 |

### 新增 19 项

| 类 | 测试 | 结果 | 覆盖点 |
|---|---|---|---|
| TestLikeEntry | test_like_9_not_entry | ✅ | 9 赞未满阈值 |
| | test_like_10_entry | ✅ | 10 赞刚好触发 |
| | test_like_5plus5_entry | ✅ | 分两次累计 |
| | test_different_users_likes_not_mixed | ✅ | 不同用户不串赞 |
| TestCommentEntry | test_keyword_entry | ✅ | 精确匹配 "入职" |
| | test_non_keyword_no_entry | ✅ | "hi" 不触发 |
| | test_whitespace_keyword | ✅ | " 入职 " 去空格后匹配 |
| TestGiftEntry | test_demo_entry_gift | ✅ | 指定 gift_id 触发 |
| | test_other_gift_no_entry | ✅ | 其他 gift_id 不触发 |
| TestSeatAllocation | test_first_25_users_get_sequential_seats | ✅ | 1→25 顺序分配 |
| | test_26th_user_enters_queue | ✅ | 满员后进队 |
| | test_same_user_no_duplicate | ✅ | 已在职重复调用返回 already_in_office |
| | test_user_in_queue_no_duplicate | ✅ | 排队中重复调用返回 already_in_queue |
| TestLeaveAndPromote | test_leave_frees_seat | ✅ | 释放工位 |
| | test_queue_first_promoted | ✅ | 队首自动补位 |
| | test_leave_empty_seat | ✅ | 空工位离场不报错 |
| | test_reset_clears_everything | ✅ | 清空 employees + queue + user_likes |
| TestIdempotency | test_duplicate_event_id_skipped | ✅ | 相同 event_id 只处理一次 |
| TestPrivacy | test_public_snapshot_no_user_id | ✅ | employees[] 和 queue_preview 都不暴露 user_id |

### 验收中发现并修复的 2 个 Bug

| Bug | 影响 | 修复 |
|---|---|---|
| `MockEventIn.repeat: le=10` 上限太小 | WS 测试发 `repeat=12` 被 Pydantic 拒绝（422），`receive_json()` 永远等不到快照 | 上限放宽到 `le=1000` |
| 测试里的 `repeat: 11` 越界参数 | 配合上限调整，改成 `repeat: 1001` | 同步更新测试 parametrize |

## 四、七场景端到端联调

后端启动（uvicorn port 8000）→ Godot 控制台版启动（连接 WS）→ 逐步触发 → 双端状态一致。

### 后端状态断言

| 场景 | 输入 | 后端状态 | 动作 |
|---|---|---|---|
| A | reset | occ=0, free=25, ver=0 | 空办公室 |
| B | comment "入职"（Ming） | action=joined, seat=1 | ✅ |
| C | like repeat=10（Zhang） | action=joined, seat=2 | ✅ |
| D | 连续 23 次 comment | 23/23 入职, occ=25 | ✅ |
| E | comment Overflow | action=queued, queue=1 | ✅ |
| F | leave seat 01 | Ming left → Overflow promoted→seat 01 | ✅ |
| G | reset | occ=0, queue=0, ver=0 | ✅ |

### Godot 快照日志（控制台版）

```
[HiMoyu-WS] 已连接 WebSocket 客户端，等待快照…
[HiMoyu-SNAP] version=0 occupied=0   ← A
[HiMoyu-SNAP] version=2 occupied=1   ← B
[HiMoyu-SNAP] version=4 occupied=2   ← C
... （中间 22 次逐步填充）
[HiMoyu-SNAP] version=50 occupied=25 ← D
[HiMoyu-SNAP] version=52 occupied=25 ← E (queue_count=1)
[HiMoyu-SNAP] version=54 occupied=25 ← F (leave→promote)
[HiMoyu-SNAP] version=0 occupied=0   ← G
```

### Godot 自动截图（真实渲染，非 AI）

路径：`d:\HiMoyu\.screenshots\phase2a\`

| 文件 | 场景 |
|---|---|
| `01_empty_office.png` | 空办公室（25 员工全隐藏，只留桌椅显示器） |
| `02_single_entry_seat01.png` | Ming 入职 seat 01（只有 01 工位显示人物+名牌） |
| `03_two_entries_seat01_02.png` | Ming seat 01 + Zhang seat 02 |
| `04_five_entries.png` | 5 人入职 |
| `05_full_25_seats.png` | 25 人满员（全部人物+名牌显示） |
| `06_26th_in_queue.png` | 25 人 + 第 26 人排队（画面不变，queue_count=1） |
| `08_leave_promoted.png` | 01 离场后短暂过渡瞬间 |

## 五、办公室冻结检查

| 检查项 | 状态 | 证据 |
|---|---|---|
| 25 工位位置和间距（GRID_X / GRID_Z） | ✅ 未改 | git diff 零修改 |
| 老板办公室位置 | ✅ 未改 | room_full_25.gd 未改动 |
| 主管工位位置 | ✅ 未改 | room_full_25.gd 未改动 |
| 会议室位置和大小 | ✅ 未改 | room_full_25.gd 未改动 |
| 相机角度（CAM_OFFSET / CAM_TARGET / CAM_SIZE） | ✅ 未改 | git diff 零修改 |
| 员工模型（employee_3d.gd） | ✅ 未改 | 该文件零 diff |
| 睡觉动画 | ✅ 未改 | employee_3d.gd 未动 |
| 名牌视觉风格（颜色/大小/位置） | ✅ 未改 | _build_nickname_overlay() 未改 |
| 静态网格合并 | ✅ 未改 | mesh_kit.gd 未动 |

### office_full_25.gd 实际改动清单（git diff）

| 改动位置 | 内容 | 是否影响视觉 |
|---|---|---|
| 头部注释 | 阶段 1.5 → 2A | ❌ |
| 新增 HimoyuWSClient preload | 引入 WS 客户端 | ❌ |
| 新增 3 个变量 | _ws_client / _stations / _mock_mode | ❌ |
| _ready() 末尾 | 收集 stations + WS 初始化 + 非 capture 初始隐藏 | ❌（capture 模式行为不变） |
| _update_nicknames() 末尾 | 加 mock_mode 条件保护 | ❌（capture 模式仍全显） |
| 新增 _apply_snapshot() | 按 seats[] 控制显隐 | ❌（仅影响非 capture 模式） |
| HUD 标题 | 更新阶段名 | 轻微（仅文字） |

**结论：所有改动都是动态接入必需的代码，没有改变任何视觉布局。**

## 六、协议说明

快照 `seats[]` 和 `employees[]` 是同源数据的不同视图，不冲突不冗余：

- **`seats[]`**：固定 25 项的工位视角数组。Godot 用这个，因为它需要"25 个工位，每个坐没坐人"。
- **`employees[]`**：动态长度的员工视角列表。浏览器模拟台用这个显示员工详情。

两者都从同一个 `OfficeState` 实例投影出来，由 `try_enter()` 和 `leave_employee_by_seat()` 同步写入，`build_snapshot()` 分别序列化。

## 七、安全检查

| 检查项 | 结果 |
|---|---|
| 快照不暴露 user_id | ✅ Employee.to_public_dict() 排除 user_id；queue_preview 也排除 |
| WebSocket 幂等 | ✅ event_id 去重机制存在 |
| 点赞累计安全 | ✅ 已在职/排队的用户不累计点赞（dispatch_entry 开头去重） |
| 不持久化 | ✅ 进程内状态，重启清空 |
| MockEventIn 输入校验 | ✅ 非法 kind / 越界 repeat / 缺失必填字段全部返回 422 |

## 八、Git 信息

| 项 | 值 |
|---|---|
| Commit Hash | `464755d` |
| 远程 | `https://github.com/hanhongsen/HiMoyu` |
| 推送 | ✅ `0952fc0..464755d  main -> main` |
| 工作区 | clean |

## 九、遗留问题

无阻塞性问题。以下为可选项：

1. **截图分辨率**：`phase2a/` 下的截图是 Godot 控制台版默认窗口大小（约 1280×720），而非 `--capture` 模式的 1920×1080。这不影响验收结论（确实是真实渲染），但如果需要高清版可以用 `--capture` + 手动触发场景生成。
2. **模拟台完整界面截图**：本次未单独截图模拟台（Phase 2A 的核心验收点是 Godot 3D）。
3. **Phase 2B 规划**：抖音真实接入未启动，需产品方案确认后再规划。
