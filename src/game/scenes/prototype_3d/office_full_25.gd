extends Node3D
## 阶段 1.5 · 25 工位完整办公室预览（独立场景，不影响原 2D 主场景与 3 工位样板）。
##
## 5×5 工位布局 + 左侧玻璃老板办公室 / 主管工位 + 右侧扩大玻璃会议室；
## 25 名外观不同的员工（generate_appearance 1..25）全部循环趴桌睡觉。
## 摄像机改为正面偏俯视正交视角，水平朝向与办公室轴线对齐（无水平旋转）。
## 支持以下命令行参数（放在 -- 之后）：
##   --capture            输出完整截图与各区域截图后退出
##   --soak[=秒数]        连续运行压力测试（默认 300 秒），采样平均/最低 FPS、
##                         帧时间、draw calls 与三角面，写出 CSV / TXT 并截图

const RoomFull25 := preload("res://scenes/prototype_3d/room_full_25.gd")
const Workstation3D := preload("res://scenes/prototype_3d/workstation_3d.gd")
const Employee3D := preload("res://scenes/prototype_3d/employee_3d.gd")
const MeshKit := preload("res://scenes/prototype_3d/mesh_kit.gd")

# 5×5 工位网格：列距 / 排距均为 2.60（桌宽 1.90 + 0.70 横向净空），
# 为每个工位预留约 200px 的昵称名牌空间（1920 宽屏、正交尺寸 14.1 时）。
# 编号 01–25 仍按「从左到右、从后到前（画面从上到下）」排列。
# 2026-11-09 第二轮：整体下移 +0.80m，给老板办公室与主管工位之间腾出通道空间。
const GRID_X := [-5.20, -2.60, 0.0, 2.60, 5.20]
const GRID_Z := [-4.50, -1.90, 0.70, 3.30, 5.90]

# 正面偏俯视正交相机：无水平旋转，从办公室正前方抬升约 35° 俯视。
# CAM_SIZE 取 14.1 时，1920×1080 下水平可视约 25.07m，完整覆盖 24.4m 的房间。
const CAM_OFFSET := Vector3(0.0, 14.95, 21.35)
const CAM_TARGET := Vector3(0.0, 1.80, -0.5)
const CAM_SIZE := 14.1
const CAM_POS := CAM_TARGET + CAM_OFFSET

# ---- 观众昵称名牌（屏幕空间 UI，投影到 3D 工位头顶上方）----
const NICKNAME_FONT_SIZE := 19
const NICKNAME_HEIGHT := 34.0
const NICKNAME_GAP_PX := 8.0
# 名牌锚点：员工趴桌睡觉时头部上方（工位原点 + 该偏移）
const NICKNAME_HEAD := Vector3(0.0, 1.32, -0.02)
# 阶段 1.5 第二轮视觉测试用的 25 个模拟昵称（暂不接入真实抖音昵称）
## 昵称覆盖任务要求的全部类型：短（小明 / 小王 / 摸鱼达人）、
## 普通（今天不想上班 / 每天都想睡觉 / 我要一直摸鱼）、
## 长（今天也要努力摸鱼的打工人 / 上班只是为了下班和工资）、
## 中英混合（Moyu2026 / Hello小王 / HiMoyu_01），其余为同风格测试昵称。
const MOCK_NICKNAMES := [
	"小明", "小王", "摸鱼达人", "今天不想上班", "每天都想睡觉",
	"今天也要努力摸鱼的打工人", "Moyu2026", "Hello小王", "老板看不见我", "咖啡续命中",
	"打工人小张", "我要一直摸鱼", "摸鱼第一名", "睡到自然醒", "假装很忙",
	"今天的砖很烫", "加班是不可能加的", "划水大师", "上班只是为了下班和工资", "HiMoyu_01",
	"键盘侠小刘", "周一的怨念", "摸鱼中请勿打扰", "下班倒计时", "明天再说吧",
]

var _camera: Camera3D
var _hud: CanvasLayer
var _perf_panel: PanelContainer
var _perf_label: Label
var _ui_font: Font

# ---- 25 个昵称名牌（屏幕空间）----
var _name_layer: CanvasLayer
var _name_panels: Array = []
var _name_labels: Array = []
var _name_anchors: Array = []

var _capture := false
var _perf_warm := 0
var _perf_frames := 0
var _perf_time := 0.0
var _perf_done := false

# ---- 长跑压力测试（--soak）----
var _soak := false
var _soak_seconds := 300.0
var _soak_warmup := 15.0
var _soak_elapsed := 0.0
var _soak_run_time := 0.0
var _soak_frames := 0
var _soak_min_fps := INF
var _soak_max_frame_ms := 0.0
var _soak_frame_ms: Array = []
var _soak_rows: Array = []
var _soak_calls := 0
var _soak_tris := 0
var _soak_done := false
var _win_frames := 0
var _win_time := 0.0


func _ready() -> void:
	get_viewport().msaa_3d = Viewport.MSAA_4X
	var args := OS.get_cmdline_user_args()
	_capture = args.has("--capture")
	for a in args:
		if String(a).begins_with("--soak"):
			_soak = true
			var parts := String(a).split("=")
			if parts.size() > 1:
				_soak_seconds = maxf(30.0, float(parts[1]))
	_build_room()
	_build_workstations()
	# 房间与 25 套工位家具建完后，统一合并静态网格（员工动画组会被跳过）
	var static_surfaces := MeshKit.bake_static(self, "dynamic_3d")
	print("[3D-BATCH] static_surfaces=%d" % static_surfaces)
	_build_hud()
	_apply_camera()
	_build_nickname_overlay()

	if _soak:
		_run_soak.call_deferred()
	elif _capture:
		_run_capture.call_deferred()


func _process(delta: float) -> void:
	_update_nicknames()
	if _soak:
		if not _soak_done:
			_soak_update(delta)
		return
	if _perf_done:
		return
	_perf_warm += 1
	if _perf_warm <= 90:
		return
	_perf_frames += 1
	_perf_time += delta
	if _perf_frames >= 90:
		_perf_done = true
		_report_perf()


# ---------- 场景组装 ----------

func _build_room() -> void:
	add_child(RoomFull25.new())


func _build_workstations() -> void:
	for row in range(GRID_Z.size()):
		for col in range(GRID_X.size()):
			var idx := row * GRID_X.size() + col
			var station := Workstation3D.new()
			station.name = "Workstation%02d" % (idx + 1)
			station.seat_index = idx + 1
			station.variant = idx % 3
			station.appearance = Employee3D.generate_appearance(idx + 1)
			add_child(station)
			station.position = Vector3(GRID_X[col], 0.0, GRID_Z[row])


func _apply_camera() -> void:
	_camera = $Camera3D
	_camera.position = CAM_POS
	_camera.look_at(CAM_TARGET, Vector3.UP)
	_camera.size = CAM_SIZE
	_camera.far = 100.0


## 细节截图：保持同一俯视角，只改变目标点与正交尺寸（用于区域特写）。
func _set_view(target: Vector3, view_size: float) -> void:
	_camera.position = target + CAM_OFFSET
	_camera.look_at(target, Vector3.UP)
	_camera.size = view_size


func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 10
	add_child(_hud)

	_ui_font = SystemFont.new()
	_ui_font.font_names = PackedStringArray([
		"Microsoft YaHei UI", "Microsoft YaHei", "PingFang SC", "Noto Sans CJK SC",
	])

	var title := _make_badge(_ui_font, "HiMoyu · 轻 3D 办公室（阶段 1.5 · 第二轮布局修正）\n25 工位 · 老板室在上 / 主管工位在下 · 工位间距 2.60m · 昵称名牌预留", 20)
	title.position = Vector2(24, 20)
	_hud.add_child(title)

	_perf_panel = _make_badge(_ui_font, "性能采样中…", 20)
	_perf_panel.anchor_left = 1.0
	_perf_panel.anchor_right = 1.0
	_perf_panel.offset_left = -424
	_perf_panel.offset_right = -24
	_perf_panel.offset_top = 20
	_perf_panel.offset_bottom = 60
	_hud.add_child(_perf_panel)
	_perf_label = _perf_panel.get_child(0)

	var foot := _make_badge(_ui_font, "正面偏俯视正交相机 · 工位 01–25 · 25 个模拟昵称名牌 · 呼吸起伏 / 头部轻晃 / Zzz", 16)
	foot.anchor_top = 1.0
	foot.anchor_bottom = 1.0
	foot.offset_left = 24
	foot.offset_top = -58
	foot.offset_bottom = -18
	_hud.add_child(foot)


func _make_badge(font: Font, text: String, font_size: int) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 1.0, 1.0, 0.78)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("#34506a"))
	panel.add_child(label)
	return panel


# ---------- 观众昵称名牌（屏幕空间 CanvasLayer） ----------

## 25 个昵称名牌：使用屏幕空间 Control 面板，每帧把工位头顶锚点投影成屏幕坐标。
## 相比 3D Label3D，屏幕空间文字在 1920×1080 直播画面里始终是 19px 实际像素，
## 不会因为距离 / 正交缩放而发虚；名牌宽度随相机推近自动放宽（局部特写可显示完整长昵称）。
func _build_nickname_overlay() -> void:
	_name_layer = CanvasLayer.new()
	_name_layer.name = "NicknameLayer"
	_name_layer.layer = 5
	add_child(_name_layer)

	for i in range(MOCK_NICKNAMES.size()):
		var panel := PanelContainer.new()
		panel.name = "Nickname%02d" % (i + 1)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.custom_minimum_size = Vector2(0, NICKNAME_HEIGHT)

		var style := StyleBoxFlat.new()
		# 暖木色半透明底框（#C9A77D ≈ rgb(201,167,125)，透明度 58%），
		# 明显区别于纯白色，与办公室木地板形成暖色系列呼应
		style.bg_color = Color("#C9A77D", 0.58)
		# 深木色边框（#9A7955 ≈ rgb(154,121,85)，透明度 55%），更清晰的边框轮廓
		style.border_color = Color("#9A7955", 0.55)
		style.set_border_width_all(1)
		style.corner_radius_top_left = 10
		style.corner_radius_top_right = 10
		style.corner_radius_bottom_left = 10
		style.corner_radius_bottom_right = 10
		style.content_margin_left = 9
		style.content_margin_right = 9
		style.content_margin_top = 3
		style.content_margin_bottom = 3
		panel.add_theme_stylebox_override("panel", style)

		var label := Label.new()
		label.text = MOCK_NICKNAMES[i]
		label.add_theme_font_override("font", _ui_font)
		label.add_theme_font_size_override("font_size", NICKNAME_FONT_SIZE)
		# 暖棕色文字（#44382D），100% 不透明，保证在半透明底框上清晰可读
		label.add_theme_color_override("font_color", Color("#44382D"))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.clip_text = true
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(label)

		_name_layer.add_child(panel)
		_name_panels.append(panel)
		_name_labels.append(label)

		# 工位序号与 _build_workstations 一致：row * 5 + col（01–25 从左到右、从上到下）
		var idx := i
		var col := idx % GRID_X.size()
		var row := int(idx / GRID_X.size())
		_name_anchors.append(Vector3(GRID_X[col], 0.0, GRID_Z[row]) + NICKNAME_HEAD)

	_name_layer.visible = false


func _show_nicknames(on: bool) -> void:
	if _name_layer == null:
		return
	_name_layer.visible = on
	if on:
		_update_nicknames()
		await get_tree().process_frame
		_update_nicknames()
		await get_tree().process_frame


func _update_nicknames() -> void:
	if _name_layer == null or not _name_layer.visible or _camera == null:
		return
	var px_per_m := get_viewport().get_visible_rect().size.y / maxf(0.001, _camera.size)
	# 相邻工位在屏幕上的横向间距（列距 2.60m），名牌宽度留 20px 安全间隙
	var panel_w := clampf((GRID_X[1] - GRID_X[0]) * px_per_m - 20.0, 160.0, 300.0)
	for i in range(_name_panels.size()):
		var panel: PanelContainer = _name_panels[i]
		var head_px := _camera.unproject_position(_name_anchors[i])
		panel.size = Vector2(panel_w, NICKNAME_HEIGHT)
		panel.position = Vector2(head_px.x - panel_w * 0.5, head_px.y - NICKNAME_GAP_PX - NICKNAME_HEIGHT)
		panel.visible = true


## 记录名牌布局自检结果：两两不重叠、与工位号牌不重叠。
func _log_nickname_layout(tag: String) -> void:
	if _name_panels.is_empty():
		return
	var overlaps := 0
	var min_gap := INF
	var min_gap_to_number := INF
	var panel_size := Vector2.ZERO
	for i in range(_name_panels.size()):
		var p: PanelContainer = _name_panels[i]
		panel_size = p.size
		var rect_i := Rect2(p.position, p.size)
		for j in range(i + 1, _name_panels.size()):
			var q: PanelContainer = _name_panels[j]
			var rect_j := Rect2(q.position, q.size)
			if rect_i.intersects(rect_j):
				overlaps += 1
			if absf(rect_i.get_center().y - rect_j.get_center().y) < 6.0:
				min_gap = minf(min_gap, absf(rect_i.get_center().x - rect_j.get_center().x) - (rect_i.size.x + rect_j.size.x) * 0.5)
		# 工位号牌顶端中心 = 工位原点 + (0, 0.95, 0.40)，要求名牌底边始终高于号牌顶边
		var number_px := _camera.unproject_position(_name_anchors[i] - NICKNAME_HEAD + Vector3(0.0, 0.95, 0.40))
		min_gap_to_number = minf(min_gap_to_number, number_px.y - (rect_i.position.y + rect_i.size.y))
	print("[3D-NAMES] %s panels=%d panel=%.0fx%.0f overlaps=%d min_h_gap=%.1fpx gap_to_number=%.1fpx" % [
		tag, _name_panels.size(), panel_size.x, panel_size.y, overlaps, min_gap, min_gap_to_number,
	])


# ---------- 性能采样 ----------

func _report_perf() -> void:
	var fps := float(_perf_frames) / _perf_time
	var calls := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var prims := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	_perf_label.text = "%.0f FPS · %d draw calls · %.1fK tris" % [fps, calls, prims / 1000.0]
	print("[3D-PERF] fps=%.1f draw_calls=%d primitives=%d" % [fps, calls, prims])


# ---------- 截图辅助（仅 --capture 模式调用） ----------

func _run_capture() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	DisplayServer.window_set_position(Vector2i(0, 0))
	# 等短时性能采样完成，确认场景稳定后再截图
	while not _perf_done:
		await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout

	var dir := _screenshot_dir()
	DirAccess.make_dir_recursive_absolute(dir)
	# 正式验收截图不叠加 HUD，保持画面干净
	_hud.visible = false

	# 1) 全景：25 个昵称名牌全部显示（阶段 1.5 第二轮验收主图）
	_set_view(CAM_TARGET, CAM_SIZE)
	await _show_nicknames(true)
	await _save_shot(dir, "office_full.png")
	_log_nickname_layout("full_view")

	# 2) 管理层区域同框：左上老板玻璃办公室 + 左下主管独立工位（两者已分离）
	await _show_nicknames(false)
	_set_view(Vector3(-10.30, 1.20, -1.20), 12.0)
	await _save_shot(dir, "management_area.png")

	# 3) 老板玻璃办公室特写
	_set_view(Vector3(-10.30, 1.70, -6.40), 4.4)
	await _save_shot(dir, "boss_office.png")

	# 4) 主管工位特写（独立于老板办公室，位于画面左下区域）
	_set_view(Vector3(-10.30, 0.62, 4.50), 4.2)
	await _save_shot(dir, "supervisor_station.png")

	# 5) 会议室（书柜正面朝主摄像机）
	_set_view(Vector3(9.55, 1.45, -3.90), 7.8)
	await _save_shot(dir, "meeting_room_bookcase.png")

	# 6) 25 工位与工位号（显示昵称）
	_set_view(Vector3(0.0, 1.45, -0.05), 11.6)
	await _show_nicknames(true)
	await _save_shot(dir, "office_25_seats.png")
	_log_nickname_layout("25_seats")

	# 7) 昵称可读性特写：相机推近后名牌自动放宽，长昵称完整显示
	_set_view(Vector3(0.0, 1.60, 0.20), 8.0)
	await _show_nicknames(true)
	await _save_shot(dir, "employee_nameplates.png")
	_log_nickname_layout("nameplates_close")

	get_tree().quit(0)


func _save_shot(dir: String, filename: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(dir.path_join(filename))
	print("[3D-CAPTURE] %s size=%s err=%d" % [filename, str(img.get_size()), err])


# ---------- 长跑压力测试 ----------

func _run_soak() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	DisplayServer.window_set_position(Vector2i(0, 0))
	await get_tree().process_frame
	await get_tree().process_frame
	# 性能测试包含 25 个昵称名牌同时显示（直播画面的目标状态）
	await _show_nicknames(true)
	print("[3D-SOAK] start godot=%s renderer=%s adapter=%s api=%s" % [
		Engine.get_version_info()["string"],
		ProjectSettings.get_setting("rendering/renderer/rendering_method"),
		RenderingServer.get_video_adapter_name(),
		RenderingServer.get_video_adapter_api_version(),
	])
	print("[3D-SOAK] window=%s vsync=%d msaa=%s employees=25 grid=5x5 spacing=2.60/2.60 nicknames=25 warmup=%.0fs soak=%.0fs" % [
		str(get_viewport().get_visible_rect().size),
		DisplayServer.window_get_vsync_mode(),
		"4x",
		_soak_warmup,
		_soak_seconds,
	])
	_count_scene_nodes()


func _soak_update(delta: float) -> void:
	_soak_elapsed += delta
	if _soak_elapsed < _soak_warmup:
		return
	_soak_run_time += delta
	_soak_frames += 1
	var ms := delta * 1000.0
	_soak_frame_ms.append(ms)
	_soak_max_frame_ms = maxf(_soak_max_frame_ms, ms)
	_win_frames += 1
	_win_time += delta
	if _win_time >= 1.0:
		var fps := float(_win_frames) / _win_time
		_soak_min_fps = minf(_soak_min_fps, fps)
		_soak_calls = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		_soak_tris = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
		_soak_rows.append({
			"t": _soak_elapsed - _soak_warmup,
			"fps": fps,
			"frame_ms": _win_time * 1000.0 / float(_win_frames),
			"calls": _soak_calls,
			"tris": _soak_tris,
		})
		_win_frames = 0
		_win_time = 0.0
	if _soak_run_time >= _soak_seconds:
		_soak_done = true
		_finish_soak.call_deferred()


func _finish_soak() -> void:
	var sorted := _soak_frame_ms.duplicate()
	sorted.sort()
	var avg_ms := 0.0
	for v in _soak_frame_ms:
		avg_ms += float(v)
	avg_ms /= maxf(1.0, float(_soak_frame_ms.size()))
	var p95_ms := _percentile(sorted, 0.95)
	var avg_fps := float(_soak_frames) / maxf(0.001, _soak_run_time)
	var calls_sum := 0
	var tris_sum := 0
	for row in _soak_rows:
		calls_sum += int(row["calls"])
		tris_sum += int(row["tris"])
	var rows := maxf(1.0, float(_soak_rows.size()))
	var avg_calls := int(round(float(calls_sum) / rows))
	var avg_tris := int(round(float(tris_sum) / rows))

	var lines := [
		"HiMoyu 3D 压力测试（25 员工同屏）",
		"Godot: %s | Renderer: %s" % [Engine.get_version_info()["string"], ProjectSettings.get_setting("rendering/renderer/rendering_method")],
		"GPU: %s | API: %s" % [RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_api_version()],
		"Window: %s | VSync: %d | MSAA: 4x" % [str(get_viewport().get_visible_rect().size), DisplayServer.window_get_vsync_mode()],
		"Warmup: %.0f s | Soak: %.0f s | Sampled frames: %d" % [_soak_warmup, _soak_seconds, _soak_frames],
		"Avg FPS: %.1f | Min (1s window) FPS: %.1f" % [avg_fps, _soak_min_fps],
		"Frame time avg: %.2f ms | max: %.2f ms | P95: %.2f ms" % [avg_ms, _soak_max_frame_ms, p95_ms],
		"Draw calls avg: %d | Primitives avg: %d" % [avg_calls, avg_tris],
	]
	for line in lines:
		print("[3D-SOAK] %s" % line)

	var dir := _screenshot_dir()
	DirAccess.make_dir_recursive_absolute(dir)
	var csv := FileAccess.open(dir.path_join("perf_soak.csv"), FileAccess.WRITE)
	csv.store_line("elapsed_s,fps,frame_ms,draw_calls,primitives")
	for row in _soak_rows:
		csv.store_line("%.1f,%.1f,%.2f,%d,%d" % [row["t"], row["fps"], row["frame_ms"], row["calls"], row["tris"]])
	csv.close()
	var txt := FileAccess.open(dir.path_join("perf_soak.txt"), FileAccess.WRITE)
	txt.store_string("\n".join(lines) + "\n")
	txt.close()

	_perf_panel.offset_left = -620
	_perf_panel.offset_right = -24
	_perf_panel.offset_top = 20
	_perf_panel.offset_bottom = 196
	_perf_label.add_theme_font_size_override("font_size", 19)
	_perf_label.text = "\n".join([
		"1920×1080 · VSync %d · MSAA 4x · 25 员工" % DisplayServer.window_get_vsync_mode(),
		"平均 %.1f FPS · 最低 %.1f FPS（1 秒窗口）" % [avg_fps, _soak_min_fps],
		"帧时间 %.2f ms · 最高 %.2f ms · P95 %.2f ms" % [avg_ms, _soak_max_frame_ms, p95_ms],
		"Draw Calls %d · 三角面 %.2fM" % [avg_calls, avg_tris / 1000000.0],
		"连续采样 %.0f 秒" % _soak_seconds,
	])
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(dir.path_join("performance_test.png"))
	print("[3D-CAPTURE] performance=%s size=%s err=%d" % [dir.path_join("performance_test.png"), str(img.get_size()), err])
	get_tree().quit(0)


func _percentile(sorted_values: Array, ratio: float) -> float:
	if sorted_values.is_empty():
		return 0.0
	var idx := clampi(int(round(float(sorted_values.size() - 1) * ratio)), 0, sorted_values.size() - 1)
	return float(sorted_values[idx])


func _count_scene_nodes() -> void:
	var stack: Array = [self]
	var nodes := 0
	var meshes := 0
	var labels := 0
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		nodes += 1
		if n is MeshInstance3D:
			meshes += 1
		elif n is Label3D:
			labels += 1
		for c in n.get_children():
			stack.append(c)
	print("[3D-SOAK] nodes=%d mesh_instances=%d label3d=%d" % [nodes, meshes, labels])


func _screenshot_dir() -> String:
	var project_dir := ProjectSettings.globalize_path("res://").trim_suffix("/")
	var workspace := project_dir.get_base_dir().get_base_dir()
	return workspace.path_join(".screenshots").path_join("prototype_3d")
