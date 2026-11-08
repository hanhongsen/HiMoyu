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

# 5×5 工位网格：列距 2.08（桌宽 1.90 + 缝隙），排距 1.95（桌面 + 椅子 + 走道）
const GRID_X := [-4.16, -2.08, 0.0, 2.08, 4.16]
const GRID_Z := [-4.90, -2.95, -1.00, 0.95, 2.90]

# 正面偏俯视正交相机：无水平旋转，从办公室正前方抬升约 35° 俯视。
# CAM_SIZE 取 13.4 时，1920×1080 下水平可视约 23.8m，完整覆盖 22.4m 的房间。
const CAM_OFFSET := Vector3(0.0, 14.95, 21.35)
const CAM_TARGET := Vector3(0.0, 1.80, -1.0)
const CAM_SIZE := 13.4
const CAM_POS := CAM_TARGET + CAM_OFFSET

var _camera: Camera3D
var _hud: CanvasLayer
var _perf_panel: PanelContainer
var _perf_label: Label

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

	if _soak:
		_run_soak.call_deferred()
	elif _capture:
		_run_capture.call_deferred()


func _process(delta: float) -> void:
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

	var font := SystemFont.new()
	font.font_names = PackedStringArray([
		"Microsoft YaHei UI", "Microsoft YaHei", "PingFang SC", "Noto Sans CJK SC",
	])

	var title := _make_badge(font, "HiMoyu · 轻 3D 办公室（阶段 1.5 · 正面偏俯视）\n25 工位 · 老板玻璃办公室 / 主管工位 / 扩大会议室 · 全员趴桌睡觉", 20)
	title.position = Vector2(24, 20)
	_hud.add_child(title)

	_perf_panel = _make_badge(font, "性能采样中…", 20)
	_perf_panel.anchor_left = 1.0
	_perf_panel.anchor_right = 1.0
	_perf_panel.offset_left = -424
	_perf_panel.offset_right = -24
	_perf_panel.offset_top = 20
	_perf_panel.offset_bottom = 60
	_hud.add_child(_perf_panel)
	_perf_label = _perf_panel.get_child(0)

	var foot := _make_badge(font, "正面偏俯视正交相机 · 工位 01–25 · 呼吸起伏 / 头部轻晃 / Zzz 飘散", 16)
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

	_set_view(CAM_TARGET, CAM_SIZE)
	await _save_shot(dir, "office_front_view.png")

	_set_view(Vector3(-9.55, 1.66, -5.70), 4.2)
	await _save_shot(dir, "boss_office.png")

	_set_view(Vector3(-6.70, 0.56, -3.00), 3.4)
	await _save_shot(dir, "supervisor_station.png")

	_set_view(Vector3(8.48, 1.30, -3.70), 7.6)
	await _save_shot(dir, "meeting_room.png")

	_set_view(Vector3(0.0, 0.68, -1.00), 6.6)
	await _save_shot(dir, "office_25_seats.png")

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
	print("[3D-SOAK] start godot=%s renderer=%s adapter=%s api=%s" % [
		Engine.get_version_info()["string"],
		ProjectSettings.get_setting("rendering/renderer/rendering_method"),
		RenderingServer.get_video_adapter_name(),
		RenderingServer.get_video_adapter_api_version(),
	])
	print("[3D-SOAK] window=%s vsync=%d msaa=%s employees=25 grid=5x5 warmup=%.0fs soak=%.0fs" % [
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
