extends Node3D
## 阶段 1 视觉升级 · 25 工位完整办公室预览（独立场景，不影响原 2D 主场景与 3 工位样板）。
##
## 5×5 工位布局 + 左侧管理区 + 右侧玻璃会议室；
## 25 名外观不同的员工（generate_appearance 1..25）全部循环趴桌睡觉。
## 支持 --capture 参数：先采样性能（FPS / draw calls / 三角形数），再输出完整截图后退出。

const RoomFull25 := preload("res://scenes/prototype_3d/room_full_25.gd")
const Workstation3D := preload("res://scenes/prototype_3d/workstation_3d.gd")
const Employee3D := preload("res://scenes/prototype_3d/employee_3d.gd")

# 5×5 工位网格：列距 2.08（桌宽 1.90 + 缝隙），排距 1.90（桌面 + 椅子 + 走道）
const GRID_X := [-4.16, -2.08, 0.0, 2.08, 4.16]
const GRID_Z := [-4.40, -2.50, -0.60, 1.30, 3.20]

const CAM_POS := Vector3(5.6, 11.0, 10.2)
const CAM_TARGET := Vector3(0.0, 0.45, -1.35)
const CAM_SIZE := 12.3

var _camera: Camera3D
var _hud: CanvasLayer
var _perf_label: Label

var _capture := false
var _perf_warm := 0
var _perf_frames := 0
var _perf_time := 0.0
var _perf_done := false


func _ready() -> void:
	get_viewport().msaa_3d = Viewport.MSAA_4X
	_capture = OS.get_cmdline_user_args().has("--capture")
	_build_room()
	_build_workstations()
	_build_hud()
	_apply_camera()

	if _capture:
		_run_capture.call_deferred()


func _process(delta: float) -> void:
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


func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 10
	add_child(_hud)

	var font := SystemFont.new()
	font.font_names = PackedStringArray([
		"Microsoft YaHei UI", "Microsoft YaHei", "PingFang SC", "Noto Sans CJK SC",
	])

	var title := _make_badge(font, "HiMoyu · 轻 3D 办公室（25 工位布局预览）\n5×5 工位 · 全员趴桌睡觉 · 管理区 / 会议室 · 正交俯视", 20)
	title.position = Vector2(24, 20)
	_hud.add_child(title)

	var perf := _make_badge(font, "性能采样中…", 20)
	perf.anchor_left = 1.0
	perf.anchor_right = 1.0
	perf.offset_left = -424
	perf.offset_right = -24
	perf.offset_top = 20
	perf.offset_bottom = 60
	_hud.add_child(perf)
	_perf_label = perf.get_child(0)

	var foot := _make_badge(font, "趴桌睡姿 · 呼吸起伏 / 头部轻晃 / Zzz 飘散", 16)
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
	DisplayServer.window_set_size(Vector2i(1600, 900))
	# 等性能采样完成，角标显示真实数据后再截图
	while not _perf_done:
		await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw

	var dir := _screenshot_dir()
	DirAccess.make_dir_recursive_absolute(dir)
	var full_path := dir.path_join("office_25_full.png")
	var err := get_viewport().get_texture().get_image().save_png(full_path)
	print("[3D-CAPTURE] full=%s err=%d" % [full_path, err])
	get_tree().quit(0)


func _screenshot_dir() -> String:
	var project_dir := ProjectSettings.globalize_path("res://").trim_suffix("/")
	var workspace := project_dir.get_base_dir().get_base_dir()
	return workspace.path_join(".screenshots").path_join("prototype_3d")
