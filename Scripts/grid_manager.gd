# GridManager.gd — 网格系统 + 地形占地登记 (M0)
# Autoload — 全场景统一网格：吸附、地形足迹登记/互斥、空位搜索
extends Node
class_name GridManager

# ============================================================
# 网格常量（与卡牌面板尺寸一致）
# ============================================================
const CELL_W := 80.0
const CELL_H := 100.0

# ============================================================
# 内部状态
# ============================================================
## 地形足迹：TerrainCard → Rect2i（左上角格 + w×h）
var _terrain_footprints: Dictionary = {}
## 格占用表：Vector2i → TerrainCard（该格被哪张地形占）
var _cell_owner: Dictionary = {}

# ============================================================
# 坐标换算
# ============================================================
func world_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(roundi(pos.x / CELL_W), roundi(pos.y / CELL_H))

func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * CELL_W, cell.y * CELL_H)

## 吸附到最近格点（返回格中心世界坐标）
func snap_to_grid(pos: Vector2) -> Vector2:
	var cell := world_to_cell(pos)
	return cell_to_world(cell)

## 吸附为整数格（用于地形足迹登记）
func snap_to_cell(pos: Vector2) -> Vector2i:
	return world_to_cell(pos)

# ============================================================
# 地形足迹登记 / 注销
# ============================================================
## 地形卡放置时登记足迹（覆盖 w×h 格，锚点为左上角格）
## 返回 true 表示登记成功；false 表示格子已被其他地形占用
func register_terrain_footprint(terrain: Node, size_w: int, size_h: int, origin_cell: Vector2i) -> bool:
	# 先试占所有格，若有冲突则整体拒绝（保持地形占用原子性）
	var rect := Rect2i(origin_cell, Vector2i(size_w, size_h))
	var conflict := false
	for x in range(rect.position.x, rect.position.x + rect.size.x):
		for y in range(rect.position.y, rect.position.y + rect.size.y):
			var cell := Vector2i(x, y)
			if _cell_owner.has(cell) and _cell_owner[cell] != terrain:
				conflict = true
				break
		if conflict:
			break

	if conflict:
		return false

	# 清除旧的足迹（若有）
	if _terrain_footprints.has(terrain):
		_release_footprint(terrain)

	# 占用新格
	for x in range(rect.position.x, rect.position.x + rect.size.x):
		for y in range(rect.position.y, rect.position.y + rect.size.y):
			_cell_owner[Vector2i(x, y)] = terrain
	_terrain_footprints[terrain] = rect
	return true

## 释放地形占用的所有格
func release_terrain_footprint(terrain: Node) -> void:
	_release_footprint(terrain)

func _release_footprint(terrain: Node) -> void:
	if not _terrain_footprints.has(terrain):
		return
	var rect: Rect2i = _terrain_footprints[terrain]
	for x in range(rect.position.x, rect.position.x + rect.size.x):
		for y in range(rect.position.y, rect.position.y + rect.size.y):
			_cell_owner.erase(Vector2i(x, y))
	_terrain_footprints.erase(terrain)

## 查询某格是否已被地形占用；返回地形卡或 null
func get_terrain_at_cell(cell: Vector2i) -> Node:
	return _cell_owner.get(cell)

## 查询某格是否被占用（地形或静态内容物）
func is_cell_occupied(cell: Vector2i) -> bool:
	return _cell_owner.has(cell)

# ============================================================
# 空位搜索（用于新合成地形跳跃、产物落位）
# ============================================================
## 从 start_cell 起螺旋外扩，找第一处能容纳 w×h 且不被地形占用的区域
## 返回区域左上角格；找不到返回 Vector2i(-1,-1)
func find_empty_area(start_cell: Vector2i, w: int, h: int, max_radius: int = 8) -> Vector2i:
	for radius in range(0, max_radius + 1):
		for y in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				if max(abs(x), abs(y)) != radius:
					continue
				var origin := start_cell + Vector2i(x, y)
				if _can_fit(origin, w, h):
					return origin
	return Vector2i(-1, -1)

func _can_fit(origin: Vector2i, w: int, h: int) -> bool:
	for x in range(origin.x, origin.x + w):
		for y in range(origin.y, origin.y + h):
			if _cell_owner.has(Vector2i(x, y)):
				return false
	return true

## 原地形的足迹（用于"优先复用"空位搜索）
func get_footprint(terrain: Node) -> Rect2i:
	return _terrain_footprints.get(terrain, Rect2i())