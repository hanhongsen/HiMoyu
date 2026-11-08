class_name Office
extends Node2D
## 办公室地图：创建 25 个工位并绑定预览员工，负责接收引擎快照。

const Desk := preload("res://scenes/office/desk.gd")
const SeatLayout := preload("res://config/seat_layout.gd")

var _desks: Array[Desk] = []


func _ready() -> void:
	for i in range(1, SeatLayout.SEAT_COUNT + 1):
		var desk := Desk.new()
		desk.position = SeatLayout.desk_rect(i).position
		add_child(desk)
		desk.setup(i)
		_desks.append(desk)


func apply_snapshot(snapshot: Dictionary) -> void:
	# 根据引擎快照更新各工位员工（前向兼容）
	var seats: Array = snapshot.get("seats", [])
	for i in range(mini(seats.size(), _desks.size())):
		var seat: Variant = seats[i]
		if typeof(seat) == TYPE_DICTIONARY:
			_desks[i].apply_snapshot_seat(seat)
