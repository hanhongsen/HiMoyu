extends Node3D
## 3D 样板间：浅木地板、暖白墙面、大窗、绿植和墙面标识。
##
## 只服务 3 工位局部样板，布局保持留白，重点仍然是人物与桌面的细节。

const MeshKit := preload("res://scenes/prototype_3d/mesh_kit.gd")

const ROOM_W := 10.8
const ROOM_TOP := 3.8
const WALL_Z := -2.0

var _mat: Dictionary = {}


func _ready() -> void:
	_make_materials()
	_build_floor()
	_build_wall()
	_build_plants()
	_build_bookshelf()


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


# ---------- 地面 ----------

func _build_floor() -> void:
	# 整块浅木色地板：17 块独立木板各自着色会在斜视角下形成明显条带
	var slab := MeshKit.lit(
		self,
		MeshKit.rounded_box(Vector3(ROOM_W + 0.4, 0.09, 7.6), 0.22, 8, 20),
		Vector3(0, -0.045, 1.75),
		_mat["floor_main"]
	)
	slab.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# 木地板缝隙：细窄的深色线条，保留木地板质感但不产生明暗条带
	var plank_w := 0.612
	for i in range(1, 17):
		var x := -ROOM_W * 0.5 + plank_w * float(i)
		MeshKit.lit(
			self,
			MeshKit.rounded_box(Vector3(0.006, 0.0015, 7.55), 0.5, 3, 6),
			Vector3(x, 0.002, 1.74),
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
	# 墙面不投射阴影：否则整面墙把灯光挡在背后，只从窗口漏光，地面会出现大块条带
	wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# 踢脚线
	MeshKit.lit(
		self,
		MeshKit.rounded_box(Vector3(ROOM_W, 0.16, 0.05), 0.4),
		Vector3(0, 0.08, WALL_Z + 0.10),
		_mat["wall_trim"]
	)
	# 顶部收边
	MeshKit.lit(
		self,
		MeshKit.rounded_box(Vector3(ROOM_W, 0.10, 0.08), 0.3),
		Vector3(0, ROOM_TOP - 0.05, WALL_Z + 0.09),
		_mat["wall_trim"]
	)

	for x in [-3.55, -1.18, 1.18, 3.55]:
		_build_window(x)



func _build_window(x: float) -> void:
	var w := 1.78
	var h := 1.62
	var y := 1.98
	var z := WALL_Z + 0.115

	# 玻璃
	var glass := MeshKit.lit(
		self,
		MeshKit.rounded_box(Vector3(w - 0.10, h - 0.10, 0.02), 0.15),
		Vector3(x, y, z - 0.015),
		_mat["glass"]
	)
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# 外框
	MeshKit.lit(self, MeshKit.rounded_box(Vector3(w, 0.072, 0.055), 0.4), Vector3(x, y + h * 0.5, z), _mat["frame"])
	MeshKit.lit(self, MeshKit.rounded_box(Vector3(w, 0.072, 0.055), 0.4), Vector3(x, y - h * 0.5, z), _mat["frame"])
	MeshKit.lit(self, MeshKit.rounded_box(Vector3(0.072, h, 0.055), 0.4), Vector3(x - w * 0.5, y, z), _mat["frame"])
	MeshKit.lit(self, MeshKit.rounded_box(Vector3(0.072, h, 0.055), 0.4), Vector3(x + w * 0.5, y, z), _mat["frame"])
	# 中挺
	MeshKit.lit(self, MeshKit.rounded_box(Vector3(0.040, h - 0.07, 0.045), 0.4), Vector3(x, y, z + 0.004), _mat["frame"])
	MeshKit.lit(self, MeshKit.rounded_box(Vector3(w - 0.07, 0.040, 0.045), 0.4), Vector3(x, y + 0.42, z + 0.004), _mat["frame"])
	# 窗台
	MeshKit.lit(
		self,
		MeshKit.rounded_box(Vector3(w + 0.14, 0.055, 0.16), 0.4),
		Vector3(x, y - h * 0.5 - 0.03, z + 0.03),
		_mat["wall_trim"]
	)
	# 窗帘杆（细木质）
	MeshKit.lit(
		self,
		MeshKit.cylinder(0.016, 0.016, w + 0.30, 10),
		Vector3(x, y + h * 0.5 + 0.10, z + 0.055),
		_mat["shelf"],
		Vector3(0, 0, 90)
	)


func _build_sign() -> void:
	# 墙面标识在样板镜头下会被裁切，品牌信息改由 HUD 展示
	pass


# ---------- 绿植 ----------

func _build_plants() -> void:
	_build_plant(Vector3(-4.55, 0, -1.25), 1.15)
	_build_plant(Vector3(4.55, 0, -1.15), 1.05)
	_build_plant(Vector3(-4.45, 0, 1.15), 0.82)


func _build_plant(base: Vector3, scale: float) -> void:
	var root := Node3D.new()
	root.position = base
	root.scale = Vector3.ONE * scale
	add_child(root)

	# 花盆
	MeshKit.lit(root, MeshKit.cylinder(0.230, 0.175, 0.360, 20), Vector3(0, 0.180, 0), _mat["pot"])
	MeshKit.lit(root, MeshKit.cylinder(0.250, 0.250, 0.055, 20), Vector3(0, 0.360, 0), _mat["pot_dark"])
	MeshKit.lit(root, MeshKit.cylinder(0.205, 0.205, 0.020, 20), Vector3(0, 0.372, 0), _mat["soil"])

	# 茎
	var stems := [
		[Vector3(-0.06, 0.37, 0.0), Vector3(-0.10, 0.86, 0.04)],
		[Vector3(0.06, 0.37, 0.0), Vector3(0.12, 0.95, -0.02)],
		[Vector3(0.0, 0.37, -0.02), Vector3(0.02, 1.05, 0.05)],
		[Vector3(0.0, 0.37, 0.04), Vector3(-0.04, 0.75, 0.12)],
	]
	for stem in stems:
		MeshKit.segment(root, Vector3(stem[0]), Vector3(stem[1]), 0.020, _mat["leaf_b"])

	# 叶团（不同绿深浅与朝向，形成蓬松体积）
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


# ---------- 书架 ----------

func _build_bookshelf() -> void:
	var root := Node3D.new()
	root.position = Vector3(4.02, 0, -1.42)
	root.rotation_degrees.y = -12.0
	add_child(root)

	MeshKit.lit(root, MeshKit.rounded_box(Vector3(1.02, 1.30, 0.34), 0.25), Vector3(0, 0.65, 0), _mat["shelf"])
	MeshKit.lit(root, MeshKit.rounded_box(Vector3(0.94, 1.16, 0.03), 0.2), Vector3(0, 0.65, -0.145), _mat["wall_trim"])

	var book_colors := [
		Color("#7fa7b8"), Color("#e0b268"), Color("#c96f62"), Color("#84ab7a"),
		Color("#9b8bb8"), Color("#e4d3a9"), Color("#6f8bb0"), Color("#c98e6d"),
		Color("#a8bd86"),
	]
	for shelf_index in range(2):
		var shelf_y := 0.38 + shelf_index * 0.42
		var x := -0.40
		for i in range(5):
			var h := 0.20 + (i % 3) * 0.035
			var w := 0.055 + (i % 2) * 0.015
			MeshKit.lit(
				root,
				MeshKit.rounded_box(Vector3(w, h, 0.210), 0.35),
				Vector3(x, shelf_y + h * 0.5, 0.035),
				MeshKit.material(book_colors[(shelf_index * 5 + i) % book_colors.size()], 0.75),
				Vector3(0, 0, 4.0 if i % 2 == 0 else -3.0)
			)
			x += w + 0.055

	# 书架顶部小盆栽
	MeshKit.lit(root, MeshKit.cylinder(0.100, 0.085, 0.140, 16), Vector3(0.30, 1.370, 0.0), _mat["pot"])
	for i in range(4):
		var a := TAU * float(i) / 4.0
		var leaf := MeshKit.lit(
			root,
			MeshKit.sphere(0.070, 14, 10),
			Vector3(0.30 + cos(a) * 0.045, 1.500 + (0.015 if i % 2 else 0.0), sin(a) * 0.045),
			leaf_mats_local(i),
			Vector3(16 * cos(a), 0, 16 * sin(a))
		)
		leaf.scale = Vector3(0.8, 1.2, 0.6)


func leaf_mats_local(i: int) -> Material:
	return [_mat["leaf_a"], _mat["leaf_b"], _mat["leaf_c"]][i % 3]
