"""HiMoyu 本地 Demo 配置。

阶段 0 只放运行参数；玩法阈值、时长、权重和礼物映射在后续阶段
按产品文档逐项加入，统一集中在本文件，避免散落在业务代码中。
"""

APP_NAME = "HiMoyu Local Engine"
APP_VERSION = "0.1.0"

HOST = "127.0.0.1"
PORT = 8000

# 办公室固定工位：01—25，5 行 × 5 列
SEAT_COUNT = 25
SEAT_ROWS = 5
SEAT_COLS = 5
