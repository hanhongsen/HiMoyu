extends Node3D
## 25 工位完整办公室场景 · 阶段 1.5 第二轮空间修正。
##
## 布局（从左到右）：
##   左侧上方：玻璃老板办公室（独立玻璃盒 + 玻璃门）
##   左侧下方：主管独立工位（与老板办公室沿 X 轴上下对齐）
##   中间：5×5 共 25 个普通员工工位，列距 / 排距均拉开到 2.60m，
##         为未来抖音昵称名牌预留视觉空间（画面主体）
##   右侧：横向扩大的玻璃会议室（长桌 / 八把椅子 / 白板 / 投影幕 / 书柜 / 文件柜）
##
## 三个区域共用同一块浅木地板、暖白墙面与后墙采光窗，靠通道自然连接。
## 静态家具在 scene 层统一合并网格（见 mesh_kit.gd / office_full_25.gd），
## 本文件只负责空间与家具几何。

const MeshKit := preload("res://scenes/prototype_3d/mesh_kit.gd")

const ROOM_W := 24.4
const ROOM_TOP := 3.6
const WALL_Z := -8.7
const FLOOR_CENTER_Z := -0.6
const FLOOR_D := 16.2

# 左：老板玻璃办公室（管理区上方）
const BOSS_X_MIN := -11.80
const BOSS_X_MAX := -8.80
const BOSS_Z_BACK := -8.52
const BOSS_Z_FRONT := -5.22
const BOSS_GLASS_H := 2.55
const BOSS_CENTER_X := -10.30

# 左：主管工位（老板办公室正下方，共用同一条 X 轴）
const SUPERVISOR_X := -10.30

# 中：25 工位（5×5，列距与排距统一为 2.60m）
const GRID_X := [-5.20, -2.60, 0.0, 2.60, 5.20]
const GRID_Z := [-5.30, -2.70, -0.10, 2.50, 5.10]

# 右：玻璃会议室
const MEET_X_MIN := 7.05
const MEET_X_MAX := 12.05
const MEET_Z_BACK := -8.52
const MEET_Z_FRONT := 0.60
const MEET_GLASS_H := 2.50

var _mat: Dictionary = {}


func _ready() -> void:
	_make_materials()
	_build_floor()
	_build_wall()
	_build_boss_office()
	_build_supervisor_station()
	_build_meeting_room()
	_build_plants()


func _make_materials() -> void:
	_mat["floor_main"] = MeshKit.material(Color("#e9d5b6"), 0.74)
	_mat["floor_seam"] = MeshKit.material(Color("#b08f6a"), 0.86)
	_mat["wall"] = MeshKit.material(Color("#f6efe2"), 0.88)
	_mat["wall_trim"] = MeshKit.material(Color("#e9deca"), 0.8)
	_mat["frame"] = MeshKit.material(Color("#faf6ec"), 0.55)
	_mat["glass"] = MeshKit.glass_material(Color("#bdd8e8"))
	_mat["pot"] = MeshKit.material(Color("#dbcab1"), 0.78)
	_mat["pot_dark"] = MeshKit.material(Color("#bfae95"), 0.8)
	_mat["soil"] = MeshKit.material(Color("#574133"), 0.95)
	_mat["leaf_a"] = MeshKit.material(Color("#5a9653"), 0.8)
	_mat["leaf_b"] = MeshKit.material(Color("#487f48"), 0.82)
	_mat["leaf_c"] = MeshKit.material(Color("#76ab5c"), 0.78)
	_mat["shelf"] = MeshKit.material(Color("#c39a6b"), 0.62)

	# 管理区 / 会议室
	_mat["mgr_wood"] = MeshKit.material(Color("#c49a6e"), 0.6)
	_mat["mgr_wood_dark"] = MeshKit.material(Color("#a67e54"), 0.66)
	_mat["boss_top"] = MeshKit.material(Color("#9c7047"), 0.48)
	_mat["boss_dark"] = MeshKit.material(Color("#75532f"), 0.55)
	_mat["boss_chair"] = MeshKit.material(Color("#3e3a3c"), 0.62)
	_mat["metal"] = MeshKit.material(Color("#565e68"), 0.35, 0.55)
	_mat["metal_dark"] = MeshKit.material(Color("#343941"), 0.42, 0.45)
	_mat["chair_dark"] = MeshKit.material(Color("#5d6a74"), 0.85)
	_mat["whiteboard"] = MeshKit.material(Color("#f2f7f9"), 0.32)
	_mat["whiteboard_frame"] = MeshKit.material(Color("#8b959d"), 0.45, 0.35)
	_mat["screen"] = MeshKit.material(Color("#2e4a64"), 0.30, 0.05, Color("#4f86b0"), 0.16)
	_mat["screen_ui"] = MeshKit.material(Color("#d7eaf6"), 0.4, 0.0, Color("#dff2ff"), 0.28)
	_mat["plastic"] = MeshKit.material(Color("#2f343c"), 0.55)
	_mat["paper"] = MeshKit.material(Color("#f4ecd9"), 0.85)
	_mat["rug"] = MeshKit.material(Color("#9fb3bd"), 0.95)
	_mat["rug_supervisor"] = MeshKit.material(Color("#b7c9c2"), 0.95)
	_mat["rug_boss"] = MeshKit.material(Color("#b8a891"), 0.95)
	_mat["gold"] = MeshKit.material(Color("#c9a35c"), 0.42, 0.25)

	# 玻璃隔断：真实半透材质；合并网格后仍保留透明属性
	var glass_wall := StandardMaterial3D.new()
	glass_wall.albedo_color = Color(0.84, 0.92, 0.97, 0.20)
	glass_wall.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_wall.roughness = 0.10
	glass_wall.metallic = 0.06
	glass_wall.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat["glass_wall"] = glass_wall
	_mat["glass_frame"] = MeshKit.material(Color("#9aa4ab"), 0.4, 0.5)


# ---------- 地面与墙 ----------

func _build_floor() -> void:
	var slab := MeshKit.lit(
		self,
		MeshKit.rounded_box(Vector3(ROOM_W + 0.4, 0.09, FLOOR_D), 0.22, 8, 20),
		Vector3(0, -0.045, FLOOR_CENTER_Z),
		_mat["floor_main"]
	)
	slab.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var plank_w := 0.612
	var seam_count := int(ROOM_W / plank_w)
	for i in range(1, seam_count):
		var x := -ROOM_W * 0.5 + plank_w * float(i)
		MeshKit.lit(
			self,
			MeshKit.rounded_box(Vector3(0.006, 0.0015, FLOOR_D - 0.1), 0.5, 3, 6),
			Vector3(x, 0.002, FLOOR_CENTER_Z),
			_mat["floor_seam"]
		)


func _build_wall() -> void:
	var wall := MeshKit.lit(
		self,
		MeshKit.rounded_box(Vector3(ROOM_W, ROOM_TOP, 0.18), 0.12, 8, 12),
		Vector3(0, ROOM_TOP * 0.5, WALL_Z),
		_mat["wall"]
	)
	wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	MeshKit.lit(
		self,
		MeshKit.rounded_box(Vector3(ROOM_W, 0.16, 0.05), 0.4),
		Vector3(0, 0.08, WALL_Z + 0.10),
		_mat["wall_trim"]
	)
	MeshKit.lit(
		self,
		MeshKit.rounded_box(Vector3(ROOM_W, 0.10, 0.08), 0.3),
		Vector3(0, ROOM_TOP - 0.05, WALL_Z + 0.09),
		_mat["wall_trim"]
	)

	# 后墙采光窗集中在中央员工区；左侧老板室与右侧会议室各有自己的玻璃/白板
	for x in [-6.9, -4.6, -2.3, 0.0, 2.3, 4.6]:
		_build_window(x)


func _build_window(x: float) -> void:
	var w := 1.90
	var h := 1.62
	var y := 2.02
	var z := WALL_Z + 0.115

	var glass := MeshKit.lit(
		self,
		MeshKit.rounded_box(Vector3(w - 0.10, h - 0.10, 0.02), 0.15),
		Vector3(x, y, z - 0.015),
		_mat["glass"]
	)
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	MeshKit.lit(self, MeshKit.rounded_box(Vector3(w, 0.072, 0.055), 0.4), Vector3(x, y + h * 0.5, z), _mat["frame"])
	MeshKit.lit(self, MeshKit.rounded_box(Vector3(w, 0.072, 0.055), 0.4), Vector3(x, y - h * 0.5, z), _mat["frame"])
	MeshKit.lit(self, MeshKit.rounded_box(Vector3(0.072, h, 0.055), 0.4), Vector3(x - w * 0.5, y, z), _mat["frame"])
	MeshKit.lit(self, MeshKit.rounded_box(Vector3(0.072, h, 0.055), 0.4), Vector3(x + w * 0.5, y, z), _mat["frame"])
	MeshKit.lit(self, MeshKit.rounded_box(Vector3(0.040, h - 0.07, 0.045), 0.4), Vector3(x, y, z + 0.004), _mat["frame"])
	MeshKit.lit(self, MeshKit.rounded_box(Vector3(w - 0.07, 0.040, 0.045), 0.4), Vector3(x, y + 0.42, z + 0.004), _mat["frame"])
	MeshKit.lit(
		self,
		MeshKit.rounded_box(Vector3(w + 0.14, 0.055, 0.16), 0.4),
		Vector3(x, y - h * 0.5 - 0.03, z + 0.03),
		_mat["wall_trim"]
	)
	MeshKit.lit(
		self,
		MeshKit.cylinder(0.016, 0.016, w + 0.30, 10),
		Vector3(x, y + h * 0.5 + 0.10, z + 0.055),
		_mat["shelf"],
		Vector3(0, 0, 90)
	)


# ---------- 左侧：老板玻璃办公室 ----------

func _build_boss_office() -> void:
	var root := Node3D.new()
	root.name = "BossOffice"
	add_child(root)

	var cx := BOSS_CENTER_X
	var h := BOSS_GLASS_H
	# 四面透明玻璃墙（背面紧贴后墙，左右与正面对镜头）
	_glass_panel_z(root, cx, BOSS_Z_BACK, BOSS_X_MAX - BOSS_X_MIN, h)
	_glass_panel_x(root, BOSS_X_MIN + 0.02, (BOSS_Z_BACK + BOSS_Z_FRONT) * 0.5, BOSS_Z_FRONT - BOSS_Z_BACK, h)
	_glass_panel_x(root, BOSS_X_MAX - 0.02, (BOSS_Z_BACK + BOSS_Z_FRONT) * 0.5, BOSS_Z_FRONT - BOSS_Z_BACK, h)
	# 正面两段等宽玻璃 + 中间 0.90m 玻璃门洞（门位于正中间）
	_glass_panel_z(root, BOSS_X_MIN + 0.525, BOSS_Z_FRONT, 1.05, h)
	_glass_panel_z(root, BOSS_X_MAX - 0.525, BOSS_Z_FRONT, 1.05, h)

	# 玻璃门（向室内微开，明确入口位置）
	var door := Node3D.new()
	door.name = "GlassDoor"
	door.position = Vector3(cx, 0, BOSS_Z_FRONT)
	door.rotation_degrees.y = 36.0
	root.add_child(door)
	_glass_panel_z(door, 0.43, 0.0, 0.86, h - 0.06)
	MeshKit.lit(door, MeshKit.cylinder(0.015, 0.015, 0.24, 10), Vector3(0.80, 1.10, 0.055), _mat["metal"])

	# 玻璃门上方的小标识
	_add_sign(root, "BOSS OFFICE", Vector3(cx, 2.30, BOSS_Z_FRONT + 0.075), 64, 0.0030)

	# 地毯 + 老板办公桌
	var desk_z := -6.62
	MeshKit.lit(
		root,
		MeshKit.rounded_box(Vector3(2.55, 0.008, 1.95), 0.35, 4, 12),
		Vector3(cx, 0.006, desk_z - 0.05),
		_mat["rug_boss"]
	)
	var top := 0.76
	MeshKit.lit(root, MeshKit.rounded_box(Vector3(2.00, 0.085, 1.00), 0.26, 14, 30), Vector3(cx, top - 0.0425, desk_z), _mat["boss_top"])
	# 前挡板与深色金属桌腿
	MeshKit.lit(root, MeshKit.rounded_box(Vector3(1.92, 0.10, 0.045), 0.35), Vector3(cx, top - 0.115, desk_z + 0.47), _mat["boss_dark"])
	for xs in [-1.0, 1.0]:
		MeshKit.lit(root, MeshKit.rounded_box(Vector3(0.070, top - 0.08, 0.82), 0.25), Vector3(cx + 0.86 * xs, (top - 0.08) * 0.5, desk_z), _mat["boss_dark"])

	# 桌面：显示器 / 合上的笔记本 / 文件 / 咖啡 / 台灯
	_build_small_monitor(root, Vector3(cx + 0.35, top + 0.002, desk_z - 0.18), 10.0)
	MeshKit.lit(root, MeshKit.rounded_box(Vector3(0.36, 0.020, 0.25), 0.4), Vector3(cx - 0.43, top + 0.012, desk_z + 0.07), _mat["metal_dark"], Vector3(0, -8, 0))
	MeshKit.lit(root, MeshKit.rounded_box(Vector3(0.32, 0.010, 0.22), 0.45), Vector3(cx - 0.43, top + 0.027, desk_z + 0.07), _mat["paper"], Vector3(0, -8, 0))
	for i in range(3):
		MeshKit.lit(
			root,
			MeshKit.rounded_box(Vector3(0.26, 0.014, 0.175), 0.5),
			Vector3(cx + 0.57, top + 0.009 + i * 0.015, desk_z - 0.22),
			MeshKit.material([Color("#f4ecd9"), Color("#e8ddc8"), Color("#f4ecd9")][i], 0.9),
			Vector3(0, 6 - i * 5, 0)
		)
	MeshKit.lit(root, MeshKit.cylinder(0.046, 0.042, 0.095, 18), Vector3(cx + 0.63, top + 0.050, desk_z + 0.20), MeshKit.material(Color("#f2e6d0"), 0.45))
	MeshKit.lit(root, MeshKit.cylinder(0.020, 0.026, 0.30, 10), Vector3(cx - 0.83, top + 0.15, desk_z - 0.24), _mat["metal"], Vector3(0, 0, -18))
	MeshKit.lit(
		root,
		MeshKit.cylinder(0.085, 0.055, 0.10, 14),
		Vector3(cx - 0.78, top + 0.30, desk_z - 0.24),
		MeshKit.material(Color("#f7ead0"), 0.5, 0.0, Color("#ffe9b8"), 0.35),
		Vector3(0, 0, -18)
	)
	# 桌面铭牌
	MeshKit.lit(root, MeshKit.rounded_box(Vector3(0.34, 0.075, 0.022), 0.45), Vector3(cx, top + 0.045, desk_z + 0.42), _mat["gold"])
	_add_sign(root, "BOSS", Vector3(cx, top + 0.045, desk_z + 0.435), 56, 0.0011)

	# 老板椅（深色高背）
	_build_manager_chair(root, Vector3(cx, 0, desk_z - 0.55), 0.0, true)

	# 后墙书柜 + 角落绿植
	_build_bookshelf(root, Vector3(cx + 0.25, 0, BOSS_Z_BACK + 0.22), 1.70, 2.10, 0.0)
	_build_plant(root, Vector3(BOSS_X_MIN + 0.43, 0, -7.90), 0.72)


# ---------- 左侧：主管工位 ----------

func _build_supervisor_station() -> void:
	var root := Node3D.new()
	root.name = "SupervisorStation"
	# 阶段 1.5 最终布局：主管工位独立放置在画面左下角（负 X + 正 Z），
	# 与左上角的老板玻璃办公室（x∈[-11.8..-8.8], z∈[-8.52..-5.22]）形成明显的上下分离。
	# x=-10.30 继续靠左；z=4.50 靠近镜头 → 画面左下区域。
	# 与最后一排员工（z=5.90）间隔约 0.60m，独立空间清晰。
	root.position = Vector3(SUPERVISOR_X, 0, 4.50)
	add_child(root)

	var top := 0.75
	# 主管专属地毯：在全景画面里与普通工位形成明确的视觉区分
	MeshKit.lit(
		root,
		MeshKit.rounded_box(Vector3(2.70, 0.008, 1.80), 0.35, 4, 12),
		Vector3(0, 0.006, -0.10),
		_mat["rug_supervisor"]
	)
	# 办公桌（面朝 +Z，与普通工位同向，便于正面镜头识别）
	MeshKit.lit(root, MeshKit.rounded_box(Vector3(2.00, 0.080, 1.00), 0.28, 12, 28), Vector3(0, top - 0.040, 0), _mat["mgr_wood"])
	MeshKit.lit(root, MeshKit.rounded_box(Vector3(1.92, 0.105, 0.045), 0.35), Vector3(0, top - 0.112, 0.478), _mat["mgr_wood_dark"])
	for xs in [-1.0, 1.0]:
		for zs in [-1.0, 1.0]:
			MeshKit.lit(root, MeshKit.rounded_box(Vector3(0.085, top - 0.06, 0.085), 0.35), Vector3(0.86 * xs, (top - 0.06) * 0.5, 0.36 * zs), _mat["mgr_wood_dark"])
	# 左侧抽屉柜
	MeshKit.lit(root, MeshKit.rounded_box(Vector3(0.50, 0.56, 0.66), 0.32), Vector3(-0.54, 0.33, 0.06), _mat["mgr_wood_dark"])

	_build_small_monitor(root, Vector3(0.40, top + 0.002, -0.26), 6.0)
	# 文件架：两层开放式木架，放几份资料
	MeshKit.lit(root, MeshKit.rounded_box(Vector3(0.42, 0.030, 0.30), 0.3), Vector3(-0.60, top + 0.015, 0.10), _mat["mgr_wood_dark"])
	for i in range(2):
		MeshKit.lit(root, MeshKit.rounded_box(Vector3(0.40, 0.022, 0.28), 0.3), Vector3(-0.60, top + 0.075 + i * 0.085, 0.10), _mat["mgr_wood"])
		MeshKit.lit(root, MeshKit.rounded_box(Vector3(0.28, 0.070, 0.200), 0.45), Vector3(-0.60, top + 0.040 + i * 0.085, 0.10), _mat["paper"], Vector3(0, -4 + i * 8, 0))
	# 咖啡杯 + 笔筒
	MeshKit.lit(root, MeshKit.cylinder(0.047, 0.043, 0.095, 18), Vector3(0.72, top + 0.050, 0.24), MeshKit.material(Color("#a8cfae"), 0.45))
	MeshKit.lit(root, MeshKit.cylinder(0.040, 0.040, 0.004, 18), Vector3(0.72, top + 0.095, 0.24), MeshKit.material(Color("#6b4b33"), 0.8))
	MeshKit.lit(root, MeshKit.cylinder(0.042, 0.038, 0.10, 16), Vector3(-0.22, top + 0.052, 0.30), MeshKit.material(Color("#c7a07c"), 0.7))
	# 铭牌
	MeshKit.lit(root, MeshKit.rounded_box(Vector3(0.46, 0.070, 0.020), 0.4), Vector3(0, top + 0.042, 0.492), _mat["gold"])
	_add_sign(root, "SUPERVISOR", Vector3(0, top + 0.042, 0.506), 52, 0.0010)

	# 主管椅（灰色高背）
	_build_manager_chair(root, Vector3(0, 0, -0.62), 0.0, false)

	# 旁边绿植（放在主管工位右前方通道里，不遮挡桌面；z 跟随新主管位置）
	_build_plant(self, Vector3(-8.40, 0, 5.30), 0.60)


# ---------- 右侧：玻璃会议室 ----------

func _build_meeting_room() -> void:
	var root := Node3D.new()
	root.name = "MeetingRoom"
	add_child(root)

	var cx := (MEET_X_MIN + MEET_X_MAX) * 0.5   # 9.55
	var h := MEET_GLASS_H
	# 西侧玻璃隔断（与员工区隔开）+ 正面玻璃（西侧留玻璃门洞）
	_glass_panel_x(root, MEET_X_MIN + 0.02, (MEET_Z_BACK + MEET_Z_FRONT) * 0.5, MEET_Z_FRONT - MEET_Z_BACK, h)
	_glass_panel_z(root, MEET_X_MIN + 0.40, MEET_Z_FRONT, 0.80, h)
	_glass_panel_z(root, MEET_X_MAX - 1.65, MEET_Z_FRONT, 3.30, h)

	var door := Node3D.new()
	door.name = "MeetingDoor"
	door.position = Vector3(MEET_X_MIN + 1.25, 0, MEET_Z_FRONT)
	door.rotation_degrees.y = 30.0
	root.add_child(door)
	_glass_panel_z(door, 0.43, 0.0, 0.86, h - 0.06)
	MeshKit.lit(door, MeshKit.cylinder(0.015, 0.015, 0.24, 10), Vector3(0.80, 1.08, 0.055), _mat["metal"])

	_add_sign(root, "MEETING ROOM", Vector3(MEET_X_MIN + 1.25, 2.30, MEET_Z_FRONT + 0.075), 64, 0.0030)

	# 会议室地毯
	MeshKit.lit(root, MeshKit.rounded_box(Vector3(4.90, 0.008, 2.90), 0.35, 4, 12), Vector3(cx, 0.006, -3.70), _mat["rug"])

	# 会议长桌
	var top := 0.75
	MeshKit.lit(root, MeshKit.rounded_box(Vector3(3.40, 0.078, 1.15), 0.26, 14, 30), Vector3(cx, top - 0.039, -3.70), _mat["mgr_wood"])
	MeshKit.lit(root, MeshKit.rounded_box(Vector3(3.30, 0.075, 0.045), 0.35), Vector3(cx, top - 0.108, -3.155), _mat["mgr_wood_dark"])
	for xs in [-1.0, 1.0]:
		MeshKit.lit(root, MeshKit.rounded_box(Vector3(0.10, top - 0.07, 0.90), 0.3), Vector3(cx + 1.45 * xs, (top - 0.07) * 0.5, -3.70), _mat["mgr_wood_dark"])

	# 八把会议椅：两侧三把 + 两端各一把
	for i in range(3):
		var x := 8.55 + i * 1.00
		_build_meeting_chair(root, Vector3(x, 0, -4.62), 0.0)
		_build_meeting_chair(root, Vector3(x, 0, -2.78), 180.0)
	_build_meeting_chair(root, Vector3(7.55, 0, -3.70), 90.0)
	_build_meeting_chair(root, Vector3(11.55, 0, -3.70), -90.0)

	# 后墙白板 + 投影幕（贴墙安装，避开背面玻璃）
	_build_whiteboard(root, Vector3(8.25, 0, MEET_Z_BACK + 0.06), 2.05, 1.28)
	_build_projection_screen(root, Vector3(10.55, 0, MEET_Z_BACK + 0.06), 1.70, 1.32)

	# 书柜：改为独立摆放、正面（书脊一侧）朝向主摄像机（+Z），
	# 放在会议室右侧靠后位置，不与后墙玻璃、会议桌椅及入口冲突。
	_build_bookshelf(root, Vector3(11.30, 0, -6.60), 1.45, 2.00, 0.0)
	_build_file_cabinet(root, Vector3(11.70, 0, -2.05))

	# 会议室绿植
	_build_plant(root, Vector3(7.40, 0, -0.55), 0.72)
	_build_plant(root, Vector3(11.82, 0, -0.45), 0.64)


# ---------- 玻璃构件 ----------

## 法线朝 ±Z 的玻璃面板（正面 / 背面），带上下金属压条。
func _glass_panel_z(parent: Node3D, cx: float, z: float, width: float, h: float) -> void:
	var glass := MeshKit.lit(parent, MeshKit.rounded_box(Vector3(width, h, 0.035), 0.08, 6, 10), Vector3(cx, h * 0.5, z), _mat["glass_wall"])
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	MeshKit.lit(parent, MeshKit.rounded_box(Vector3(width + 0.05, 0.06, 0.075), 0.4), Vector3(cx, h + 0.03, z), _mat["glass_frame"])
	MeshKit.lit(parent, MeshKit.rounded_box(Vector3(width + 0.05, 0.04, 0.075), 0.4), Vector3(cx, 0.02, z), _mat["glass_frame"])


## 法线朝 ±X 的玻璃面板（侧面），带上下金属压条。
func _glass_panel_x(parent: Node3D, x: float, cz: float, depth: float, h: float) -> void:
	var glass := MeshKit.lit(parent, MeshKit.rounded_box(Vector3(0.035, h, depth), 0.08, 6, 10), Vector3(x, h * 0.5, cz), _mat["glass_wall"])
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	MeshKit.lit(parent, MeshKit.rounded_box(Vector3(0.075, 0.06, depth + 0.05), 0.4), Vector3(x, h + 0.03, cz), _mat["glass_frame"])
	MeshKit.lit(parent, MeshKit.rounded_box(Vector3(0.075, 0.04, depth + 0.05), 0.4), Vector3(x, 0.02, cz), _mat["glass_frame"])


# ---------- 家具构件 ----------

## 小型桌面显示器：屏幕朝 +Z（正面镜头可见 UI），可整体绕 Y 偏转。
func _build_small_monitor(parent: Node3D, base: Vector3, yaw: float) -> void:
	var pivot := Node3D.new()
	pivot.position = base
	pivot.rotation_degrees.y = yaw
	parent.add_child(pivot)
	MeshKit.lit(pivot, MeshKit.rounded_box(Vector3(0.26, 0.022, 0.18), 0.5), Vector3(0, 0.011, 0.03), _mat["plastic"])
	MeshKit.lit(pivot, MeshKit.cylinder(0.026, 0.033, 0.15, 14), Vector3(0, 0.090, 0.015), _mat["metal"])
	MeshKit.lit(pivot, MeshKit.rounded_box(Vector3(0.62, 0.39, 0.045), 0.30, 12, 24), Vector3(0, 0.285, 0), _mat["plastic"])
	MeshKit.lit(pivot, MeshKit.rounded_box(Vector3(0.565, 0.335, 0.012), 0.28), Vector3(0, 0.285, 0.028), _mat["screen"])
	MeshKit.lit(pivot, MeshKit.rounded_box(Vector3(0.500, 0.028, 0.004), 0.5), Vector3(0, 0.392, 0.036), _mat["screen_ui"])
	MeshKit.lit(
		pivot,
		MeshKit.rounded_box(Vector3(0.330, 0.170, 0.004), 0.30),
		Vector3(-0.085, 0.272, 0.036),
		MeshKit.material(Color("#4d7590"), 0.5, 0.0, Color("#6d9fbf"), 0.10)
	)
	for i in range(3):
		MeshKit.lit(
			pivot,
			MeshKit.rounded_box(Vector3(0.120, 0.010, 0.004), 0.5),
			Vector3(0.140, 0.330 - i * 0.030, 0.036),
			MeshKit.material(Color("#9fc2d8"), 0.5, 0.0, Color("#b5d8ea"), 0.10)
		)


func _build_manager_chair(parent: Node3D, pos: Vector3, yaw: float, leather: bool) -> void:
	var chair := Node3D.new()
	chair.position = pos
	chair.rotation_degrees.y = yaw
	parent.add_child(chair)
	var seat_mat: Material = _mat["boss_chair"] if leather else _mat["chair_dark"]
	var back_mat: Material = _mat["boss_chair"] if leather else _mat["chair_dark"]
	MeshKit.lit(chair, MeshKit.rounded_box(Vector3(0.56, 0.110, 0.52), 0.55), Vector3(0, 0.552, 0), seat_mat)
	MeshKit.lit(chair, MeshKit.rounded_box(Vector3(0.58, 0.70, 0.10), 0.5), Vector3(0, 0.98, -0.25), back_mat, Vector3(-7, 0, 0))
	# 扶手
	for side in [-1.0, 1.0]:
		MeshKit.lit(chair, MeshKit.rounded_box(Vector3(0.090, 0.050, 0.32), 0.55), Vector3(0.320 * side, 0.720, 0.03), _mat["metal_dark"])
		MeshKit.segment(chair, Vector3(0.320 * side, 0.560, 0.03), Vector3(0.320 * side, 0.705, 0.03), 0.026, _mat["metal"])
	# 气压杆 + 五星脚
	MeshKit.lit(chair, MeshKit.cylinder(0.045, 0.045, 0.29, 14), Vector3(0, 0.36, 0), _mat["metal"])
	for i in range(5):
		var a := TAU * float(i) / 5.0 + 0.32
		var end := Vector3(cos(a) * 0.265, 0.105, sin(a) * 0.265)
		MeshKit.segment(chair, Vector3(0, 0.155, 0), end, 0.026, _mat["metal"])
		MeshKit.lit(chair, MeshKit.cylinder(0.045, 0.045, 0.030, 14), end + Vector3(0, -0.035, 0), _mat["metal"], Vector3(0, 0, 90))


func _build_meeting_chair(parent: Node3D, pos: Vector3, yaw: float) -> void:
	var chair := Node3D.new()
	chair.position = pos
	chair.rotation_degrees.y = yaw
	parent.add_child(chair)
	MeshKit.lit(chair, MeshKit.rounded_box(Vector3(0.44, 0.064, 0.44), 0.5), Vector3(0, 0.452, 0), _mat["chair_dark"])
	MeshKit.lit(chair, MeshKit.rounded_box(Vector3(0.44, 0.50, 0.055), 0.5), Vector3(0, 0.765, -0.19), _mat["chair_dark"], Vector3(-6, 0, 0))
	for xs in [-1.0, 1.0]:
		for zs in [-1.0, 1.0]:
			MeshKit.lit(chair, MeshKit.cylinder(0.020, 0.020, 0.44, 10), Vector3(0.17 * xs, 0.22, 0.17 * zs), _mat["metal"])


## 木书柜：背板 + 侧板 + 三层书脊；yaw=0 时正面朝 +Z，yaw=-90 时正面朝 -X。
func _build_bookshelf(parent: Node3D, base: Vector3, width: float, height: float, yaw: float) -> void:
	var shelf := Node3D.new()
	shelf.position = base
	shelf.rotation_degrees.y = yaw
	parent.add_child(shelf)
	var depth := 0.34
	var half := width * 0.5
	MeshKit.lit(shelf, MeshKit.rounded_box(Vector3(width, height, 0.030), 0.2), Vector3(0, height * 0.5, -depth * 0.5 + 0.015), _mat["wall_trim"])
	for xs in [-1.0, 1.0]:
		MeshKit.lit(shelf, MeshKit.rounded_box(Vector3(0.045, height, depth), 0.3), Vector3(half * xs, height * 0.5, 0), _mat["shelf"])
	MeshKit.lit(shelf, MeshKit.rounded_box(Vector3(width, 0.048, depth), 0.3), Vector3(0, height - 0.024, 0), _mat["shelf"])
	MeshKit.lit(shelf, MeshKit.rounded_box(Vector3(width, 0.055, depth), 0.3), Vector3(0, 0.028, 0), _mat["shelf"])
	var board_y := [height * 0.36, height * 0.68]
	for y in board_y:
		MeshKit.lit(shelf, MeshKit.rounded_box(Vector3(width - 0.06, 0.035, depth - 0.04), 0.3), Vector3(0, y, 0), _mat["shelf"])
	var book_colors := [
		Color("#7fa7b8"), Color("#e0b268"), Color("#c96f62"), Color("#84ab7a"),
		Color("#9b8bb8"), Color("#e4d3a9"), Color("#6f8bb0"), Color("#c98e6d"),
	]
	var levels := [0.058, height * 0.36 + 0.020, height * 0.68 + 0.020]
	for level in range(3):
		var x := -half + 0.10
		var count := maxi(2, int((width - 0.20) / 0.11))
		for i in range(count):
			var h := minf(0.20 + (i % 3) * 0.035, (height * 0.32) - 0.06)
			var w := 0.055 + (i % 2) * 0.015
			MeshKit.lit(
				shelf,
				MeshKit.rounded_box(Vector3(w, h, 0.210), 0.35),
				Vector3(x, levels[level] + h * 0.5, 0.012),
				MeshKit.material(book_colors[(level * 6 + i) % book_colors.size()], 0.75),
				Vector3(0, 0, 4.0 if i % 2 == 0 else -3.0)
			)
			x += w + 0.060
			if x > half - 0.08:
				break


func _build_file_cabinet(parent: Node3D, pos: Vector3) -> void:
	var cabinet := Node3D.new()
	cabinet.position = pos
	parent.add_child(cabinet)
	MeshKit.lit(cabinet, MeshKit.rounded_box(Vector3(0.62, 1.05, 0.55), 0.28), Vector3(0, 0.525, 0), _mat["chair_dark"])
	for i in range(3):
		var y := 0.28 + i * 0.30
		MeshKit.lit(cabinet, MeshKit.rounded_box(Vector3(0.52, 0.24, 0.025), 0.4), Vector3(0, y, 0.285), _mat["wall_trim"])
		MeshKit.lit(cabinet, MeshKit.rounded_box(Vector3(0.16, 0.025, 0.020), 0.5), Vector3(0, y, 0.300), _mat["metal"])


func _build_whiteboard(parent: Node3D, base: Vector3, width: float, height: float) -> void:
	var board := Node3D.new()
	board.position = base
	parent.add_child(board)
	MeshKit.lit(board, MeshKit.rounded_box(Vector3(width, height, 0.045), 0.15), Vector3(0, 1.55, 0), _mat["whiteboard"])
	MeshKit.lit(board, MeshKit.rounded_box(Vector3(width + 0.08, 0.055, 0.065), 0.4), Vector3(0, 1.55 + height * 0.5, 0), _mat["whiteboard_frame"])
	MeshKit.lit(board, MeshKit.rounded_box(Vector3(width + 0.08, 0.055, 0.065), 0.4), Vector3(0, 1.55 - height * 0.5, 0), _mat["whiteboard_frame"])
	for xs in [-1.0, 1.0]:
		MeshKit.lit(board, MeshKit.rounded_box(Vector3(0.055, height, 0.065), 0.4), Vector3((width * 0.5 + 0.02) * xs, 1.55, 0), _mat["whiteboard_frame"])
	for i in range(3):
		MeshKit.lit(
			board,
			MeshKit.rounded_box(Vector3(0.85 - 0.18 * i, 0.035, 0.012), 0.5),
			Vector3(-0.30 + 0.09 * i, 1.82 - i * 0.16, 0.028),
			MeshKit.material([Color("#7fa7b8"), Color("#c96f62"), Color("#84ab7a")][i], 0.7)
		)
	MeshKit.segment(board, Vector3(-0.70, 0.10, 0), Vector3(-0.70, 0.95, 0), 0.028, _mat["whiteboard_frame"])
	MeshKit.segment(board, Vector3(0.70, 0.10, 0), Vector3(0.70, 0.95, 0), 0.028, _mat["whiteboard_frame"])


func _build_projection_screen(parent: Node3D, base: Vector3, width: float, height: float) -> void:
	var screen := Node3D.new()
	screen.position = base
	parent.add_child(screen)
	MeshKit.lit(screen, MeshKit.rounded_box(Vector3(width, 0.06, 0.07), 0.4), Vector3(0, 2.62, 0), _mat["whiteboard_frame"])
	MeshKit.lit(screen, MeshKit.rounded_box(Vector3(width, height, 0.02), 0.2), Vector3(0, 2.56 - height * 0.5, 0), _mat["whiteboard"])
	MeshKit.lit(screen, MeshKit.rounded_box(Vector3(width + 0.06, 0.05, 0.045), 0.4), Vector3(0, 2.56 - height, 0), _mat["whiteboard_frame"])
	for xs in [-1.0, 1.0]:
		MeshKit.lit(screen, MeshKit.rounded_box(Vector3(0.045, height, 0.045), 0.4), Vector3((width * 0.5 + 0.005) * xs, 2.56 - height * 0.5, 0), _mat["whiteboard_frame"])


## 3D 文字标识（使用 Godot 默认字体，拉丁文即可稳定显示）。
func _add_sign(parent: Node3D, text: String, pos: Vector3, font_size: int, pixel_size: float) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = font_size
	label.pixel_size = pixel_size
	label.modulate = Color("#33485c")
	label.outline_size = 0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = pos
	parent.add_child(label)


# ---------- 绿植 ----------

func _build_plants() -> void:
	# 办公室四角与通道边的绿植，填满前后景但避开工位与家具
	# 左下角落原绿植（z=4.65）让位给新主管工位，移至左上角落老板办公室前方
	_build_plant(self, Vector3(-11.90, 0, -4.50), 0.92)
	_build_plant(self, Vector3(11.90, 0, 4.65), 0.88)
	_build_plant(self, Vector3(-10.55, 0, 1.35), 0.72)
	_build_plant(self, Vector3(11.95, 0, 1.95), 0.72)


func _build_plant(parent: Node3D, base: Vector3, plant_scale: float) -> void:
	var root := Node3D.new()
	root.position = base
	root.scale = Vector3.ONE * plant_scale
	parent.add_child(root)

	MeshKit.lit(root, MeshKit.cylinder(0.230, 0.175, 0.360, 20), Vector3(0, 0.180, 0), _mat["pot"])
	MeshKit.lit(root, MeshKit.cylinder(0.250, 0.250, 0.055, 20), Vector3(0, 0.360, 0), _mat["pot_dark"])
	MeshKit.lit(root, MeshKit.cylinder(0.205, 0.205, 0.020, 20), Vector3(0, 0.372, 0), _mat["soil"])

	var stems := [
		[Vector3(-0.06, 0.37, 0.0), Vector3(-0.10, 0.86, 0.04)],
		[Vector3(0.06, 0.37, 0.0), Vector3(0.12, 0.95, -0.02)],
		[Vector3(0.0, 0.37, -0.02), Vector3(0.02, 1.05, 0.05)],
		[Vector3(0.0, 0.37, 0.04), Vector3(-0.04, 0.75, 0.12)],
	]
	for stem in stems:
		MeshKit.segment(root, Vector3(stem[0]), Vector3(stem[1]), 0.020, _mat["leaf_b"])

	var leaves := [
		[Vector3(-0.24, 0.74, 0.06), 0.155, 0],
		[Vector3(0.24, 0.78, -0.04), 0.160, 1],
		[Vector3(-0.10, 1.00, 0.10), 0.175, 2],
		[Vector3(0.12, 1.08, 0.02), 0.150, 0],
		[Vector3(0.0, 0.90, -0.18), 0.165, 1],
		[Vector3(-0.18, 0.95, -0.12), 0.140, 2],
		[Vector3(0.20, 0.96, 0.16), 0.130, 0],
		[Vector3(0.0, 1.16, 0.0), 0.120, 1],
	]
	var leaf_mats := [_mat["leaf_a"], _mat["leaf_b"], _mat["leaf_c"]]
	for i in range(leaves.size()):
		var pos: Vector3 = leaves[i][0]
		var size: float = leaves[i][1]
		var mi := MeshKit.lit(
			root,
			MeshKit.sphere(size, 16, 10),
			pos,
			leaf_mats[int(leaves[i][2])],
			Vector3(12 * i, 24 * i, 8 * i)
		)
		mi.scale = Vector3(1.0, 0.78, 0.70)
