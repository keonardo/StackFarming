# DragPreview.gd — 拖拽落位预览（棋盘格视觉提示）
# 挂在 grid 层之上(z_index=1000)，非交互，只画提示框
extends Node2D
class_name DragPreview

# ============================================================
# 配置
# ============================================================
const CELL_W := 80.0
const CELL_H := 100.0

# ============================================================
# 状态
# ============================================================
var _active: bool = false
var _origin_cell: Vector2i = Vector2i.ZERO  # 预览占位左上角格
var _size_cells: Vector2i = Vector2i(1, 1) # 占位尺寸(w×h 格)
var _valid: bool = true                      # 是否可放置（无冲突）

# ============================================================
# Public API
# ============================================================
func show_preview(cell_origin: Vector2i, size: Vector2i, valid: bool) -> void:
	_active = true
	_origin_cell = cell_origin
	_size_cells = Vector2i(maxi(size.x, 1), maxi(size.y, 1))
	_valid = valid
	queue_redraw()

func hide_preview() -> void:
	if not _active:
		return
	_active = false
	queue_redraw()

func is_active() -> bool:
	return _active

# ============================================================
# 绘制
# ============================================================
func _draw() -> void:
	if not _active:
		return

	var top_left: Vector2 = Vector2(_origin_cell.x * CELL_W, _origin_cell.y * CELL_H)
	var size := Vector2(_size_cells.x * CELL_W, _size_cells.y * CELL_H)

	# 半透明填充
	if _valid:
		draw_rect(Rect2(top_left, size), Color(0.3, 1.0, 0.4, 0.25), true)
		draw_rect(Rect2(top_left, size), Color(0.6, 1.0, 0.7, 0.9), false, 2.0)
	else:
		draw_rect(Rect2(top_left, size), Color(1.0, 0.3, 0.3, 0.3), true)
		draw_rect(Rect2(top_left, size), Color(1.0, 0.4, 0.4, 0.95), false, 2.5)

	# 内部格线（多格时）：帮玩家看清占了几格
	if _size_cells.x > 1 or _size_cells.y > 1:
		for x in range(1, _size_cells.x):
			draw_line(top_left + Vector2(x * CELL_W, 0), top_left + Vector2(x * CELL_W, size.y), Color(1, 1, 1, 0.3), 1.0)
		for y in range(1, _size_cells.y):
			draw_line(top_left + Vector2(0, y * CELL_H), top_left + Vector2(size.x, y * CELL_H), Color(1, 1, 1, 0.3), 1.0)