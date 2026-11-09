"""HiMoyu 本地 Demo 配置。

阶段 2A 新增员工入职规则常量（集中管理，方便后续调整）。
"""

APP_NAME = "HiMoyu Local Engine"
APP_VERSION = "0.2.0"

HOST = "127.0.0.1"
PORT = 8000

# 办公室固定工位：01—25，5 行 × 5 列
SEAT_COUNT = 25
SEAT_ROWS = 5
SEAT_COLS = 5

# ---------- 阶段 2A 员工入职规则 ----------

# 最大员工数量（等于固定工位数）
MAX_EMPLOYEES = 25

# 点赞入职阈值：同一用户累计达到 10 个有效点赞即可入职
LIKE_ENTRY_THRESHOLD = 10

# 评论入职关键词（去空格后精确匹配）
COMMENT_ENTRY_KEYWORD = "入职"

# 模拟入职礼物 ID（后续接入抖音时替换为真实礼物 ID）
ENTRY_GIFT_ID = "demo_entry_gift"

# 模拟入职礼物显示名称（仅用于模拟台和日志）
ENTRY_GIFT_NAME = "入职礼物（模拟）"

# 昵称长度上限（防止 Godot 画面溢出）
NICKNAME_MAX_LENGTH = 16

# 员工 ID 前缀
EMPLOYEE_ID_PREFIX = "emp_"
