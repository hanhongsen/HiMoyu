extends Node3D
## 单个轻 3D 工位组件：办公桌、办公椅、显示器、键鼠与桌面小物。
##
## 工位原点在桌子正下方地面，桌子沿 X 展开、朝向 +Z（摄像机方向）。
## 员工坐在桌子后方（-Z），趴向桌面；3 个工位通过 variant 使用不同配色与摆件。

const MeshKit := preload("res://scenes/prototype_3d/mesh_kit.gd")
const Employee3D := preload("res://scenes/prototype_3d/employee_3d.gd")

const DESK_W := 1.90
const DESK_D := 0.95
const DESK_H := 0.75

var seat_index: int = 1
var variant: int = 0
var appearance: Dictionary = {}

var employee: Node3D
var _mat: Dictionary = {}


func _ready() -> void:
	if appearance.is_empty():
		appearance = Employee3D.preview_preset(variant)
	_make_materials()
	_build_desk()
	_build_chair()
	_build_monitor()
	_build_peripherals()
	_build_props()
	_build_employee()


func _make_materials() -> void:
	var wood_tops := [Color("#d9b186"), Color("#d2a97c"), Color("#e0ba90")]
	var wood_darks := [Color("#bb9368"), Color("#b28a60"), Color("#c69d72")]
	var fabrics := [Color("#93a8ba"), Color("#9fb2c0"), Color("#8fa6b4")]

	_mat["wood"] = MeshKit.material(wood_tops[variant % 3], 0.62)
	_mat["wood_dark"] = MeshKit.material(wood_darks[variant % 3], 0.66)
	_mat["fabric"] = MeshKit.material(fabrics[variant % 3], 0.9)
	_mat["fabric_dark"] = MeshKit.material(fabrics[variant % 3].darkened(0.18), 0.9)
	_mat["metal"] = MeshKit.material(Color("#565e68"), 0.35, 0.55)
	_mat["metal_dark"] = MeshKit.material(Color("#343941"), 0.42, 0.45)
	_mat["plastic"] = MeshKit.material(Color("#2f343c"), 0.55)
	_mat["screen"] = MeshKit.material(Color("#2e4a64"), 0.30, 0.05, Color("#4f86b0"), 0.16)
	_mat["screen_ui"] = MeshKit.material(Color("#d7eaf6"), 0.4, 0.0, Color("#dff2ff"), 0.28)
	_mat["paper"] = MeshKit.material(Color("#f4ecd9"), 0.85)
	_mat["key"] = MeshKit.material(Color("#464e59"), 0.7)
	_mat["rug"] = MeshKit.material(Color("#a9b4bb"), 0.95)
	_mat["ceramic"] = MeshKit.material(Color("#f3ede2"), 0.35)
	_mat["leaf"] = MeshKit.material(Color("#5f9e5f"), 0.8)


# ---------- 桌子 ----------

func _build_desk() -> void:
	# 桌面（厚度 + 圆角）
	MeshKit.lit(
		self,
		MeshKit.rounded_box(Vector3(DESK_W, 0.078, DESK_D), 0.30, 12, 28),
		Vector3(0, DESK_H - 0.039, 0),
		_mat["wood"],
		Vector3.ZERO,
		"DeskTop"
	)

	# 前挡板，增强桌面厚度感
	MeshKit.lit(
		self,
		MeshKit.rounded_box(Vector3(DESK_W - 0.06, 0.105, 0.045), 0.35),
		Vector3(0, DESK_H - 0.115, DESK_D * 0.5 - 0.020),
		_mat["wood_dark"]
	)

	# 桌腿
	for xs in [-1.0, 1.0]:
		for zs in [-1.0, 1.0]:
			MeshKit.lit(
				self,
				MeshKit.rounded_box(Vector3(0.085, DESK_H - 0.06, 0.085), 0.35),
				Vector3(0.80 * xs, (DESK_H - 0.06) * 0.5, 0.35 * zs),
				_mat["wood_dark"]
			)

	# 左侧抽屉柜
	MeshKit.lit(
		self,
		MeshKit.rounded_box(Vector3(0.50, 0.56, 0.66), 0.32),
		Vector3(-0.54, 0.33, 0.06),
		_mat["wood_dark"]
	)
	for i in range(2):
		var y := 0.475 - i * 0.245
		MeshKit.lit(
			self,
			MeshKit.rounded_box(Vector3(0.43, 0.185, 0.030), 0.45),
			Vector3(-0.54, y, 0.396),
			_mat["wood"]
		)
		MeshKit.lit(
			self,
			MeshKit.cylinder(0.018, 0.018, 0.035, 12),
			Vector3(-0.54, y, 0.418),
			_mat["metal"],
			Vector3(90, 0, 0)
		)

	# 工位号牌
	MeshKit.lit(
		self,
		MeshKit.rounded_box(Vector3(0.175, 0.115, 0.020), 0.5),
		Vector3(0, 0.575, DESK_D * 0.5 + 0.006),
		MeshKit.material(Color("#fbf2e2"), 0.6)
	)
	var label := Label3D.new()
	label.text = "%02d" % seat_index
	label.font_size = 64
	label.pixel_size = 0.0026
	label.modulate = Color("#34506a")
	label.outline_size = 0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector3(0, 0.576, DESK_D * 0.5 + 0.018)
	add_child(label)


# ---------- 椅子 ----------

func _build_chair() -> void:
	var z := -0.52

	# 坐垫与靠背
	MeshKit.lit(
		self,
		MeshKit.rounded_box(Vector3(0.54, 0.105, 0.50), 0.55),
		Vector3(0, 0.552, z),
		_mat["fabric"]
	)
	MeshKit.lit(
		self,
		MeshKit.rounded_box(Vector3(0.570, 0.545, 0.095), 0.5),
		Vector3(0, 0.890, z - 0.235),
		_mat["fabric"],
		Vector3(-7, 0, 0)
	)
	MeshKit.lit(
		self,
		MeshKit.rounded_box(Vector3(0.40, 0.10, 0.035), 0.6),
		Vector3(0, 0.655, z - 0.205),
		_mat["fabric_dark"],
		Vector3(-7, 0, 0)
	)

	# 扶手
	for side in [-1.0, 1.0]:
		MeshKit.lit(
			self,
				MeshKit.rounded_box(Vector3(0.085, 0.050, 0.30), 0.55),
			Vector3(0.305 * side, 0.720, z + 0.055),
			_mat["fabric_dark"]
		)
		MeshKit.segment(
			self,
			Vector3(0.305 * side, 0.565, z + 0.075),
			Vector3(0.305 * side, 0.705, z + 0.075),
			0.026,
			_mat["metal"]
		)

	# 气压杆 + 五星脚
	MeshKit.lit(self, MeshKit.cylinder(0.045, 0.045, 0.29, 14), Vector3(0, 0.36, z), _mat["metal"])
	MeshKit.lit(self, MeshKit.cylinder(0.070, 0.070, 0.045, 14), Vector3(0, 0.195, z), _mat["metal_dark"])
	for i in range(5):
		var a := TAU * float(i) / 5.0 + 0.32
		var end := Vector3(cos(a) * 0.265, 0.105, z + sin(a) * 0.265)
		MeshKit.segment(self, Vector3(0, 0.155, z), end, 0.026, _mat["metal_dark"])
		MeshKit.lit(
			self,
			MeshKit.cylinder(0.045, 0.045, 0.030, 14),
			end + Vector3(0, -0.035, 0),
			_mat["metal_dark"],
			Vector3(0, 0, 90)
		)


# ---------- 显示器 ----------

func _build_monitor() -> void:
	# 第二轮优化：显示器整体缩小约 14%，并向右后方挪动，
	# 屏幕内缘让出员工脸部区域，减少对人物与交叠手臂的遮挡。
	var pivot := Node3D.new()
	pivot.name = "Monitor"
	pivot.position = Vector3(0.48, 0, -0.30)
	pivot.rotation_degrees.y = -16.0
	add_child(pivot)

	# 底座 + 立柱（保持桌面接触部分不缩放，避免沉入桌面）
	MeshKit.lit(
		pivot,
		MeshKit.rounded_box(Vector3(0.205, 0.022, 0.150), 0.5),
		Vector3(0, DESK_H + 0.011, 0.02),
		_mat["plastic"]
	)
	MeshKit.lit(pivot, MeshKit.cylinder(0.024, 0.031, 0.135, 14), Vector3(0, DESK_H + 0.088, 0.005), _mat["metal"])
	MeshKit.lit(
		pivot,
		MeshKit.rounded_box(Vector3(0.074, 0.064, 0.038), 0.4),
		Vector3(0, DESK_H + 0.152, 0.0),
		_mat["plastic"]
	)

	# 屏幕组件：以屏幕中心为原点构建，整体缩放 0.86，同时略微降低高度
	var screen := Node3D.new()
	screen.name = "Screen"
	screen.position = Vector3(0, DESK_H + 0.278, 0.0)
	screen.scale = Vector3.ONE * 0.86
	pivot.add_child(screen)

	# 屏幕主体
	MeshKit.lit(
		screen,
		MeshKit.rounded_box(Vector3(0.600, 0.375, 0.045), 0.30, 12, 26),
		Vector3.ZERO,
		_mat["plastic"]
	)
	MeshKit.lit(
		screen,
		MeshKit.rounded_box(Vector3(0.548, 0.326, 0.012), 0.28),
		Vector3(0, 0, 0.028),
		_mat["screen"]
	)

	# 屏幕 UI：标题栏 + 主窗口 + 细行文本，避免出现"屏幕长眼睛"的错觉
	MeshKit.lit(
		screen,
		MeshKit.rounded_box(Vector3(0.486, 0.026, 0.004), 0.5),
		Vector3(0, 0.132, 0.036),
		_mat["screen_ui"]
	)
	MeshKit.lit(
		screen,
		MeshKit.rounded_box(Vector3(0.310, 0.175, 0.004), 0.30),
		Vector3(-0.088, 0.012, 0.036),
		MeshKit.material(Color("#4d7590"), 0.5, 0.0, Color("#6d9fbf"), 0.10)
	)
	for i in range(4):
		MeshKit.lit(
			screen,
			MeshKit.rounded_box(Vector3(0.120, 0.010, 0.004), 0.5),
			Vector3(0.150, 0.068 - i * 0.030, 0.036),
			MeshKit.material(Color("#9fc2d8"), 0.5, 0.0, Color("#b5d8ea"), 0.10)
		)
	MeshKit.lit(
		screen,
		MeshKit.rounded_box(Vector3(0.486, 0.018, 0.004), 0.5),
		Vector3(0, -0.082, 0.036),
		MeshKit.material(Color("#8fb6cc"), 0.5, 0.0, Color("#a8d4ea"), 0.10)
	)

	# 背面散热细节
	MeshKit.lit(
		screen,
		MeshKit.rounded_box(Vector3(0.240, 0.020, 0.020), 0.5),
		Vector3(0, -0.070, -0.028),
		_mat["metal_dark"]
	)


# ---------- 键盘鼠标 ----------

func _build_peripherals() -> void:
	var top := DESK_H + 0.004

	# 键盘后移，让趴下的手臂落在干净桌面上而不是压住键盘
	var kb_z := -0.075

	# 桌垫
	MeshKit.lit(
		self,
		MeshKit.rounded_box(Vector3(0.610, 0.006, 0.280), 0.55),
		Vector3(-0.02, top, kb_z),
		_mat["rug"]
	)

	# 键盘
	MeshKit.lit(
		self,
		MeshKit.rounded_box(Vector3(0.440, 0.022, 0.155), 0.30),
		Vector3(-0.02, top + 0.013, kb_z),
		_mat["plastic"]
	)
	for i in range(3):
		MeshKit.lit(
			self,
				MeshKit.rounded_box(Vector3(0.392, 0.006, 0.030), 0.55),
			Vector3(-0.02, top + 0.026, kb_z - 0.048 + i * 0.037),
			_mat["key"]
		)
	MeshKit.lit(
		self,
		MeshKit.rounded_box(Vector3(0.150, 0.006, 0.028), 0.55),
		Vector3(-0.02, top + 0.026, kb_z + 0.060),
		_mat["key"]
	)

	# 鼠标：放在键盘右前侧，避开交叠手臂的肘部区域；
	# 用偏灰的暖色并提高粗糙度，避免顶面被主光打成一团白色
	var mouse := MeshKit.lit(
		self,
		MeshKit.sphere(0.055, 18, 12),
		Vector3(0.370, top + 0.030, -0.030),
		MeshKit.material(Color("#b5aea2"), 0.78)
	)
	mouse.scale = Vector3(1.0, 0.55, 1.25)


# ---------- 桌面小物 ----------

func _build_props() -> void:
	var top := DESK_H + 0.002

	# 每位员工都有一杯咖啡，颜色不同
	var mug_colors := [Color("#f2e6d0"), Color("#e7a6b5"), Color("#a8cfae")]
	MeshKit.lit(
		self,
		MeshKit.cylinder(0.047, 0.043, 0.095, 18),
		Vector3(-0.625, top + 0.0475, 0.235),
		MeshKit.material(mug_colors[variant % 3], 0.45)
	)
	MeshKit.lit(
		self,
		MeshKit.cylinder(0.040, 0.040, 0.004, 18),
		Vector3(-0.625, top + 0.092, 0.235),
		MeshKit.material(Color("#6b4b33"), 0.8)
	)
	MeshKit.lit(
		self,
		MeshKit.torus(0.024, 0.040, 20, 8),
		Vector3(-0.567, top + 0.048, 0.235),
		MeshKit.material(mug_colors[variant % 3], 0.45),
		Vector3(90, 0, 0)
	)

	match variant % 3:
		0:
			_build_books(Vector3(0.665, top, 0.055))
			_build_note_stack(Vector3(0.640, top, -0.135))
		1:
			_build_phone(Vector3(0.655, top, 0.145))
			_build_desk_plant(Vector3(-0.630, top, -0.035))
		2:
			_build_pen_cup(Vector3(-0.610, top, -0.080))
			_build_notebook(Vector3(0.640, top, 0.030))


func _build_books(base: Vector3) -> void:
	var colors := [Color("#5d8f9c"), Color("#e2c399"), Color("#b9655a")]
	for i in range(3):
		MeshKit.lit(
			self,
			MeshKit.rounded_box(Vector3(0.205, 0.038, 0.150), 0.45),
			base + Vector3(0.01 * i, 0.028 + i * 0.039, 0.0),
			MeshKit.material(colors[i], 0.75),
			Vector3(0, 6 * i, 0)
		)
	# 书脊
	MeshKit.lit(
		self,
		MeshKit.rounded_box(Vector3(0.028, 0.034, 0.152), 0.5),
		base + Vector3(-0.094, 0.066, 0.0),
		_mat["paper"]
	)


func _build_note_stack(base: Vector3) -> void:
	for i in range(3):
		MeshKit.lit(
			self,
			MeshKit.rounded_box(Vector3(0.145, 0.012, 0.105), 0.55),
			base + Vector3(0, 0.007 + i * 0.013, 0),
			MeshKit.material([Color("#f6e28c"), Color("#f4d2ce"), Color("#cfe3ef")][i], 0.9),
			Vector3(0, 8 - i * 5, 0)
		)


func _build_phone(base: Vector3) -> void:
	MeshKit.lit(
		self,
		MeshKit.rounded_box(Vector3(0.115, 0.014, 0.195), 0.40),
		base + Vector3(0, 0.009, 0),
		_mat["plastic"],
		Vector3(0, -12, 0)
	)
	MeshKit.lit(
		self,
		MeshKit.rounded_box(Vector3(0.100, 0.004, 0.175), 0.40),
		base + Vector3(0.002, 0.018, 0),
		MeshKit.material(Color("#9cc6dd"), 0.35, 0.0, Color("#b9e2f4"), 0.45),
		Vector3(0, -12, 0)
	)


func _build_desk_plant(base: Vector3) -> void:
	MeshKit.lit(
		self,
		MeshKit.cylinder(0.058, 0.048, 0.095, 16),
		base + Vector3(0, 0.0475, 0),
		MeshKit.material(Color("#d6c6ae"), 0.7)
	)
	MeshKit.lit(
		self,
		MeshKit.cylinder(0.050, 0.050, 0.012, 16),
		base + Vector3(0, 0.092, 0),
		MeshKit.material(Color("#5a4433"), 0.95)
	)
	for i in range(4):
		var a := TAU * float(i) / 4.0
		var leaf := MeshKit.lit(
			self,
			MeshKit.sphere(0.052, 16, 10),
			base + Vector3(cos(a) * 0.035, 0.125 + (0.018 if i % 2 == 0 else 0.0), sin(a) * 0.035),
			_mat["leaf"],
			Vector3(18 * cos(a), 0, 18 * sin(a))
		)
		leaf.scale = Vector3(0.75, 1.15, 0.55)


func _build_pen_cup(base: Vector3) -> void:
	MeshKit.lit(
		self,
		MeshKit.cylinder(0.045, 0.040, 0.100, 16),
		base + Vector3(0, 0.050, 0),
		MeshKit.material(Color("#c7a07c"), 0.7)
	)
	var pen_colors := [Color("#3f6e9e"), Color("#d76d5f"), Color("#e0bb52")]
	for i in range(3):
		var a := TAU * float(i) / 3.0
		MeshKit.segment(
			self,
			base + Vector3(cos(a) * 0.014, 0.085, sin(a) * 0.014),
			base + Vector3(cos(a) * 0.045, 0.190, sin(a) * 0.045),
			0.007,
			MeshKit.material(pen_colors[i], 0.55)
		)


func _build_notebook(base: Vector3) -> void:
	MeshKit.lit(
		self,
		MeshKit.rounded_box(Vector3(0.215, 0.020, 0.155), 0.45),
		base + Vector3(0, 0.010, 0),
		MeshKit.material(Color("#7aa58d"), 0.8),
		Vector3(0, -8, 0)
	)
	MeshKit.lit(
		self,
		MeshKit.rounded_box(Vector3(0.202, 0.006, 0.143), 0.45),
		base + Vector3(0.004, 0.023, 0),
		_mat["paper"],
		Vector3(0, -8, 0)
	)


# ---------- 员工 ----------

func _build_employee() -> void:
	employee = Employee3D.new()
	employee.name = "Employee%02d" % seat_index
	employee.position = Vector3(0, 0, -0.52)
	employee.configure(appearance, float(seat_index) * 0.83, seat_index)
	add_child(employee)
