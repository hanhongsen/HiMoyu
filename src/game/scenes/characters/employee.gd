class_name Employee
extends Node2D
## 可复用的员工人物组件。
##
## 通过 appearance 字典程序化绘制抽象动漫形象，不依赖外部素材。
## 人物内部按 z_index 分层：_body_layer（身体+头，z=1）和 _arms_layer（手臂，z=3），
## 工位桌面会放在 z=2，从而形成"头部露出桌面、手臂趴在桌上"的正确遮挡。
##
## 动画状态通过 set_action() 切换，本阶段只实现 SLEEP，
## 但结构已为 PHONE / SNACK / COFFEE / WORK / WAKE / STAND 预留。

enum Action { SLEEP, PHONE, SNACK, COFFEE, WORK, WAKE, STAND }

const DrawLayer := preload("res://scenes/characters/draw_layer.gd")

# 外观参数
var appearance: Dictionary = {
	"skin": Color("#f6c9a8"),
	"hair": Color("#3a2a22"),
	"shirt": Color("#5b8def"),
	"hair_style": 0,
	"accessory": 0,
}

var action_state: Action = Action.SLEEP
var nickname: String = ""
var seat_index: int = 0

# 动画时间（带相位偏移，避免 25 人完全同步）
var anim_time: float = 0.0
var phase_offset: float = 0.0

# 睡觉 Zzz 粒子
var _zzz: Array = []

# 内部分层节点
var _body_layer: Node2D
var _arms_layer: Node2D


func _ready() -> void:
	_body_layer = DrawLayer.new()
	_body_layer.z_index = 1
	_body_layer.draw_callback = func(layer): _draw_body(layer)
	add_child(_body_layer)

	_arms_layer = DrawLayer.new()
	_arms_layer.z_index = 4
	_arms_layer.draw_callback = func(layer): _draw_arms(layer)
	add_child(_arms_layer)

	# 初始外观刷新
	_redraw_all()


func _process(delta: float) -> void:
	anim_time += delta
	match action_state:
		Action.SLEEP:
			_update_sleep(delta)
		_:
			pass
	_redraw_all()


func set_appearance(data: Dictionary) -> void:
	for key in data.keys():
		if appearance.has(key):
			appearance[key] = data[key]
	queue_redraw()


func set_action(new_action: Action) -> void:
	action_state = new_action
	queue_redraw()


func set_nickname(name: String) -> void:
	nickname = name


func bind_seat(index: int) -> void:
	seat_index = index


func _redraw_all() -> void:
	if _body_layer:
		_body_layer.queue_redraw()
	if _arms_layer:
		_arms_layer.queue_redraw()


# ---------- 睡觉动画 ----------

func _update_sleep(delta: float) -> void:
	# Zzz 粒子生成与更新
	if randf() < delta * 0.6:
		_zzz.append({
			"x": randf_range(-6.0, 8.0),
			"y": -42.0,
			"life": 0.0,
			"max_life": randf_range(1.6, 2.6),
			"size": randf_range(7.0, 11.0),
		})
	var survivors := []
	for p in _zzz:
		p["life"] = float(p["life"]) + delta
		p["y"] = float(p["y"]) - delta * 14.0
		p["x"] = float(p["x"]) + delta * 6.0
		if float(p["life"]) < float(p["max_life"]):
			survivors.append(p)
	_zzz = survivors


func _sleep_breath() -> float:
	# 呼吸缩放：0.96 ~ 1.04
	return 1.0 + sin(anim_time * 2.2 + phase_offset) * 0.04


func _sleep_head_bob() -> float:
	# 头部轻微上下点动
	return sin(anim_time * 1.6 + phase_offset * 1.3) * 2.5


# ---------- 绘制 ----------

func _draw_body(layer: CanvasItem) -> void:
	var skin: Color = appearance["skin"]
	var hair: Color = appearance["hair"]
	var shirt: Color = appearance["shirt"]
	var hair_style: int = int(appearance["hair_style"])
	var accessory: int = int(appearance["accessory"])

	var breath := _sleep_breath()
	var bob := _sleep_head_bob()

	# 身体 / 肩膀（梯形）—— 位于桌面后方，被桌面遮挡下半部分
	var body_top_y := -6.0 + bob * 0.3
	var body_bottom_y := 46.0
	var body_half_top := 22.0 * breath
	var body_half_bottom := 30.0 * breath
	var body_pts := PackedVector2Array([
		Vector2(-body_half_top, body_top_y),
		Vector2(body_half_top, body_top_y),
		Vector2(body_half_bottom, body_bottom_y),
		Vector2(-body_half_bottom, body_bottom_y),
	])
	layer.draw_colored_polygon(body_pts, shirt)

	# 脖子
	var neck_w := 10.0 * breath
	layer.draw_rect(Rect2(-neck_w * 0.5, body_top_y - 8.0, neck_w, 10.0), skin)

	# 头部
	var head_cx := 0.0
	var head_cy := -24.0 + bob
	var head_r := 18.0
	layer.draw_circle(Vector2(head_cx, head_cy), head_r, skin)

	# 头发（按样式）
	_draw_hair(layer, head_cx, head_cy, head_r, hair, hair_style)

	# 闭眼（两条小线段）
	var eye_y := head_cy - 1.0
	var eye_half := 5.0
	var eye_color := Color("#2b2b2b")
	layer.draw_line(Vector2(head_cx - eye_half - 2.0, eye_y), Vector2(head_cx - eye_half + 2.0, eye_y), eye_color, 1.6)
	layer.draw_line(Vector2(head_cx + eye_half - 2.0, eye_y), Vector2(head_cx + eye_half + 2.0, eye_y), eye_color, 1.6)

	# 腮红（睡觉时的可爱感）
	var blush := Color(1.0, 0.65, 0.65, 0.45)
	layer.draw_circle(Vector2(head_cx - 9.0, eye_y + 5.0), 3.0, blush)
	layer.draw_circle(Vector2(head_cx + 9.0, eye_y + 5.0), 3.0, blush)

	# 配件（眼镜 / 耳机 / 帽子）
	match accessory:
		0:
			pass  # 无配件
		1:
			# 圆框眼镜
			var glasses := Color("#222222")
			layer.draw_arc(Vector2(head_cx - 6.0, eye_y), 4.5, 0.0, TAU, 16, glasses, 1.4)
			layer.draw_arc(Vector2(head_cx + 6.0, eye_y), 4.5, 0.0, TAU, 16, glasses, 1.4)
			layer.draw_line(Vector2(head_cx - 1.5, eye_y), Vector2(head_cx + 1.5, eye_y), glasses, 1.4)
		2:
			# 耳机
			var hp := Color("#444444")
			layer.draw_arc(Vector2(head_cx, head_cy), head_r + 1.0, PI * 1.15, PI * 1.85, 12, hp, 3.0)
			layer.draw_circle(Vector2(head_cx - head_r, head_cy + 2.0), 4.0, hp)
			layer.draw_circle(Vector2(head_cx + head_r, head_cy + 2.0), 4.0, hp)
		3:
			# 小帽子
			var hat := hair.darkened(0.2)
			var hat_pts := PackedVector2Array([
				Vector2(head_cx - head_r - 1.0, head_cy - head_r * 0.4),
				Vector2(head_cx + head_r + 1.0, head_cy - head_r * 0.4),
				Vector2(head_cx + head_r * 0.6, head_cy - head_r - 6.0),
				Vector2(head_cx - head_r * 0.6, head_cy - head_r - 6.0),
			])
			layer.draw_colored_polygon(hat_pts, hat)


func _draw_hair(layer: CanvasItem, cx: float, cy: float, r: float, color: Color, style: int) -> void:
	match style:
		0:
			# 短发：头顶半圆 + 底部封口（顺时针：左→顶→右→右下→左下）
			var pts := PackedVector2Array()
			for i in range(13):
				var a := PI + (PI * float(i) / 12.0)
				pts.append(Vector2(cx + cos(a) * (r + 1.5), cy + sin(a) * (r + 1.5)))
			pts.append(Vector2(cx + r, cy + 2.0))
			pts.append(Vector2(cx - r, cy + 2.0))
			layer.draw_colored_polygon(pts, color)
		1:
			# 刘海：短发 + 前刘海
			var base := PackedVector2Array()
			for i in range(13):
				var a := PI + (PI * float(i) / 12.0)
				base.append(Vector2(cx + cos(a) * (r + 1.5), cy + sin(a) * (r + 1.5)))
			base.append(Vector2(cx + r, cy + 2.0))
			base.append(Vector2(cx - r, cy + 2.0))
			layer.draw_colored_polygon(base, color)
			for i in range(3):
				var bx := cx - r * 0.5 + i * r * 0.5
				var bang := PackedVector2Array([
					Vector2(bx - 4.0, cy - r * 0.7),
					Vector2(bx + 4.0, cy - r * 0.7),
					Vector2(bx + 1.0, cy - r * 0.2),
				])
				layer.draw_colored_polygon(bang, color.darkened(0.12))
		2:
			# 长发：两侧垂下
			var pts := PackedVector2Array()
			for i in range(13):
				var a := PI + (PI * float(i) / 12.0)
				pts.append(Vector2(cx + cos(a) * (r + 1.5), cy + sin(a) * (r + 1.5)))
			pts.append(Vector2(cx + r, cy + 2.0))
			pts.append(Vector2(cx - r, cy + 2.0))
			layer.draw_colored_polygon(pts, color)
			layer.draw_rect(Rect2(cx - r - 2.0, cy - 2.0, 6.0, r + 14.0), color)
			layer.draw_rect(Rect2(cx + r - 4.0, cy - 2.0, 6.0, r + 14.0), color)
		3:
			# 丸子头：头顶一团
			var pts := PackedVector2Array()
			for i in range(13):
				var a := PI + (PI * float(i) / 12.0)
				pts.append(Vector2(cx + cos(a) * (r + 1.5), cy + sin(a) * (r + 1.5)))
			pts.append(Vector2(cx + r, cy + 2.0))
			pts.append(Vector2(cx - r, cy + 2.0))
			layer.draw_colored_polygon(pts, color)
			layer.draw_circle(Vector2(cx, cy - r - 5.0), 6.0, color)
		4:
			# 刺猬头：头顶尖刺
			var pts := PackedVector2Array([Vector2(cx - r, cy + 2.0)])
			var spikes := 5
			for i in range(spikes):
				var x_base := cx - r + (2.0 * r * float(i) / float(spikes))
				var x_tip := cx - r + (2.0 * r * float(i + 0.5) / float(spikes))
				pts.append(Vector2(x_base, cy - r * 0.5))
				pts.append(Vector2(x_tip, cy - r - 7.0))
			pts.append(Vector2(cx + r, cy - r * 0.5))
			pts.append(Vector2(cx + r, cy + 2.0))
			layer.draw_colored_polygon(pts, color)
		_:
			layer.draw_circle(Vector2(cx, cy), r + 1.5, color)


func _draw_arms(layer: CanvasItem) -> void:
	var skin: Color = appearance["skin"]
	var shirt: Color = appearance["shirt"]
	var breath := _sleep_breath()

	# 手臂趴在桌面上
	var left_shoulder := Vector2(-22.0 * breath, -2.0)
	var left_hand := Vector2(-12.0, 12.0)
	var arm_pts_l := PackedVector2Array([
		left_shoulder + Vector2(-5.0, 0.0),
		left_shoulder + Vector2(5.0, 0.0),
		left_hand + Vector2(4.0, 4.0),
		left_hand + Vector2(-4.0, 4.0),
	])
	layer.draw_colored_polygon(arm_pts_l, shirt)
	layer.draw_circle(left_hand, 5.0, skin)

	var right_shoulder := Vector2(22.0 * breath, -2.0)
	var right_hand := Vector2(12.0, 12.0)
	var arm_pts_r := PackedVector2Array([
		right_shoulder + Vector2(-5.0, 0.0),
		right_shoulder + Vector2(5.0, 0.0),
		right_hand + Vector2(4.0, 4.0),
		right_hand + Vector2(-4.0, 4.0),
	])
	layer.draw_colored_polygon(arm_pts_r, shirt)
	layer.draw_circle(right_hand, 5.0, skin)

	# Zzz 睡觉提示
	for p in _zzz:
		var t: float = float(p["life"]) / float(p["max_life"])
		var alpha: float = 1.0 - t
		var col := Color(0.35, 0.55, 0.85, alpha)
		var sz: float = float(p["size"])
		var px: float = float(p["x"])
		var py: float = float(p["y"])
		layer.draw_line(Vector2(px - sz, py - sz * 0.5), Vector2(px + sz, py - sz * 0.5), col, 1.8)
		layer.draw_line(Vector2(px + sz, py - sz * 0.5), Vector2(px - sz, py + sz * 0.5), col, 1.8)
		layer.draw_line(Vector2(px - sz, py + sz * 0.5), Vector2(px + sz, py + sz * 0.5), col, 1.8)


# ---------- 外观生成 ----------

static func generate_appearance(seed_index: int) -> Dictionary:
	# 基于工位序号生成确定性外观，保证 25 人可区分且可复现
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_index * 2654435761

	var skins := [
		Color("#f6c9a8"), Color("#e8b590"), Color("#f0d2b0"),
		Color("#d9a07a"), Color("#f7dcc2"),
	]
	var hairs := [
		Color("#3a2a22"), Color("#1a1a1a"), Color("#6b4423"),
		Color("#a86a3a"), Color("#d4a05a"), Color("#4a3a5a"),
		Color("#2a4a6a"), Color("#c25a5a"),
	]
	var shirts := [
		Color("#5b8def"), Color("#5fbf8a"), Color("#e07a5f"),
		Color("#9b6dd1"), Color("#e0a94d"), Color("#4d9fb0"),
		Color("#d65b8a"), Color("#6dbf5f"), Color("#7a8a9a"),
	]
	return {
		"skin": skins[rng.randi_range(0, skins.size() - 1)],
		"hair": hairs[rng.randi_range(0, hairs.size() - 1)],
		"shirt": shirts[rng.randi_range(0, shirts.size() - 1)],
		"hair_style": rng.randi_range(0, 4),
		"accessory": rng.randi_range(0, 3),
	}
