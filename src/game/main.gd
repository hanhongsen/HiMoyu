extends Node2D
## 阶段 1 主场景：办公室地图 + 25 个循环睡觉员工 + HUD 状态层。
##
## 保留阶段 0 的 WebSocket 链路与状态显示，将占位网格替换为真实办公室画面。

const WS_CLIENT := preload("res://net/ws_client.gd")
const WS_URL := "ws://127.0.0.1:8000/ws"

const OfficeBackground := preload("res://scenes/office/background.gd")
const Office := preload("res://scenes/office/office.gd")

var _office: Office
var _status_label: Label
var _seat_usage_label: Label
var _version_label: Label
var _counts_label: Label
var _last_event_label: Label

var _font: SystemFont


func _ready() -> void:
	_font = _build_font()
	_build_world()
	_build_hud()
	_start_ws()


func _build_font() -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray([
		"Microsoft YaHei UI",
		"Microsoft YaHei",
		"PingFang SC",
		"Noto Sans CJK SC",
		"SimHei",
	])
	return font


func _build_world() -> void:
	var bg := OfficeBackground.new()
	add_child(bg)

	_office = Office.new()
	add_child(_office)


func _build_hud() -> void:
	# HUD 用 CanvasLayer 悬浮在画面之上，不随世界缩放/遮挡
	var hud := CanvasLayer.new()
	hud.layer = 10
	add_child(hud)

	var theme := Theme.new()
	theme.default_font = _font
	theme.default_font_size = 18

	# 顶部状态栏
	var bar := Panel.new()
	bar.position = Vector2(0, 0)
	bar.custom_minimum_size = Vector2(1920, 56)
	var bar_style := StyleBoxFlat.new()
	bar_style.bg_color = Color("#0b1220d9")
	bar_style.set_corner_radius_all(0)
	bar.add_theme_stylebox_override("panel", bar_style)
	bar.theme = theme
	hud.add_child(bar)

	var title := _make_label("HiMoyu · AI 摸鱼办公室", 26, Color("#e6edf7"), Vector2(24, 12))
	hud.add_child(title)

	_status_label = _make_label("WebSocket：等待连接", 18, Color("#8fa1bd"), Vector2(0, 16))
	_status_label.position = Vector2(1920 - 420, 16)
	hud.add_child(_status_label)

	# 左下信息区
	var info_bg := Panel.new()
	info_bg.position = Vector2(20, 980)
	info_bg.custom_minimum_size = Vector2(720, 80)
	var info_style := StyleBoxFlat.new()
	info_style.bg_color = Color("#0b1220c8")
	info_style.set_corner_radius_all(10)
	info_style.set_border_width_all(1)
	info_style.border_color = Color("#26344f")
	info_bg.add_theme_stylebox_override("panel", info_style)
	info_bg.theme = theme
	hud.add_child(info_bg)

	_seat_usage_label = _make_label("工位 0 / 25", 18, Color("#cfe9ff"), Vector2(20, 992))
	hud.add_child(_seat_usage_label)

	_version_label = _make_label("快照版本 0", 18, Color("#cfe9ff"), Vector2(180, 992))
	hud.add_child(_version_label)

	_counts_label = _make_label("点赞 0 · 评论 0 · 礼物 0", 18, Color("#cfe9ff"), Vector2(360, 992))
	hud.add_child(_counts_label)

	_last_event_label = _make_label("最近事件：暂无", 16, Color("#ffd9cc"), Vector2(20, 1024))
	hud.add_child(_last_event_label)

	# 右下阶段标识
	var phase_label := _make_label("阶段 1 · 办公室地图与睡觉动画", 16, Color("#8fa1bd"), Vector2(0, 0))
	phase_label.position = Vector2(1920 - 320, 1024)
	hud.add_child(phase_label)


func _make_label(text: String, font_size: int, color: Color, pos: Vector2) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.position = pos
	return label


func _start_ws() -> void:
	var client := WS_CLIENT.new()
	client.url = WS_URL
	client.snapshot_received.connect(_on_snapshot)
	client.connection_changed.connect(_on_connection)
	add_child(client)


func _on_connection(connected: bool, detail: String) -> void:
	_status_label.text = "WebSocket：%s" % detail
	_status_label.add_theme_color_override(
		"font_color",
		Color("#46d39a") if connected else Color("#ff8b7b")
	)


func _on_snapshot(snapshot: Dictionary) -> void:
	var session: Dictionary = snapshot.get("session", {})
	var occupied := int(session.get("occupied_seats", 0))
	var total := int(session.get("seat_count", 25))
	_seat_usage_label.text = "工位 %d / %d" % [occupied, total]
	_version_label.text = "快照版本 %d" % int(snapshot.get("version", 0))

	var counts: Dictionary = session.get("event_counts", {})
	_counts_label.text = "点赞 %d · 评论 %d · 礼物 %d" % [
		int(counts.get("like", 0)),
		int(counts.get("comment", 0)),
		int(counts.get("gift", 0)),
	]
	_last_event_label.text = "最近事件：%s" % _describe_event(session.get("last_event", null))

	_office.apply_snapshot(snapshot)


func _describe_event(event: Variant) -> String:
	if typeof(event) != TYPE_DICTIONARY:
		return "暂无"
	var data: Dictionary = event
	var nickname := str(data.get("nickname", "模拟观众"))
	var kind := str(data.get("kind", ""))
	match kind:
		"like":
			return "%s 点赞" % nickname
		"comment":
			return "%s 评论「%s」" % [nickname, str(data.get("text", ""))]
		"gift":
			return "%s 送出 %s" % [nickname, _gift_name(str(data.get("gift_id", "")))]
	return "%s 触发 %s" % [nickname, kind]


func _gift_name(gift_id: String) -> String:
	match gift_id:
		"gift_join":
			return "入职礼物"
		"gift_phone":
			return "手机"
		"gift_snack":
			return "零食"
		"gift_coffee":
			return "咖啡"
		"gift_alarm":
			return "闹钟"
		"gift_file":
			return "文件"
	return gift_id
