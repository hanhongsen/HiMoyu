extends Node3D
## 25 工位完整办公室场景：浅木地板、暖白墙面、六扇大窗。
##
## 左侧为管理区（主管办公桌 / 办公椅 / 书架 / 文件柜），
## 右侧为玻璃隔断会议室（长桌 / 六把会议椅 / 白板），四角摆放绿植。
## 风格与 room_3d.gd 保持一致，仅按比例放大并补充功能区域。

const MeshKit := preload("res://scenes/prototype_3d/mesh_kit.gd")

const ROOM_W := 17.4
const ROOM_TOP := 3.6
const WALL_Z := -6.6
const FLOOR_CENTER_Z := -1.0
const FLOOR_D := 11.8

var _mat: Dictionary = {}


func _ready() -> void:
	_make_materials()
	_build_floor()
	_build_wall()
	_build_management_area()
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
	# 管理区与会议室
	_mat["mgr_wood"] = MeshKit.material(Color("#c49a6e"), 0.6)
	_mat["mgr_wood_dark"] = MeshKit.material(Color("#a67e54"), 0.66)
	_mat["metal"] = MeshKit.material(Color("#565e68"), 0.35, 0.55)
	_mat["chair_dark"] = MeshKit.material(Color("#5d6a74"), 0.85)
	_mat["whiteboard"] = MeshKit.material(Color("#f2f7f9"), 0.32)
	_mat["whiteboard_frame"] = MeshKit.material(Color("#8b959d"), 0.45, 0.35)

	# 会议室玻璃隔断：真实半透材质
	var glass_wall := StandardMaterial3D.new()
	glass_wall.albedo_color = Color(0.84, 0.92, 0.97, 0.30)
	glass_wall.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_wall.roughness = 0.12
	glass_wall.metallic = 0.05
	glass_wall.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat["glass_wall"] = glass_wall
	_mat["glass_frame"] = MeshKit.material(Color("#9aa4ab"), 0.4, 0.5)


# ---------- 地面 ----------

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


# ---------- 墙面与窗 ----------

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

	for x in [-7.15, -4.30, -1.45, 1.45, 4.30, 7.15]:
		_build_window(x)


func _build_window(x: float) -> void:
	var w := 1.78
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


# ---------- 左侧管理区 ----------

func _build_management_area() -> void:
	var root := Node3D.new()
	root.name = "ManagementArea"
	root.position = Vector3(-7.15, 0, -2.2)
	root.rotation_degrees.y = 90.0
	add_child(root)

	# 主管办公桌（比普通工位略大，面朝工位区）
	MeshKit.lit(
		root,
		MeshKit.rounded_box(Vector3(2.05, 0.078, 0.98), 0.30, 12, 28),
		Vector3(0, 0.711, 0),
		_mat["mgr_wood"]
	)
	for xs in [-1.0, 1.0]:
		for zs in [-1.0, 1.0]:
			MeshKit.lit(
				root,
				MeshKit.rounded_box(Vector3(0.085, 0.69, 0.085), 0.35),
				Vector3(0.86 * xs, 0.345, 0.37 * zs),
				_mat["mgr_wood_dark"]
			)
	# 桌上：合上的笔记本 + 文件堆 + 小台灯
	MeshKit.lit(
		root,
		MeshKit.rounded_box(Vector3(0.34, 0.022, 0.24), 0.35),
		Vector3(-0.30, 0.762, 0.02),
		_mat["chair_dark"],
		Vector3(0, 8, 0)
	)
	for i in range(3):
		MeshKit.lit(
			root,
			MeshKit.rounded_box(Vector3(0.24, 0.012, 0.17), 0.5),
			Vector3(0.34, 0.758 + i * 0.013, -0.06),
			MeshKit.material([Color("#f4ecd9"), Color("#e8ddc8"), Color("#f4ecd9")][i], 0.9),
			Vector3(0, 5 - i * 4, 0)
		)
	MeshKit.lit(root, MeshKit.cylinder(0.020, 0.026, 0.30, 10), Vector3(0.72, 0.90, -0.28), _mat["metal"], Vector3(0, 0, -18))
	MeshKit.lit(
		root,
		MeshKit.cylinder(0.085, 0.055, 0.10, 14),
		Vector3(0.775, 1.045, -0.28),
		MeshKit.material(Color("#f7ead0"), 0.5, 0.0, Color("#ffe9b8"), 0.35),
		Vector3(0, 0, -18)
	)

	# 主管椅（高背）
	var chair := Node3D.new()
	chair.position = Vector3(-0.75, 0, 0)
	root.add_child(chair)
	MeshKit.lit(chair, MeshKit.rounded_box(Vector3(0.54, 0.105, 0.50), 0.55), Vector3(0, 0.552, 0), _mat["chair_dark"])
	MeshKit.lit(
		chair,
		MeshKit.rounded_box(Vector3(0.56, 0.68, 0.095), 0.5),
		Vector3(0, 0.96, -0.24),
		_mat["chair_dark"],
		Vector3(-7, 0, 0)
	)
	MeshKit.lit(chair, MeshKit.cylinder(0.045, 0.045, 0.29, 14), Vector3(0, 0.36, 0), _mat["metal"])
	for i in range(5):
		var a := TAU * float(i) / 5.0 + 0.32
		var end := Vector3(cos(a) * 0.265, 0.105, sin(a) * 0.265)
		MeshKit.segment(chair, Vector3(0, 0.155, 0), end, 0.026, _mat["metal"])

	# 文件柜
	var cabinet := Node3D.new()
	cabinet.position = Vector3(-8.05, 0, -4.75)
	add_child(cabinet)
	MeshKit.lit(cabinet, MeshKit.rounded_box(Vector3(0.62, 1.05, 0.55), 0.28), Vector3(0, 0.525, 0), _mat["chair_dark"])
	for i in range(3):
		var y := 0.28 + i * 0.30
		MeshKit.lit(cabinet, MeshKit.rounded_box(Vector3(0.52, 0.24, 0.025), 0.4), Vector3(0, y, 0.285), _mat["wall_trim"])
		MeshKit.lit(cabinet, MeshKit.rounded_box(Vector3(0.16, 0.025, 0.020), 0.5), Vector3(0, y, 0.30), _mat["metal"])

	# 管理区书架：移到后墙左角、竖放面朝 +X（朝向工位区），
	# 开放式框架结构，书脊朝外，避免遮挡窗户
	var shelf := Node3D.new()
	shelf.position = Vector3(-8.28, 0, -5.80)
	shelf.rotation_degrees.y = 90.0
	add_child(shelf)
	# 背板 + 侧板 + 顶底板 + 两层隔板
	MeshKit.lit(shelf, MeshKit.rounded_box(Vector3(1.30, 1.45, 0.030), 0.2), Vector3(0, 0.725, -0.155), _mat["wall_trim"])
	for xs in [-1.0, 1.0]:
		MeshKit.lit(shelf, MeshKit.rounded_box(Vector3(0.040, 1.45, 0.34), 0.3), Vector3(0.63 * xs, 0.725, 0), _mat["shelf"])
	MeshKit.lit(shelf, MeshKit.rounded_box(Vector3(1.30, 0.045, 0.34), 0.3), Vector3(0, 1.425, 0), _mat["shelf"])
	MeshKit.lit(shelf, MeshKit.rounded_box(Vector3(1.30, 0.055, 0.34), 0.3), Vector3(0, 0.028, 0), _mat["shelf"])
	for board_y in [0.475, 0.895]:
		MeshKit.lit(shelf, MeshKit.rounded_box(Vector3(1.24, 0.035, 0.30), 0.3), Vector3(0, board_y, 0), _mat["shelf"])
	# 三层书脊，站在底板与两层隔板上，朝外可见
	var book_colors := [
		Color("#7fa7b8"), Color("#e0b268"), Color("#c96f62"), Color("#84ab7a"),
		Color("#9b8bb8"), Color("#e4d3a9"), Color("#6f8bb0"), Color("#c98e6d"),
	]
	for shelf_index in range(3):
		var shelf_y := 0.056 + shelf_index * 0.42
		var x := -0.55
		for i in range(6):
			var h := 0.20 + (i % 3) * 0.035
			var w := 0.055 + (i % 2) * 0.015
			MeshKit.lit(
				shelf,
				MeshKit.rounded_box(Vector3(w, h, 0.210), 0.35),
				Vector3(x, shelf_y + h * 0.5, 0.015),
				MeshKit.material(book_colors[(shelf_index * 6 + i) % book_colors.size()], 0.75),
				Vector3(0, 0, 4.0 if i % 2 == 0 else -3.0)
			)
			x += w + 0.055


# ---------- 右侧玻璃会议室 ----------

func _build_meeting_room() -> void:
	var root := Node3D.new()
	root.name = "MeetingRoom"
	add_child(root)

	# 玻璃隔断：西侧 x=6.0（z -5.0 ~ 0.0），北侧 z=0.0（x 6.0 ~ 8.5，留 0.9m 门洞）
	_build_glass_wall(root, Vector3(6.0, 0, -3.35), 3.3, true)
	_build_glass_wall(root, Vector3(6.0, 0, -0.85), 1.0, true)
	_build_glass_wall(root, Vector3(6.85, 0, 0.0), 1.7, false)
	_build_glass_wall(root, Vector3(8.10, 0, 0.0), 0.8, false)

	# 会议长桌
	MeshKit.lit(
		root,
		MeshKit.rounded_box(Vector3(1.95, 0.07, 0.95), 0.30, 12, 26),
		Vector3(7.25, 0.715, -2.60),
		_mat["mgr_wood"]
	)
	for xs in [-1.0, 1.0]:
		MeshKit.lit(
			root,
			MeshKit.rounded_box(Vector3(0.09, 0.68, 0.75), 0.35),
			Vector3(7.25 + 0.82 * xs, 0.34, -2.60),
			_mat["mgr_wood_dark"]
		)

	# 六把会议椅（两侧各三把，面朝长桌）
	for i in range(3):
		var x := 6.72 + i * 0.53
		_build_meeting_chair(root, Vector3(x, 0, -3.28), 0.0)
		_build_meeting_chair(root, Vector3(x, 0, -1.92), 180.0)

	# 白板（东墙边，面朝会议室）
	var board := Node3D.new()
	board.position = Vector3(8.42, 0, -2.60)
	board.rotation_degrees.y = -90.0
	root.add_child(board)
	MeshKit.lit(board, MeshKit.rounded_box(Vector3(1.70, 1.15, 0.045), 0.15), Vector3(0, 1.55, 0), _mat["whiteboard"])
	MeshKit.lit(board, MeshKit.rounded_box(Vector3(1.78, 0.055, 0.065), 0.4), Vector3(0, 2.15, 0), _mat["whiteboard_frame"])
	MeshKit.lit(board, MeshKit.rounded_box(Vector3(1.78, 0.055, 0.065), 0.4), Vector3(0, 0.95, 0), _mat["whiteboard_frame"])
	MeshKit.lit(board, MeshKit.rounded_box(Vector3(0.055, 1.15, 0.065), 0.4), Vector3(-0.88, 1.55, 0), _mat["whiteboard_frame"])
	MeshKit.lit(board, MeshKit.rounded_box(Vector3(0.055, 1.15, 0.065), 0.4), Vector3(0.88, 1.55, 0), _mat["whiteboard_frame"])
	# 白板上的几行"会议记录"
	for i in range(3):
		MeshKit.lit(
			board,
			MeshKit.rounded_box(Vector3(0.85 - 0.18 * i, 0.035, 0.012), 0.5),
			Vector3(-0.30 + 0.09 * i, 1.82 - i * 0.16, 0.028),
			MeshKit.material([Color("#7fa7b8"), Color("#c96f62"), Color("#84ab7a")][i], 0.7)
		)
	MeshKit.segment(board, Vector3(-0.70, 0.10, 0), Vector3(-0.70, 0.95, 0), 0.028, _mat["whiteboard_frame"])
	MeshKit.segment(board, Vector3(0.70, 0.10, 0), Vector3(0.70, 0.95, 0), 0.028, _mat["whiteboard_frame"])


func _build_glass_wall(parent: Node3D, center: Vector3, length: float, along_z: bool) -> void:
	var h := 2.30
	var size := Vector3(0.05, h, length) if along_z else Vector3(length, h, 0.05)
	var glass := MeshKit.lit(parent, MeshKit.rounded_box(size, 0.15, 6, 10), center + Vector3(0, h * 0.5, 0), _mat["glass_wall"])
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# 上下金属压条
	var rail_size := Vector3(0.07, 0.06, length) if along_z else Vector3(length, 0.06, 0.07)
	MeshKit.lit(parent, MeshKit.rounded_box(rail_size, 0.4), center + Vector3(0, h + 0.03, 0), _mat["glass_frame"])
	MeshKit.lit(parent, MeshKit.rounded_box(rail_size, 0.4), center + Vector3(0, 0.04, 0), _mat["glass_frame"])


func _build_meeting_chair(parent: Node3D, pos: Vector3, yaw: float) -> void:
	var chair := Node3D.new()
	chair.position = pos
	chair.rotation_degrees.y = yaw
	parent.add_child(chair)
	MeshKit.lit(chair, MeshKit.rounded_box(Vector3(0.42, 0.06, 0.42), 0.5), Vector3(0, 0.45, 0), _mat["chair_dark"])
	MeshKit.lit(chair, MeshKit.rounded_box(Vector3(0.42, 0.48, 0.055), 0.5), Vector3(0, 0.76, -0.19), _mat["chair_dark"])
	for xs in [-1.0, 1.0]:
		for zs in [-1.0, 1.0]:
			MeshKit.lit(
				chair,
				MeshKit.cylinder(0.020, 0.020, 0.44, 10),
				Vector3(0.17 * xs, 0.22, 0.17 * zs),
				_mat["metal"]
			)


# ---------- 绿植 ----------

func _build_plants() -> void:
	_build_plant(Vector3(-8.05, 0, -5.95), 1.15)
	_build_plant(Vector3(8.05, 0, -5.95), 1.05)
	_build_plant(Vector3(-8.15, 0, 4.05), 0.88)
	_build_plant(Vector3(8.20, 0, 4.05), 0.82)
	_build_plant(Vector3(6.35, 0, -4.55), 0.70)


func _build_plant(base: Vector3, plant_scale: float) -> void:
	var root := Node3D.new()
	root.position = base
	root.scale = Vector3.ONE * plant_scale
	add_child(root)

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
