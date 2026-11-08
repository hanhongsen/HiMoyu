class_name OfficeBackground
extends Node2D
## 办公室背景：地板、墙壁、管理层办公室（左上玻璃房）、会议室（右侧）。
##
## 纯程序化绘制，不依赖外部贴图。位于所有工位之下（z_index = -100）。

const VIEW_W := 1920.0
const VIEW_H := 1080.0


func _ready() -> void:
	z_index = -100
	queue_redraw()


func _draw() -> void:
	# 地板
	var floor := Color("#e8ddd0")
	draw_rect(Rect2(0, 0, VIEW_W, VIEW_H), floor)

	# 地板木纹（横向线条）
	var wood_line := Color("#d8c9b8")
	for y in range(0, int(VIEW_H), 48):
		draw_line(Vector2(0, y), Vector2(VIEW_W, y), wood_line, 1.0)

	# 后墙（顶部一条）
	var wall_h := 90.0
	draw_rect(Rect2(0, 0, VIEW_W, wall_h), Color("#c9b89a"))
	# 踢脚线
	draw_rect(Rect2(0, wall_h - 6.0, VIEW_W, 6.0), Color("#9a8466"))

	# 左侧墙
	draw_rect(Rect2(0, 0, 40.0, VIEW_H), Color("#d4c4a8"))
	# 右侧墙
	draw_rect(Rect2(VIEW_W - 40.0, 0, 40.0, VIEW_H), Color("#d4c4a8"))

	# 窗户装饰（后墙）—— 先画，标题覆盖在上方
	_draw_windows()

	# 顶部办公室名牌
	var title_color := Color("#3a2e22")
	var font := ThemeDB.fallback_font
	draw_string(
		font,
		Vector2(VIEW_W * 0.5 - 180.0, 58.0),
		"HiMoyu · AI 摸鱼办公室",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		30,
		title_color
	)

	# 左上：管理层办公室（玻璃房）
	_draw_management_room()

	# 右侧：会议室
	_draw_meeting_room()


func _draw_management_room() -> void:
	# 玻璃房，位于左上，靠后墙
	var rx := 50.0
	var ry := 100.0
	var rw := 360.0
	var rh := 160.0
	# 玻璃
	draw_rect(Rect2(rx, ry, rw, rh), Color(0.75, 0.88, 0.95, 0.35))
	# 玻璃框
	var frame := Color("#5a6a7a")
	draw_rect(Rect2(rx, ry, rw, 4.0), frame)
	draw_rect(Rect2(rx, ry + rh - 4.0, rw, 4.0), frame)
	draw_rect(Rect2(rx, ry, 4.0, rh), frame)
	draw_rect(Rect2(rx + rw - 4.0, ry, 4.0, rh), frame)
	# 中间竖框
	draw_rect(Rect2(rx + rw * 0.5 - 2.0, ry, 4.0, rh), frame)
	# 铭牌
	draw_rect(Rect2(rx + 16.0, ry + 14.0, 100.0, 24.0), Color("#5a6a7a"))
	draw_string(
		ThemeDB.fallback_font,
		Vector2(rx + 24.0, ry + 32.0),
		"管理层",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		16,
		Color("#ffffff")
	)
	# 里面的小桌子
	draw_rect(Rect2(rx + 60.0, ry + rh - 50.0, 120.0, 14.0), Color("#b5895a"))
	draw_rect(Rect2(rx + 60.0, ry + rh - 36.0, 120.0, 4.0), Color("#8a6440"))


func _draw_meeting_room() -> void:
	# 右侧会议室区域
	var rx := VIEW_W - 360.0
	var ry := 100.0
	var rw := 320.0
	var rh := 160.0
	# 地毯
	draw_rect(Rect2(rx, ry, rw, rh), Color("#b8a8c8", 0.5))
	# 会议桌
	var tw := 180.0
	var th := 60.0
	var tx := rx + (rw - tw) * 0.5
	var ty := ry + (rh - th) * 0.5
	draw_rect(Rect2(tx, ty, tw, th), Color("#a07850"))
	draw_rect(Rect2(tx, ty + th - 4.0, tw, 4.0), Color("#7a5a38"))
	# 椅子（两侧）
	var chair_color := Color("#5a4a3a")
	for i in range(3):
		var cx := tx + 20.0 + i * 50.0
		draw_rect(Rect2(cx, ty - 16.0, 30.0, 12.0), chair_color)
		draw_rect(Rect2(cx, ty + th + 4.0, 30.0, 12.0), chair_color)
	# 铭牌
	draw_rect(Rect2(rx + 16.0, ry + 14.0, 80.0, 24.0), Color("#6a5a8a"))
	draw_string(
		ThemeDB.fallback_font,
		Vector2(rx + 26.0, ry + 32.0),
		"会议室",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		16,
		Color("#ffffff")
	)


func _draw_windows() -> void:
	# 后墙上的几扇窗
	var win_y := 24.0
	var win_h := 44.0
	var win_w := 120.0
	var gap := 80.0
	var start_x := 460.0
	var frame := Color("#4a5a6a")
	var glass := Color(0.7, 0.85, 0.95, 0.6)
	for i in range(5):
		var x := start_x + i * (win_w + gap)
		draw_rect(Rect2(x, win_y, win_w, win_h), frame)
		draw_rect(Rect2(x + 3.0, win_y + 3.0, win_w - 6.0, win_h - 6.0), glass)
		# 十字窗格
		draw_rect(Rect2(x + win_w * 0.5 - 1.5, win_y + 3.0, 3.0, win_h - 6.0), frame)
		draw_rect(Rect2(x + 3.0, win_y + win_h * 0.5 - 1.5, win_w - 6.0, 3.0), frame)
