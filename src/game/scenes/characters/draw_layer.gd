class_name DrawLayer
extends Node2D
## 轻量绘制层：将自身作为 CanvasItem 传入回调，
## 使父节点的绘制逻辑能在正确的节点上下文中执行 draw_* 调用。

var draw_callback: Callable


func _draw() -> void:
	if draw_callback.is_valid():
		draw_callback.call(self)
