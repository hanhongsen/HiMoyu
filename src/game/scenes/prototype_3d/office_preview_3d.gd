extends Node3D
## 阶段 1 视觉升级 · 轻 3D 工位样板（独立预览场景，不影响原 2D 主场景）。
##
## 组装顺序：房间 → 3 个工位 → 员工 → 摄像机 / UI。
## 支持 --capture 参数：自动输出全景截图与人物局部截图后退出。

const Room3D := preload("res://scenes/prototype_3d/room_3d.gd")
const Workstation3D := preload("res://scenes/prototype_3d/workstation_3d.gd")
const Employee3D := preload("res://scenes/prototype_3d/employee_3d.gd")

const DESK_X := [-2.08, 0.0, 2.08]

# 全景镜头：轻微等距的斜上方视角，正交投影保证 3 工位透视不畸变
const CAMERA_POS := Vector3(3.25, 4.95, 5.25)
const CAMERA_TARGET := Vector3(0.0, 1.62, -0.30)
const CAMERA_SIZE := 4.60

# 人物局部镜头
const CLOSE_POS := Vector3(0.98, 1.98, 1.68)
const CLOSE_TARGET := Vector3(0.0, 1.00, 0.03)
const CLOSE_SIZE := 1.58

@onready var _camera: Camera3D = $Camera3D
@onready var _hud: CanvasLayer = $HUD

var _workstations: Array = []


func _ready() -> void:
	get_viewport().msaa_3d = Viewport.MSAA_4X
	_build_room()
	_build_workstations()
	_build_hud()
	_apply_full_camera()

	if OS.get_cmdline_user_args().has("--capture"):
		_run_capture.call_deferred()


func _build_room() -> void:
	var room := Room3D.new()
	room.name = "Room3D"
	add_child(room)


func _build_workstations() -> void:
	for i in range(DESK_X.size()):
		var station := Workstation3D.new()
		station.name = "Workstation%02d" % (i + 1)
		station.seat_index = i + 1
		station.variant = i
		station.appearance = Employee3D.preview_preset(i)
		add_child(station)
		station.position = Vector3(DESK_X[i], 0.0, 0.0)
		_workstations.append(station)


func _build_hud() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray([
		"Microsoft YaHei UI",
		"Microsoft YaHei",
		"PingFang SC",
		"Noto Sans CJK SC",
		"SimHei",
	])

	# 左上标题卡
	_add_card(Vector2(34, 28), Vector2(486, 92))
	var title := _make_label("HiMoyu · 轻 3D 工位样板", 30, Color("#2f4a5e"), Vector2(60, 40), font)
	_hud.add_child(title)
	var subtitle := _make_label("3 工位 · 睡觉循环 · 正交视角", 18, Color("#7c8b96"), Vector2(62, 82), font)
	_hud.add_child(subtitle)

	# 右上模式徽标
	_add_card(Vector2(1920 - 350, 28), Vector2(316, 56))
	var mode := _make_label("Stylized 3D · Prototype", 19, Color("#4f6b7d"), Vector2(1920 - 322, 44), font)
	_hud.add_child(mode)

	# 左下说明条
	_add_card(Vector2(34, 1080 - 84), Vector2(620, 52))
	var tip := _make_label("趴桌睡姿 · 呼吸起伏 / 头部轻晃 / Zzz 飘散", 19, Color("#596b78"), Vector2(60, 1080 - 74), font)
	_hud.add_child(tip)


func _add_card(pos: Vector2, size: Vector2) -> void:
	var panel := Panel.new()
	panel.position = pos
	panel.size = size
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#fffaf0e8")
	style.set_corner_radius_all(18)
	style.set_border_width_all(1)
	style.border_color = Color("#e6d9c4")
	style.shadow_color = Color(0.30, 0.24, 0.16, 0.12)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 4)
	panel.add_theme_stylebox_override("panel", style)
	_hud.add_child(panel)


func _make_label(text: String, font_size: int, color: Color, pos: Vector2, font: Font) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _apply_full_camera() -> void:
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = CAMERA_SIZE
	_camera.far = 60.0
	_camera.position = CAMERA_POS
	_camera.look_at(CAMERA_TARGET, Vector3.UP)


func _apply_closeup_camera() -> void:
	_camera.size = CLOSE_SIZE
	_camera.position = CLOSE_POS
	_camera.look_at(CLOSE_TARGET, Vector3.UP)


# ---------- 截图辅助（仅 --capture 模式调用） ----------

func _run_capture() -> void:
	DisplayServer.window_set_size(Vector2i(1600, 900))
	await get_tree().create_timer(0.9).timeout
	await RenderingServer.frame_post_draw

	var dir := _screenshot_dir()
	DirAccess.make_dir_recursive_absolute(dir)

	var full_path := dir.path_join("prototype_3d_full.png")
	var full_image := get_viewport().get_texture().get_image()
	var full_err := full_image.save_png(full_path)
	print("[3D-CAPTURE] full=%s err=%d" % [full_path, full_err])

	_hud.visible = false
	_apply_closeup_camera()
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw

	var close_path := dir.path_join("prototype_3d_closeup.png")
	var close_image := get_viewport().get_texture().get_image()
	var close_err := close_image.save_png(close_path)
	print("[3D-CAPTURE] closeup=%s err=%d" % [close_path, close_err])

	get_tree().quit(0)


func _screenshot_dir() -> String:
	var project_dir := ProjectSettings.globalize_path("res://").trim_suffix("/")
	var workspace := project_dir.get_base_dir().get_base_dir()
	return workspace.path_join(".screenshots").path_join("prototype_3d")
