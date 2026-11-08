extends Node3D
## 轻 3D 版 Q 版员工。
##
## 角色由基础几何体 + 圆角箱体程序化拼装，没有外部模型依赖：
##   头部（球体）+ 半球发型 / 刘海 / 发饰
##   躯干（圆角箱体）+ 连帽衫口袋 / 抽绳 / 帽子
##   四肢（胶囊）分别建构成坐姿与趴在桌面上的手臂
##
## 动画系统：SLEEP 状态下用正弦驱动呼吸、身体前后微晃、头部轻晃，
## 并周期性生成向上飘散的 Zzz。动作枚举为后续的刷手机 / 吃零食 /
## 喝咖啡 / 假工作 / 被叫醒 / 罚站预留。

const MeshKit := preload("res://scenes/prototype_3d/mesh_kit.gd")

enum Action { SLEEP, PHONE, SNACK, COFFEE, WORK, WAKE, STAND }

# 睡姿关键角度（度）
# 头部侧靠角度加大，让脸侧向一边、脸颊贴向交叠的小臂
const BODY_LEAN := 45.0
const HEAD_PITCH := -21.0
const HEAD_ROLL := 15.0
const HEAD_YAW := 13.0

const HEAD_RADIUS := 0.27
# 第二轮比例优化：头部整体缩小约 13%，身体保持不变，
# 让角色更接近精致 Q 版员工而不是"大头玩偶"
const HEAD_SCALE := 0.87

var appearance: Dictionary = {}
var action_state: int = Action.SLEEP
var anim_time: float = 0.0
var phase_offset: float = 0.0
var seat_index: int = 0

var _mat: Dictionary = {}
var _body_group: Node3D
var _chest: Node3D
var _head_pivot: Node3D
var _arm_group: Node3D
var _zzz_items: Array = []
var _zzz_timer: float = 0.9


func configure(data: Dictionary, phase: float, index: int) -> void:
	appearance = data.duplicate(true)
	phase_offset = phase
	seat_index = index


func _ready() -> void:
	if appearance.is_empty():
		appearance = preview_preset(0)
	_make_materials()
	_build_legs()
	_build_body()
	_build_head()
	_build_arms()


func _process(delta: float) -> void:
	anim_time += delta
	_update_zzz(delta)
	if action_state != Action.SLEEP:
		return

	var t := anim_time + phase_offset

	# 呼吸：胸腔缓慢起伏
	var breath := sin(t * 1.9)
	_chest.scale = Vector3(1.0 + breath * 0.012, 1.0 + breath * 0.022, 1.0 + breath * 0.012)

	# 身体极轻微前后晃动
	_body_group.rotation_degrees.x = BODY_LEAN + sin(t * 1.05) * 0.7

	# 头部：轻微点头 + 侧向晃动
	_head_pivot.rotation_degrees = Vector3(
		HEAD_PITCH + sin(t * 1.25 + 0.6) * 0.9,
		HEAD_YAW + sin(t * 0.85) * 0.7,
		HEAD_ROLL + sin(t * 1.45 + 1.1) * 1.4
	)

	# 手臂随呼吸有 1~2 毫米的浮动，避免完全静止
	_arm_group.position.y = sin(t * 1.6 + 0.4) * 0.002

	_zzz_timer -= delta
	if _zzz_timer <= 0.0:
		_spawn_zzz()
		_zzz_timer = randf_range(1.5, 2.4)


func set_action(new_action: int) -> void:
	action_state = new_action


# ---------- 材质 ----------

func _make_materials() -> void:
	var skin: Color = appearance["skin"]
	var hair: Color = appearance["hair"]
	var shirt: Color = appearance["shirt"]
	var pants: Color = appearance["pants"]
	var shoes: Color = appearance["shoes"]
	var accent: Color = appearance["accent"]

	_mat["skin"] = MeshKit.material(skin, 0.62)
	_mat["skin_dark"] = MeshKit.material(skin.darkened(0.10), 0.62)
	_mat["hair"] = MeshKit.material(hair, 0.72)
	_mat["hair_dark"] = MeshKit.material(hair.darkened(0.18), 0.72)
	_mat["shirt"] = MeshKit.material(shirt, 0.78)
	_mat["shirt_dark"] = MeshKit.material(shirt.darkened(0.16), 0.78)
	_mat["pants"] = MeshKit.material(pants, 0.82)
	_mat["shoes"] = MeshKit.material(shoes, 0.72)
	_mat["accent"] = MeshKit.material(accent, 0.6)
	_mat["accent_dark"] = MeshKit.material(accent.darkened(0.18), 0.6)
	_mat["blush"] = MeshKit.material(Color("#f0b3a5"), 0.9)
	_mat["ink"] = MeshKit.material(Color("#46362f"), 0.75)
	_mat["metal"] = MeshKit.material(Color("#3b4048"), 0.36, 0.55)


# ---------- 身体 ----------

func _build_legs() -> void:
	var pants: Material = _mat["pants"]
	var shoes: Material = _mat["shoes"]
	for side in [-1.0, 1.0]:
		var x: float = 0.105 * side
		MeshKit.segment(self, Vector3(x, 0.55, 0.0), Vector3(x, 0.51, 0.21), 0.078, pants, "Thigh")
		MeshKit.segment(self, Vector3(x, 0.51, 0.21), Vector3(x, 0.15, 0.18), 0.062, pants, "Shin")
		MeshKit.lit(
			self,
			MeshKit.rounded_box(Vector3(0.145, 0.085, 0.235), 0.45),
			Vector3(x, 0.070, 0.235),
			shoes,
			Vector3.ZERO,
			"Shoe"
		)


func _build_body() -> void:
	_body_group = Node3D.new()
	_body_group.name = "BodyLean"
	_body_group.position = Vector3(0, 0.58, 0)
	_body_group.rotation_degrees.x = BODY_LEAN
	add_child(_body_group)

	# 腰部（裤子）
	MeshKit.lit(
		_body_group,
		MeshKit.rounded_box(Vector3(0.355, 0.165, 0.255), 0.5),
		Vector3(0, 0.02, 0),
		_mat["pants"]
	)

	_chest = Node3D.new()
	_chest.name = "Chest"
	_chest.position = Vector3(0, 0.24, 0)
	_body_group.add_child(_chest)

	# 连帽衫主体：圆角箱体 + 略微前凸的肚子，避免"方块拼接"的观感
	# 第二轮比例优化：加宽加厚上半身，平衡缩小后的头部
	MeshKit.lit(
		_chest,
		MeshKit.rounded_box(Vector3(0.435, 0.355, 0.29), 0.52, 14, 26),
		Vector3.ZERO,
		_mat["shirt"]
	)
	# 下摆
	MeshKit.lit(
		_chest,
		MeshKit.rounded_box(Vector3(0.40, 0.045, 0.275), 0.55),
		Vector3(0, -0.172, 0),
		_mat["shirt_dark"]
	)
	# 口袋
	MeshKit.lit(
		_chest,
		MeshKit.rounded_box(Vector3(0.185, 0.085, 0.018), 0.6),
		Vector3(0, -0.045, 0.142),
		_mat["shirt_dark"]
	)
	# 抽绳
	MeshKit.segment(_chest, Vector3(-0.048, -0.03, 0.142), Vector3(-0.055, -0.115, 0.146), 0.007, _mat["skin"])
	MeshKit.segment(_chest, Vector3(0.048, -0.03, 0.142), Vector3(0.055, -0.115, 0.146), 0.007, _mat["skin"])

	# 帽子（搭在颈后）
	var hood := MeshKit.lit(
		_chest,
		MeshKit.sphere(0.165),
		Vector3(0, 0.108, -0.140),
		_mat["shirt_dark"]
	)
	hood.scale = Vector3(1.08, 0.68, 0.88)

	# 肩膀：加大体积，让上半身轮廓更结实
	for side in [-1.0, 1.0]:
		MeshKit.lit(
			_body_group,
			MeshKit.sphere(0.102),
			Vector3(0.205 * side, 0.375, 0.0),
			_mat["shirt"]
		)

	# 脖子
	MeshKit.lit(
		_body_group,
		MeshKit.cylinder(0.052, 0.062, 0.105),
		Vector3(0, 0.428, 0.01),
		_mat["skin"]
	)
	# 领口
	MeshKit.lit(
		_body_group,
		MeshKit.cylinder(0.115, 0.128, 0.038),
		Vector3(0, 0.405, 0.012),
		_mat["shirt_dark"]
	)

	_head_pivot = Node3D.new()
	_head_pivot.name = "HeadPivot"
	_head_pivot.position = Vector3(0.0, 0.41, 0.015)
	_head_pivot.rotation_degrees = Vector3(HEAD_PITCH, HEAD_YAW, HEAD_ROLL)
	_body_group.add_child(_head_pivot)


func _build_arms() -> void:
	_arm_group = Node3D.new()
	_arm_group.name = "ArmsOnDesk"
	add_child(_arm_group)

	# 两只手臂在桌面上自然交叠：左臂垫在下方、右臂搭在左手上，
	# 双手越过身体中线，头部侧靠在交叉点上。
	# 整条手臂用一根平滑圆管从肩连到腕，不使用任何关节球，
	# 避免"圆球拼接"的观感；肘球高度基准：桌面 y=0.75，管半径 0.072。
	# 左臂（下层）：肩 → 肘 → 越过中线 → 手掌平放在桌面（底=0.750）
	var l_shoulder := Vector3(-0.215, 0.845, 0.250)
	var l_elbow := Vector3(-0.295, 0.824, 0.415)
	var l_wrist := Vector3(-0.035, 0.820, 0.545)
	var l_hand := Vector3(0.045, 0.777, 0.585)
	# 右臂（上层）：肘部落在桌面，前臂抬起，手掌叠放在左手背上
	var r_shoulder := Vector3(0.215, 0.848, 0.250)
	var r_elbow := Vector3(0.295, 0.824, 0.415)
	var r_wrist := Vector3(0.115, 0.830, 0.560)
	var r_hand := Vector3(-0.010, 0.831, 0.600)

	_build_arm(l_shoulder, l_elbow, l_wrist, l_hand, -1.0)
	_build_arm(r_shoulder, r_elbow, r_wrist, r_hand, 1.0)


func _build_arm(shoulder: Vector3, elbow: Vector3, wrist: Vector3, hand: Vector3, side: float) -> void:
	var fore_dir := (wrist - elbow).normalized()
	var hand_dir := (hand - wrist).normalized()
	var upper_dir := (elbow - shoulder).normalized()

	# 整条手臂用一根平滑圆管从肩连到腕：肘部用"拐点外推"的三个点
	# 倒出圆角，不再使用任何关节球，彻底消除"圆球拼接"的观感。
	# 拐角倒角半径(约0.075)不小于管半径(0.072)，圆管不会在弯折处自交。
	var arm_pts := [
		shoulder,
		shoulder.lerp(elbow, 0.5) + Vector3(0.015 * side, -0.002, 0.010),
		elbow - upper_dir * 0.075,
		elbow + (fore_dir - upper_dir).normalized() * 0.055,
		elbow + fore_dir * 0.075,
		elbow.lerp(wrist, 0.5) + Vector3(0.0, 0.004, 0.008),
		wrist + fore_dir * 0.010,
	]
	MeshKit.tube(_arm_group, arm_pts, 0.072, _mat["shirt"], 10, "Arm")
	# 袖口：沿前臂的一小段加粗圆管，像卷起一圈的袖子
	MeshKit.tube(
		_arm_group,
		[wrist - fore_dir * 0.020, wrist + fore_dir * 0.016],
		0.074,
		_mat["shirt_dark"],
		10,
		"Cuff"
	)
	# 手腕 → 手背的过渡，避免袖口与手掌之间出现断口
	MeshKit.tube(
		_arm_group,
		[wrist + hand_dir * 0.008, hand - hand_dir * 0.012],
		0.044,
		_mat["skin"],
		8,
		"Wrist"
	)

	# 手掌：压扁的球体，平放在桌面 / 另一只小臂上
	var palm := MeshKit.lit(_arm_group, MeshKit.sphere(0.054), hand, _mat["skin"], Vector3.ZERO, "Hand")
	palm.scale = Vector3(1.05, 0.5, 1.2)
	# 拇指
	var thumb := MeshKit.lit(
		_arm_group,
		MeshKit.sphere(0.018),
		hand + Vector3(0.035 * side, 0.010, -0.015),
		_mat["skin"]
	)
	thumb.scale = Vector3(1.4, 0.75, 1.0)


# ---------- 头部 ----------

func _build_head() -> void:
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0.025, 0.29, 0)
	head.scale = Vector3.ONE * HEAD_SCALE
	_head_pivot.add_child(head)

	var skull := MeshKit.lit(head, MeshKit.sphere(HEAD_RADIUS, 32, 18), Vector3.ZERO, _mat["skin"], Vector3.ZERO, "Skull")
	skull.scale = Vector3(1.02, 0.97, 0.99)

	# 耳朵
	for side in [-1.0, 1.0]:
		var ear := MeshKit.lit(
			head,
			MeshKit.sphere(0.044),
			Vector3(0.264 * side, -0.005, 0.0),
			_mat["skin"]
		)
		ear.scale = Vector3(0.7, 1.15, 0.9)

	_build_hair(head)
	_build_face(head)
	_build_accessory(head)


func _build_hair(head: Node3D) -> void:
	var style := int(appearance["hair_style"])

	# 发帽：略微前压，让发际线更贴近眼睛，缩小"大额头"的观感
	var cap := MeshKit.lit(
		head,
		MeshKit.hemisphere(0.288, 32, 14),
		Vector3(0, 0.058, -0.050),
		_mat["hair"],
		Vector3(-24, 0, 0),
		"HairCap"
	)
	cap.scale = Vector3(1.03, 0.98, 1.07)

	# 后脑发片，增加体积感
	var back_size := Vector3(0.315, 0.26, 0.105)
	var back_pos := Vector3(0, -0.095, -0.125)
	if style == 1:
		back_size = Vector3(0.345, 0.42, 0.125)
		back_pos = Vector3(0, -0.185, -0.135)
	MeshKit.lit(
		head,
		MeshKit.rounded_box(back_size, 0.55, 10, 20),
		back_pos,
		_mat["hair"]
	)

	# 发帽边缘保持干净的半圆发际线，碎发只做轻微体积变化，避免遮挡五官
	# 鬓角：贴着脸侧向下，作为发型轮廓而不是横在脸上
	var side_scale := 1.55
	if style == 1:
		side_scale = 2.15
	for side in [-1.0, 1.0]:
		var lock := MeshKit.lit(
			head,
			MeshKit.sphere(0.072, 18, 12),
			Vector3(0.252 * side, -0.060, -0.006),
			_mat["hair"]
		)
		lock.scale = Vector3(0.55, side_scale, 0.65)

	match style:
		0:
			# 一小撮呆毛，避免发型过于"头盔"
			MeshKit.segment(head, Vector3(0.010, 0.318, -0.020), Vector3(0.038, 0.372, -0.060), 0.018, _mat["hair"])
			MeshKit.segment(head, Vector3(0.038, 0.372, -0.060), Vector3(0.076, 0.352, -0.108), 0.015, _mat["hair"])
		1:
			# 丸子头 + 发圈
			var bun := MeshKit.lit(head, MeshKit.sphere(0.108, 20, 14), Vector3(0, 0.255, -0.155), _mat["hair"], Vector3.ZERO, "Bun")
			bun.scale = Vector3(1.0, 0.95, 1.0)
			MeshKit.lit(
				head,
				MeshKit.torus(0.060, 0.088, 20, 8),
				Vector3(0, 0.205, -0.148),
				_mat["accent"],
				Vector3(14, 0, 0)
			)
		2:
			# 刺猬头：几束向外挑起的发梢（戴帽子时不叠加，避免轮廓杂乱）
			if int(appearance["accessory"]) == 3:
				return
			var spikes := [
				[Vector3(-0.195, 0.150, -0.020), Vector3(-0.285, 0.305, -0.075)],
				[Vector3(-0.085, 0.235, 0.000), Vector3(-0.115, 0.420, -0.020)],
				[Vector3(0.000, 0.252, -0.020), Vector3(0.000, 0.465, -0.035)],
				[Vector3(0.085, 0.235, 0.000), Vector3(0.115, 0.420, -0.020)],
				[Vector3(0.195, 0.150, -0.020), Vector3(0.285, 0.305, -0.075)],
				[Vector3(0.000, 0.095, -0.240), Vector3(0.000, 0.235, -0.390)],
			]
			for spike in spikes:
				MeshKit.cone_between(head, Vector3(spike[0]), Vector3(spike[1]), 0.062, _mat["hair"])


func _build_face(head: Node3D) -> void:
	# 五官贴合脸部球面，位置略偏上，避免全部挤在下巴附近
	# 闭眼：沿脸部球面生成一根平滑圆管，避免多段拼接线看起来像"眉毛"
	var eye_pts := [
		Vector2(0.150, 0.040), Vector2(0.135, 0.026), Vector2(0.120, 0.017),
		Vector2(0.104, 0.014), Vector2(0.088, 0.017), Vector2(0.072, 0.026),
		Vector2(0.056, 0.040),
	]
	for side in [-1.0, 1.0]:
		var pts: Array = []
		for v in eye_pts:
			pts.append(_face_point(v.x * side, v.y))
		MeshKit.tube(head, pts, 0.010, _mat["ink"], 8, "EyeLine")

		# 腮红：小而淡，贴在眼睛外下方，避免显得像"捂着脸"
		var blush := MeshKit.lit(
			head,
			MeshKit.sphere(0.042, 18, 12),
			_face_point(0.150 * side, -0.004, 0.002),
			_mat["blush"]
		)
		blush.scale = Vector3(1.0, 0.52, 0.26)

	# 鼻子：小圆点
	var nose := MeshKit.lit(head, MeshKit.sphere(0.014), _face_point(0.0, -0.026, 0.010), _mat["skin_dark"])
	nose.scale = Vector3(1.0, 0.82, 0.62)

	# 嘴巴：放松的浅笑，用平滑圆管避免两段拼接形成"八字胡"的观感
	var mouth_pts := [
		_face_point(-0.030, -0.044), _face_point(-0.015, -0.050),
		_face_point(0.0, -0.052), _face_point(0.015, -0.050),
		_face_point(0.030, -0.044),
	]
	MeshKit.tube(head, mouth_pts, 0.0065, _mat["ink"], 6, "Mouth")


## 把一个脸部平面坐标投影到头部球面上，extra 为向外偏移量。
func _face_point(px: float, py: float, extra: float = 0.006) -> Vector3:
	var face_r := 0.272
	var pz := sqrt(maxf(face_r * face_r - px * px - py * py, 0.0)) + extra
	return Vector3(px, py, pz)


func _build_accessory(head: Node3D) -> void:
	# 底部都压在桌面，如果低头角度很大，面部配件仍位于头部表面
	match int(appearance["accessory"]):
		1:
			_build_glasses(head)
		2:
			_build_headphones(head)
		3:
			_build_cap(head)


func _build_glasses(head: Node3D) -> void:
	var frame: Material = _mat["metal"]
	for side in [-1.0, 1.0]:
		MeshKit.lit(
			head,
			MeshKit.torus(0.047, 0.060, 24, 8),
			Vector3(0.098 * side, -0.016, 0.262),
			frame,
			Vector3(90, 0, 0)
		)
		# 镜腿
		MeshKit.segment(
			head,
			Vector3(0.132 * side, -0.012, 0.246),
			Vector3(0.254 * side, 0.012, -0.012),
			0.0055,
			frame
		)
	# 鼻梁
	MeshKit.segment(head, Vector3(-0.045, -0.016, 0.268), Vector3(0.045, -0.016, 0.268), 0.0055, frame)
	# 镜片反光
	for side in [-1.0, 1.0]:
		var glint := MeshKit.lit(
			head,
			MeshKit.rounded_box(Vector3(0.022, 0.010, 0.004), 0.6),
			Vector3(0.078 * side, 0.008, 0.271),
			MeshKit.material(Color(1, 1, 1, 1), 0.2)
		)
		glint.rotation_degrees.z = 28


func _build_headphones(head: Node3D) -> void:
	var band: Material = _mat["metal"]
	var arc := [
		Vector3(-0.258, -0.010, 0.0),
		Vector3(-0.232, 0.185, 0.012),
		Vector3(-0.090, 0.272, 0.012),
		Vector3(0.090, 0.272, 0.012),
		Vector3(0.232, 0.185, 0.012),
		Vector3(0.258, -0.010, 0.0),
	]
	for i in range(arc.size() - 1):
		MeshKit.segment(head, Vector3(arc[i]), Vector3(arc[i + 1]), 0.014, band)
	for side in [-1.0, 1.0]:
		MeshKit.lit(
			head,
			MeshKit.cylinder(0.066, 0.066, 0.050),
			Vector3(0.272 * side, -0.008, 0.0),
			band,
			Vector3(0, 0, 90)
		)
		var accent := MeshKit.lit(
			head,
			MeshKit.cylinder(0.030, 0.030, 0.012),
			Vector3(0.300 * side, -0.008, 0.0),
			_mat["accent"],
			Vector3(0, 0, 90)
		)
		accent.scale = Vector3(1, 1, 1)


func _build_cap(head: Node3D) -> void:
	var cap := MeshKit.lit(
		head,
		MeshKit.cylinder(0.238, 0.278, 0.125),
		Vector3(0, 0.228, -0.005),
		_mat["accent"]
	)
	cap.scale = Vector3(1.0, 1.0, 0.96)
	MeshKit.lit(
		head,
		MeshKit.rounded_box(Vector3(0.330, 0.026, 0.215), 0.5),
		Vector3(0, 0.162, 0.128),
		_mat["accent_dark"],
		Vector3(-7, 0, 0)
	)
	MeshKit.lit(head, MeshKit.sphere(0.030), Vector3(0, 0.292, -0.005), _mat["accent_dark"])


# ---------- Zzz ----------

func _spawn_zzz() -> void:
	if _zzz_items.size() >= 3:
		return
	var label := Label3D.new()
	label.text = "Z"
	label.font_size = 72
	label.pixel_size = 0.0034
	label.modulate = Color(0.52, 0.72, 0.92, 0.0)
	label.outline_size = 10
	label.outline_modulate = Color(1, 1, 1, 0.85)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.shaded = false
	label.double_sided = true
	add_child(label)

	var start := Vector3(0.16 + randf_range(-0.03, 0.05), 1.36 + randf_range(-0.02, 0.03), 0.02)
	label.position = start
	label.scale = Vector3.ONE * 0.75

	_zzz_items.append({
		"node": label,
		"age": 0.0,
		"life": randf_range(2.0, 2.8),
		"start": start,
		"drift": randf_range(0.06, 0.13),
	})


func _update_zzz(delta: float) -> void:
	var survivors := []
	for item in _zzz_items:
		var node: Label3D = item["node"]
		item["age"] = float(item["age"]) + delta
		var age: float = float(item["age"])
		var life: float = float(item["life"])
		if age >= life:
			node.queue_free()
			continue
		var t := age / life
		var start: Vector3 = item["start"]
		var drift: float = float(item["drift"])
		node.position = start + Vector3(drift * t, 0.46 * t, 0.0)
		var s := 0.72 + t * 0.55
		node.scale = Vector3(s, s, s)
		var alpha := sin(clampf(t, 0.0, 1.0) * PI) * 0.95
		node.modulate = Color(0.52, 0.72, 0.92, alpha)
		survivors.append(item)
	_zzz_items = survivors


# ---------- 外观生成 ----------

static func preview_preset(index: int) -> Dictionary:
	var presets := [
		{
			"skin": Color("#eec09c"), "hair": Color("#4b3427"), "shirt": Color("#5f86d6"),
			"pants": Color("#34405a"), "shoes": Color("#2f3540"), "accent": Color("#c58a52"),
			"hair_style": 0, "accessory": 1,
		},
		{
			"skin": Color("#edc39e"), "hair": Color("#2c2229"), "shirt": Color("#e392a9"),
			"pants": Color("#4a3d59"), "shoes": Color("#6d4a46"), "accent": Color("#c9576e"),
			"hair_style": 1, "accessory": 2,
		},
		{
			"skin": Color("#dfab83"), "hair": Color("#1d1a19"), "shirt": Color("#69bd8b"),
			"pants": Color("#3f4a3e"), "shoes": Color("#ded4c4"), "accent": Color("#d9a44c"),
			"hair_style": 0, "accessory": 3,
		},
	]
	return presets[index % presets.size()]


## 确定性生成 25 名员工外观（1..25），后续扩展工位时可直接复用。
static func generate_appearance(seed_index: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_index * 2654435761

	var skins := [
		Color("#eec09c"), Color("#e3b189"), Color("#f2cbaa"),
		Color("#d9a07a"), Color("#f0d4b6"),
	]
	var hairs := [
		Color("#4b3427"), Color("#1d1a19"), Color("#6b4423"), Color("#a86a3a"),
		Color("#d4a05a"), Color("#4a3a5a"), Color("#2a4a6a"), Color("#c25a5a"),
	]
	var shirts := [
		Color("#5f86d6"), Color("#69bd8b"), Color("#e07a5f"), Color("#9b6dd1"),
		Color("#e9a8ba"), Color("#4d9fb0"), Color("#d65b8a"), Color("#6dbf5f"),
		Color("#7a8a9a"),
	]
	var accents := [
		Color("#d9a44c"), Color("#c58a52"), Color("#c9576e"), Color("#4f8fb8"),
	]
	var result := {
		"skin": skins[rng.randi_range(0, skins.size() - 1)],
		"hair": hairs[rng.randi_range(0, hairs.size() - 1)],
		"shirt": shirts[rng.randi_range(0, shirts.size() - 1)],
		"pants": Color("#3c4050").darkened(rng.randf_range(0.0, 0.15)),
		"shoes": Color("#3a3640").lightened(rng.randf_range(0.0, 0.2)),
		"accent": accents[rng.randi_range(0, accents.size() - 1)],
		"hair_style": rng.randi_range(0, 2),
		"accessory": rng.randi_range(0, 3),
	}
	return result
