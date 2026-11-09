# HiMoyu · 开发状态总览

> 本文档用于不同 AI 编程工具之间同步项目进度。每次完成开发任务后必须更新。

## 当前阶段

**阶段 1.5 · 最终布局确认（已完成，等待用户验收）**

- 最新 Git 提交：`6054586`（2026-11-09 · fix: refine management spacing and employee nameplate style）+ 本轮追加修正待提交
- 远程分支：`main`（`https://github.com/hanhongsen/HiMoyu`）
- 本地工作目录：`D:\HiMoyu`
- Godot 路径：`D:\Godot_v4.7.2-stable_win64.exe`

## 已完成模块

| # | 模块 | 文件路径 | 完成日期 | 备注 |
|---|---|---|---|---|
| 1 | Python 规则引擎 + FastAPI | `src/engine/app/` | 阶段 0 | 9 项 pytest 契约测试通过 |
| 2 | WebSocket 快照协议 | `src/engine/app/realtime/hub.py` | 阶段 0 | Godot 客户端使用 |
| 3 | 浏览器模拟控制台 | `src/engine/simulator/` | 阶段 0 | 本地开发用 |
| 4 | 2D 办公室主场景 | `src/game/main.tscn` + `scenes/office/` + `scenes/characters/` | 阶段 1 | 默认启动入口，未修改 |
| 5 | 3 工位 3D 样板间 | `src/game/scenes/prototype_3d/office_preview_3d.tscn` | 阶段 1.5 视觉原型 | |
| 6 | 25 工位 3D 完整场景 | `src/game/scenes/prototype_3d/office_full_25.tscn` + `room_full_25.gd` | 阶段 1.5 | 正面偏俯视正交相机 |
| 7 | 3D 人物建模与睡觉动画 | `src/game/scenes/prototype_3d/employee_3d.gd` | 阶段 1.5 | 25 种外观，呼吸+头部轻晃+Zzz |
| 8 | 静态网格合并优化 | `src/game/scenes/prototype_3d/mesh_kit.gd` → `bake_static()` | 阶段 1.5 | 按材质 + 阴影分组合并，85 个合并表面 |
| 9 | 老板玻璃办公室 | `room_full_25.gd::_build_boss_office()` | 阶段 1.5 最终 | 位置：x∈[-11.80,-8.80], z∈[-8.52,-5.22]（画面左上） |
| 10 | 主管独立工位 | `room_full_25.gd::_build_supervisor_station()` | 阶段 1.5 最终 | 位置：x=-10.30, z=4.50（画面左下），与老板室分离 |
| 11 | 25 工位 5×5 布局 | `office_full_25.gd::GRID_X/GRID_Z` | 阶段 1.5 第二轮 | 间距 2.60m，编号 01-25（row*5+col+1） |
| 12 | 右侧扩大会议室 | `room_full_25.gd::_build_meeting_room()` | 阶段 1.5 第二轮 | 书柜 yaw=0° 正面朝镜头 |
| 13 | 昵称名牌系统 | `office_full_25.gd::_build_nickname_overlay()` | 阶段 1.5 最终 | 屏幕空间 CanvasLayer，暖木色底框 #C9A77D |
| 14 | 7 张验收截图流水线 | `office_full_25.gd::_run_capture()` | 阶段 1.5 第二轮 | --capture 命令自动生成 |
| 15 | 300 秒性能压力测试 | `office_full_25.gd::_run_soak()` | 阶段 1.5 第二轮 | --soak=300 命令 |

## 关键文件清单（只读/保护）

以下文件已通过前序验收，**后续迭代禁止修改**：

- `src/engine/app/` — Python 规则引擎全部文件
- `src/engine/app/api/ws.py` — WebSocket 协议
- `src/engine/app/domain/models.py` — 场次状态模型
- `src/game/main.gd` + `main.tscn` — 2D 主场景
- `src/game/scenes/office/` — 2D 办公室场景
- `src/game/scenes/characters/` — 2D 人物组件
- `src/game/net/ws_client.gd` — Godot WebSocket 客户端
- `src/game/config/seat_layout.gd` — 2D 工位布局常量

## 最近修改文件（本轮）

| 文件 | 修改说明 |
|---|---|
| `src/game/scenes/prototype_3d/room_full_25.gd` | 主管工位 z=-3.10 → 4.50（移到左下区域）；左下角落绿植移至左上；主管旁绿植跟随新位置 |
| `src/game/scenes/prototype_3d/office_full_25.gd` | 昵称名牌底框 #E8D9C2→#C9A77D(58%透明)，边框 #B69A76→#9A7955(55%透明)；management_area 视角更新；supervisor_station 视角更新 |

## 约束与硬限制

- 不修改 Python 规则引擎、WebSocket 协议、2D 主场景
- 不修改 25 工位编号规则（01-25，从左到右从上到下，与 SeatState.index 映射）
- 不修改静态网格合并优化（`MeshKit.bake_static`）
- 不使用 force push，不删除之前的截图和开发记录
- 不接入抖音 API，不开发礼物/排行榜/入职/集体事件等阶段 2 功能
- 所有外部素材必须有授权；3D 内容全部程序化生成
- 不修改 `project.godot` 默认主场景（保持 2D）

## 下一步待办（等待用户验收后）

1. **阶段 1.5 最终验收**：用户检查截图、确认布局和名牌样式
2. **阶段 2 抖音接入**（验收通过后启动）：
   - 抖音开放平台申请（需产品方案确认）
   - 真实昵称替换模拟昵称
   - 事件流接入（点赞/评论/礼物）
   - WebSocket 事件映射
3. **3D 替换 2D 主场景**：在 25 工位稳定后，将 `office_full_25.tscn` 设为默认主场景

## 运行命令速查

```powershell
# Python 引擎
powershell -ExecutionPolicy Bypass -File scripts\run_engine.ps1

# 2D 客户端（默认）
powershell -ExecutionPolicy Bypass -File scripts\run_game.ps1

# 3D 完整办公室（阶段 1.5 最终布局）
powershell -ExecutionPolicy Bypass -File scripts\run_3d_preview.ps1 -Scene full25

# 生成 7 张验收截图
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
| MeshInstance3D | 553 | Godot 启动日志 |
| Label3D | 29 | Godot 启动日志 |
