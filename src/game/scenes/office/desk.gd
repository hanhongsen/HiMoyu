class_name Desk
extends Node2D
## 单个工位组件：桌子、椅子、显示器、编号，以及绑定的员工。
##
## 内部按 z_index 分层，保证遮挡关系正确：
##   chair(0) → employee.body(1) → desk_top(2) → monitor(3) → employee.arms(4) → label(5)

const DrawLayer := preload("res://scenes/characters/draw_layer.gd")
const Employee := preload("res://scenes/characters/employee.gd")
const SeatLayout := preload("res://config/seat_layout.gd")

var seat_index: int = 0
var employee: Employee

var _chair_layer: DrawLayer
var _desk_layer: DrawLayer
var _monitor_layer: DrawLayer
var _label: Label


func _ready() -> void:
	_chair_layer = DrawLayer.new()
	_chair_layer.z_index = 0
	_chair_layer.draw_callback = func(layer): _draw_chair(layer)
	add_child(_chair_layer)

	_desk_layer = DrawLayer.new()
	_desk_layer.z_index = 2
	_desk_layer.draw_callback = func(layer): _draw_desk(layer)
	add_child(_desk_layer)

	_monitor_layer = DrawLayer.new()
	_monitor_layer.z_index = 3
	_monitor_layer.draw_callback = func(layer): _draw_monitor(layer)
	add_child(_monitor_layer)

	_label = Label.new()
	_label.z_index = 5
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_color", Color("#ffffff"))
	add_child(_label)


func setup(index: int) -> void:
	seat_index = index
	# 按行设置 z_index，保证前排工位遮挡后排（轻微伪等距）
	var row := (index - 1) / 5
	z_index = row * 100

	# 创建员工
	employee = Employee.new()
	employee.z_index = 0
	employee.position = Vector2(SeatLayout.EMPLOYEE_OFFSET_X, SeatLayout.EMPLOYEE_OFFSET_Y)
	employee.phase_offset = float(index) * 0.73  # 错开动画相位
	employee.appearance = Employee.generate_appearance(index)
	employee.set_nickname("员工%02d" % index)
	employee.bind_seat(index)
	add_child(employee)

	# 编号标签位置：桌面右下角
	_label.text = "%02d" % index
	_label.position = Vector2(SeatLayout.DESK_WIDTH - 28.0, SeatLayout.DESK_DEPTH - 22.0)

	_redraw()


func _redraw() -> void:
	if _chair_layer:
		_chair_layer.queue_redraw()
	if _desk_layer:
		_desk_layer.queue_redraw()
	if _monitor_layer:
		_monitor_layer.queue_redraw()


func _draw_chair(layer: CanvasItem) -> void:
	# 椅子：位于桌子后方（y 为负），员工坐在上面
	var chair_color := Color("#5a4a3a")
	var seat_w := 70.0
	var seat_h := 14.0
	var seat_x := (SeatLayout.DESK_WIDTH - seat_w) * 0.5
	var seat_y := -22.0
	# 座椅面
	layer.draw_rect(Rect2(seat_x, seat_y, seat_w, seat_h), chair_color)
	# 靠背
	layer.draw_rect(Rect2(seat_x + 4.0, seat_y - 30.0, seat_w - 8.0, 30.0), chair_color.darkened(0.15))
	# 椅腿
	layer.draw_rect(Rect2(seat_x + 4.0, seat_y + seat_h, 6.0, 18.0), chair_color.darkened(0.25))
	layer.draw_rect(Rect2(seat_x + seat_w - 10.0, seat_y + seat_h, 6.0, 18.0), chair_color.darkened(0.25))


func _draw_desk(layer: CanvasItem) -> void:
	# 桌面
	var top_color := Color("#b5895a")
	var edge_color := Color("#8a6440")
	layer.draw_rect(Rect2(0, 0, SeatLayout.DESK_WIDTH, SeatLayout.DESK_DEPTH), top_color)
	# 桌面边缘描边（前侧加厚，营造厚度）
	layer.draw_rect(Rect2(0, SeatLayout.DESK_DEPTH - 6.0, SeatLayout.DESK_WIDTH, 6.0), edge_color)
	# 桌腿
	var leg_color := Color("#6b4f30")
	var leg_w := 8.0
	layer.draw_rect(Rect2(4.0, SeatLayout.DESK_DEPTH - 4.0, leg_w, 14.0), leg_color)
	layer.draw_rect(Rect2(SeatLayout.DESK_WIDTH - leg_w - 4.0, SeatLayout.DESK_DEPTH - 4.0, leg_w, 14.0), leg_color)


func _draw_monitor(layer: CanvasItem) -> void:
	# 显示器：位于桌面中央靠后
	var mw := 62.0
	var mh := 40.0
	var mx := (SeatLayout.DESK_WIDTH - mw) * 0.5
	var my := 8.0
	# 屏幕外框
	layer.draw_rect(Rect2(mx, my, mw, mh), Color("#2a2a2a"))
	# 屏幕
	layer.draw_rect(Rect2(mx + 3.0, my + 3.0, mw - 6.0, mh - 6.0), Color("#3a6ea5"))
	# 屏幕反光
	layer.draw_rect(Rect2(mx + 5.0, my + 5.0, 10.0, 4.0), Color(1, 1, 1, 0.25))
	# 支架
	layer.draw_rect(Rect2(mx + mw * 0.5 - 4.0, my + mh, 8.0, 10.0), Color("#333333"))
	# 底座
	layer.draw_rect(Rect2(mx + mw * 0.5 - 12.0, my + mh + 10.0, 24.0, 4.0), Color("#333333"))


func apply_snapshot_seat(seat_data: Dictionary) -> void:
	# 前向兼容：根据引擎快照更新该工位员工
	var employee_id: Variant = seat_data.get("employee_id", null)
	var nickname_val: Variant = seat_data.get("nickname", null)
	if employee_id != null and employee_id != "":
		employee.set_nickname(str(nickname_val) if nickname_val != null else "员工")
		# 有员工时保持睡觉动画；未来可在此切换动作
	else:
		employee.set_nickname("员工%02d" % seat_index)
