class_name SeatLayout
extends RefCounted
## 工位布局的集中配置。
##
## 与 src/engine/app/config.py 中的 SEAT_COUNT / SEAT_ROWS / SEAT_COLS 保持一致。
## 所有工位坐标都从这里计算，避免在多个脚本中硬编码。
## index 采用 1..25，与引擎 SeatState.index 对齐。

# 工位总数与网格
const SEAT_COUNT := 25
const GRID_COLS := 5
const GRID_ROWS := 5

# 单个工位尺寸
const DESK_WIDTH := 176.0
const DESK_DEPTH := 104.0

# 工位间距
const GAP_X := 36.0
const GAP_Y := 44.0

# 网格左上角原点（在 1920×1080 视口中居中布置员工区）
const GRID_ORIGIN_X := 448.0
const GRID_ORIGIN_Y := 200.0

# 员工在工位中的相对位置（相对工位左上角）
# 员工坐在桌子后方，身体上半部分露出桌面。
# 员工原点与桌面顶边对齐，便于头部在桌面上方、手臂在桌面上方绘制。
const EMPLOYEE_OFFSET_X := DESK_WIDTH * 0.5
const EMPLOYEE_OFFSET_Y := 0.0


static func desk_rect(index: int) -> Rect2:
	# index: 1..25
	var i: int = clamp(index - 1, 0, SEAT_COUNT - 1)
	var col: int = i % GRID_COLS
	var row: int = i / GRID_COLS
	var x: float = GRID_ORIGIN_X + col * (DESK_WIDTH + GAP_X)
	var y: float = GRID_ORIGIN_Y + row * (DESK_DEPTH + GAP_Y)
	return Rect2(x, y, DESK_WIDTH, DESK_DEPTH)


static func desk_center(index: int) -> Vector2:
	return desk_rect(index).position + Vector2(DESK_WIDTH * 0.5, DESK_DEPTH * 0.5)


static func desk_top_center(index: int) -> Vector2:
	# 桌面顶边中点，用于放置员工
	var rect := desk_rect(index)
	return rect.position + Vector2(DESK_WIDTH * 0.5, 0.0)


static func employee_position(index: int) -> Vector2:
	var rect := desk_rect(index)
	return rect.position + Vector2(EMPLOYEE_OFFSET_X, EMPLOYEE_OFFSET_Y)


static func grid_total_size() -> Vector2:
	var w := GRID_COLS * DESK_WIDTH + (GRID_COLS - 1) * GAP_X
	var h := GRID_ROWS * DESK_DEPTH + (GRID_ROWS - 1) * GAP_Y
	return Vector2(w, h)
