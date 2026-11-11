# HiMoyu · 开发状态总览

> 本文档用于不同 AI 编程工具之间同步项目进度。每次完成开发任务后必须更新。

## 当前阶段

**阶段 2B-1 · 员工动作状态后端系统（已完成并验收，含 2026-11-11 修复轮）**

- 最新 Git 提交：`f2c7713`（2026-11-11 · feat: implement employee action backend system，已推送 origin/main）
- 待提交修复（2026-11-11，等待审查）：event_id 幂等顺序、动作时间戳微秒精度、state_lock 锁内取 state、文档同步
- 远程分支：`main`（`https://github.com/hanhongsen/HiMoyu`）
- 本地工作目录：`D:\HiMoyu`
- Godot 路径：`D:\Godot_v4.7.2-stable_win64.exe`

## 已完成模块

| # | 模块 | 文件路径 | 完成日期 | 备注 |
|---|---|---|---|---|
| 1 | Python 规则引擎 + FastAPI | `src/engine/app/` | 阶段 0 | pytest 契约测试通过 |
| 2 | WebSocket 快照协议 v1→v2 | `src/engine/app/realtime/protocol.py` | 阶段 0 → 2A | 新增 `queue_count` / `queue_preview` / `employees[]` |
| 3 | 浏览器模拟控制台 | `src/engine/simulator/` | 阶段 0 → 2A | 新增点赞累计、评论、离场、排队显示 |
| 4 | 2D 办公室主场景 | `src/game/main.tscn` + `scenes/office/` + `scenes/characters/` | 阶段 1 | 默认启动入口，未修改 |
| 5 | 3 工位 3D 样板间 | `src/game/scenes/prototype_3d/office_preview_3d.tscn` | 阶段 1.5 | 视觉原型 |
| 6 | 25 工位 3D 完整场景 | `src/game/scenes/prototype_3d/office_full_25.tscn` + `.gd` | 阶段 1.5 → 2A | 正面偏俯视正交相机；阶段 2A 接入 HimoyuWSClient |
| 7 | 3D 人物建模与睡觉动画 | `src/game/scenes/prototype_3d/employee_3d.gd` | 阶段 1.5 | 25 种外观，呼吸+头部轻晃+Zzz（未修改） |
| 8 | 静态网格合并优化 | `src/game/scenes/prototype_3d/mesh_kit.gd` → `bake_static()` | 阶段 1.5 | 按材质 + 阴影分组合并 |
| 9 | 老板玻璃办公室 | `room_full_25.gd::_build_boss_office()` | 阶段 1.5 最终 | 位置：x∈[-11.80,-8.80], z∈[-8.52,-5.22]（画面左上） |
| 10 | 主管独立工位 | `room_full_25.gd::_build_supervisor_station()` | 阶段 1.5 最终 | 位置：x=-10.30, z=4.50（画面左下），与老板室分离 |
| 11 | 25 工位 5×5 布局 | `office_full_25.gd::GRID_X/GRID_Z` | 阶段 1.5 第二轮 | 间距 2.60m，编号 01-25（row*5+col+1） |
| 12 | 右侧扩大会议室 | `room_full_25.gd::_build_meeting_room()` | 阶段 1.5 第二轮 | 书柜 yaw=0° 正面朝镜头 |
| 13 | 昵称名牌系统 | `office_full_25.gd::_build_nickname_overlay()` | 阶段 1.5 最终 → 2A | 屏幕空间 CanvasLayer，暖木色底框 #C9A77D；阶段 2A 按快照显隐 |
| 14 | 7 张验收截图流水线 | `office_full_25.gd::_run_capture()` | 阶段 1.5 第二轮 | --capture 命令自动生成 |
| 15 | 300 秒性能压力测试 | `office_full_25.gd::_run_soak()` | 阶段 1.5 第二轮 | --soak=300 命令 |
| 16 | **入职规则引擎（阶段 2A 新增）** | `src/engine/app/domain/onboarding.py` | 2026-11-09 | `handle_like`（10 赞阈值）/ `handle_comment`（"入职"关键词）/ `handle_gift` / `dispatch_entry` |
| 17 | **员工数据模型（阶段 2A 扩展）** | `src/engine/app/domain/models.py` | 2026-11-09 | `Employee`（含 `to_public_dict()` 不暴露 user_id）/ `QueueEntry` / `try_enter()` / `leave_employee_by_seat()` |
| 18 | **Mock 接口扩展（阶段 2A）** | `src/engine/app/api/routes_mock.py` | 2026-11-09 | `/api/mock/event` 调 `dispatch_entry`；新增 `/api/mock/leave`；`repeat` 上限放宽到 1000 |
| 19 | **Godot WebSocket 快照驱动（阶段 2A）** | `office_full_25.gd::_apply_snapshot()` | 2026-11-09 | 非 capture 模式下：连接 `HimoyuWSClient`，初始隐藏所有员工+名牌，按 `seats[]` 控制 25 工位显隐 |
| 20 | **员工动作状态系统（阶段 2B-1）** | `src/engine/app/domain/models.py::Employee/OfficeState` | 2026-11-10 | Employee 新增 action+started_at+until+source；`apply_action()` + `expire_actions()` |
| 21 | **动作配置集中管理（阶段 2B-1）** | `src/engine/app/config.py` | 2026-11-10 | `VALID_ACTIONS` / `ACTION_DEFAULTS` / `GIFT_TO_ACTION` / `EXPIRE_CHECK_INTERVAL` |
| 22 | **WebSocket 协议 v3（阶段 2B-1）** | `src/engine/app/realtime/protocol.py` | 2026-11-10 | PROTOCOL_VERSION=3；seats[] 新增 `action` + `action_remaining_s`（动态只读投影） |
| 23 | **后台过期检查（阶段 2B-1）** | `src/engine/app/main.py::lifespan` + `runtime.py::state_lock` | 2026-11-10 | FastAPI lifespan 启动 asyncio.Task `_expire_loop()`（0.5s 间隔），仅在有变化时广播；`asyncio.Lock` 保护 state 修改+broadcast 原子性 |
| 24 | **礼物→动作映射（阶段 2B-1）** | `src/engine/app/api/routes_mock.py::_apply_gift_action_if_any` | 2026-11-10 | gift_phone→phone / gift_snack→snack / gift_file→work；支持 `seat_index` 指定目标工位 |
| 25 | **手动动作接口（阶段 2B-1）** | `POST /api/mock/action` | 2026-11-10 | seat_index(1-25) + action(sleep/phone/snack/work)；空工位返回 ok=False |
| 26 | **2B-1 修复轮** | `routes_mock.py` / `models.py` / `tests` / 文档 | 2026-11-11 | ① event_id 幂等顺序修复：首次请求正确执行入职/礼物动作，第二次才返回 idempotent=true；② action_started_at/action_until 改微秒精度，避免动作提前最多 1 秒过期；③ event/action/leave/reset 四端点统一"先取锁、锁内取 state、锁内完成读取-修改-快照-广播"；④ README/DEVELOPMENT_STATUS 同步 |

## 关键文件清单（只读/保护）

以下文件已通过前序验收，**后续迭代禁止修改其视觉布局/结构部分**：

- `src/engine/app/` — Python 规则引擎（阶段 0+2A，可扩展接口）
- `src/engine/app/api/ws.py` — WebSocket 协议入口
- `src/game/main.gd` + `main.tscn` — 2D 主场景（未修改）
- `src/game/scenes/office/` — 2D 办公室场景（未修改）
- `src/game/scenes/characters/` — 2D 人物组件（未修改）
- `src/game/scenes/prototype_3d/workstation_3d.gd` — 工位组件（未修改）
- `src/game/scenes/prototype_3d/employee_3d.gd` — 人物模型+动画（未修改）
- `src/game/scenes/prototype_3d/room_full_25.gd` — 办公室结构（未修改布局）
- `src/game/scenes/prototype_3d/mesh_kit.gd` — 程序化建模工具（未修改）
- `src/game/net/ws_client.gd` — Godot WebSocket 客户端（未修改）
- `src/game/config/seat_layout.gd` — 2D 工位布局常量（未修改）

### 阶段 2A 允许修改的文件（仅动态接入相关）

- `office_full_25.gd` — 只能修改：`_ready()` 末尾（WS 初始化）、新增 `_apply_snapshot()`、`_update_nicknames()` 的 mock_mode 条件保护。**禁止修改 GRID_X/GRID_Z、CAM_OFFSET/CAM_TARGET/CAM_SIZE、_build_room()、_build_workstations()、_build_nickname_overlay() 的视觉参数**。

## 协议说明：seats[] 与 employees[] 的关系

快照里有两个员工-工位数据源，**同源、无冲突、互不冗余**：

| 字段 | 结构 | 用途 | 消费端 |
|---|---|---|---|
| `seats[]` | 固定 25 项，index 1-25，每项 `{index, employee_id, nickname}` | 工位视角：每个槽位"坐了谁"，空槽位 employee_id=null | **Godot `_apply_snapshot()`** — 25 个 station 按 index 直接映射 |
| `employees[]` | 动态长度，只有已入职员工，按 seat_index 排序 | 员工视角：在职员工详细信息（entry_method / joined_at 等） | 浏览器模拟台展示 / 未来前端 |

两者都从同一个 `OfficeState` 投影出来。`state.try_enter()` 同时写 `seats[i].employee_id` 和 `employees[emp_id]`，`build_snapshot()` 从同一个 state 的两个成员分别生成两份数组。

## 七场景端到端验收结果（2026-11-09）

| 场景 | 后端状态 | Godot 快照日志 | 结果 |
|---|---|---|---|
| A. 空办公室 | occ=0, free=25 | `[HiMoyu-SNAP] version=0 occupied=0` | ✅ |
| B. 评论入职 | action=joined, seat=1 | `version=2 occupied=1` | ✅ |
| C. 10 赞触发 | action=joined, seat=2 | `version=4 occupied=2` | ✅ |
| D. 填满 25 工位 | 23/23 入职, occ=25 | `version=50 occupied=25` | ✅ |
| E. 第 26 人排队 | action=queued, queue=1 | `version=52 occupied=25`（queue_count=1） | ✅ |
| F. 01 离场→队首补位 | Overflow promoted→seat 01 | `version=54 occupied=25` | ✅ |
| G. reset | occ=0, queue=0, ver=0 | `version=0 occupied=0` | ✅ |

pytest：**28/28 通过**（1.08s），包括原有 9 项 + 阶段 2A 新增 19 项。

验收过程中修复的 2 个 bug：
1. `MockEventIn.repeat: le=10` 放宽到 `le=1000`（原上限导致 WS 测试发 `repeat=12` 时 422 卡住）
2. 测试 parametrize 第三项从 `repeat: 11` 改为 `repeat: 1001`（配合上限调整）

## 约束与硬限制

- **不修改** 25 工位编号规则（01-25，从左到右从上到下）
- **不修改** 静态网格合并优化（`MeshKit.bake_static`）
- **不修改** 相机参数、工位坐标、办公室布局
- **不修改** 人物模型和睡觉动画
- 不使用 force push，不删除之前的截图和开发记录
- 不接入抖音 API，不开发礼物/排行榜/集体事件等后续功能
- 所有外部素材必须有授权；3D 内容全部程序化生成
- 不修改 `project.godot` 默认主场景（保持 2D）

## 下一步待办

1. **阶段 2B-2 · Godot 动作动画**：
   - 拆分 employee_3d.gd 左右手节点 + hand_pivot
   - 实现 phone/snack/work 三种姿势 pose 函数
   - Tween 过渡 + 临时道具 mesh
   - office_full_25.gd 在 _apply_snapshot 中调用 set_action()
2. **阶段 2B-3 · 浏览器模拟台动作控制**：
   - 新增手动动作控制卡片（工位+动作+触发按钮）
   - renderEmployeeList 显示 action 字段
3. **阶段 2B-4 · 礼物事件与抖音接入**：真实抖音礼物 ID 映射

## pytest 结果

阶段 2B-1 + 修复轮：**70/70 通过**
- 原有阶段 2A 28 个测试全部通过（零回归）
- 新增 37 个动作系统测试（TestActionModel 12 + TestActionExpiry 7 + TestSnapshotProtocolV3 7 + TestActionAPI 11）
- 2026-11-11 修复轮新增 5 个测试（TestEventIdSemantics 3：幂等首次执行 / 二次拦截 / 礼物动作首次生效；TestActionTimestampPrecision 2：微秒精度 + 剩余时间不截断）

## 运行命令速查

```powershell
# Python 引擎
powershell -ExecutionPolicy Bypass -File scripts\run_engine.ps1

# 3D 完整办公室（阶段 2A WebSocket 快照驱动）
powershell -ExecutionPolicy Bypass -File scripts\run_3d_preview.ps1 -Scene full25

# 浏览器模拟台
# 打开 http://127.0.0.1:8000/sim/

# 生成 7 张验收截图（--capture 模式，用 MOCK_NICKNAMES）
powershell -ExecutionPolicy Bypass -File scripts\run_3d_preview.ps1 -Scene full25 -Capture

# pytest 契约测试
python -m pytest tests/ -v
```

## 关键技术参数

| 参数 | 值 | 位置 |
|---|---|---|
| 房间宽度 ROOM_W | 24.4m | `room_full_25.gd::ROOM_W` |
| 房间深度 FLOOR_D | 16.2m | `room_full_25.gd::FLOOR_D` |
| 工位间距 | 2.60m × 2.60m | `office_full_25.gd::GRID_X/GRID_Z` |
| 相机位置 | (0, 16.75, 20.85) | `office_full_25.gd::CAM_POS` |
| 相机目标 | (0, 1.80, -0.50) | `office_full_25.gd::CAM_TARGET` |
| 正交相机尺寸 | 14.1 | `office_full_25.gd::CAM_SIZE` |
| 渲染分辨率 | 1920×1080（16:9） | |
| VSync | 1（开启） | |
| MSAA | 4x | |
| 昵称名牌字体 | 19px | `office_full_25.gd::NICKNAME_FONT_SIZE` |
| 昵称名牌底框 | #C9A77D, alpha 0.58 | `_build_nickname_overlay()` |
| 昵称名牌边框 | #9A7955, alpha 0.55 | `_build_nickname_overlay()` |
| 昵称名牌文字 | #44382D, alpha 1.0 | `_build_nickname_overlay()` |
| 静态合并表面 | 85 | Godot 启动日志 |
| MockEventIn.repeat 上限 | 1000 | `routes_mock.py::MockEventIn` |
| WebSocket 协议版本 | 3 | `protocol.py::PROTOCOL_VERSION` |
| 入职点赞阈值 | 10 | `config.LIKE_ENTRY_THRESHOLD` |
| 入职关键词 | "入职" | `config.COMMENT_ENTRY_KEYWORD` |
| 空工位 | 25 | `config.SEAT_COUNT` |
