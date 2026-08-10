# IrrigationManager.gd — 水流传导系统 (v1)
# Autoload — 维护地貌卡水网图，处理滋润传导、翻塘判定
extends Node
class_name IrrigationManager

# ============================================================
# Signals — 驱动视觉层
# ============================================================
## 滋润传导发生时发射（source→target，传导量）
signal moisture_flow(source: TerrainCard, target: TerrainCard, amount: float)
## 水网连接变化（用于连线显示更新）
signal flow_network_changed()

# ============================================================
# 导出配置
# ============================================================
@export_group("🌊 传导参数")
@export var update_interval: float = 2.0            ## 图重建+传导间隔（秒）
@export var connection_range: float = 250.0         ## 两张地貌卡距离 ≤ 此值即视为水网相连（px）
@export var flow_rate: float = 5.0                  ## 每秒传导滋润量
@export var fish_pond_supplies_water: bool = false  ## 鱼塘是否对外供水（默认否，鱼塘自用）

@export_group("☣️ 翻塘参数")
@export var eutrophication_feces_threshold: int = 3  ## 粪便数量阈值
@export var eutrophication_warning_time: float = 10.0 ## 警告持续多久后触发翻塘

# ============================================================
# 内部状态
# ============================================================
var _terrains: Array[TerrainCard] = []               # 所有已注册地貌卡
var _adjacency: Dictionary = {}                       # TerrainCard → Array[TerrainCard]
var _eutrophication_timers: Dictionary = {}           # TerrainCard → float (警告累计秒数)
var _flow_timer: float = 0.0                          # 传导计时器
var _dirty: bool = true                               # 下次 tick 强制重建图

# ============================================================
# 注册 / 注销
# ============================================================
func register_terrain(terrain: TerrainCard) -> void:
	if terrain in _terrains:
		return
	_terrains.append(terrain)
	_dirty = true
	print("[IrrigationManager] + ", terrain.card_name, " (", terrain.get_instance_id(), ") registered. Total: ", _terrains.size())

func unregister_terrain(terrain: TerrainCard) -> void:
	var idx := _terrains.find(terrain)
	if idx >= 0:
		_terrains.remove_at(idx)
	_adjacency.erase(terrain)
	_eutrophication_timers.erase(terrain)
	# 从其他卡的邻接表中移除
	for key in _adjacency.keys():
		var arr: Array = _adjacency[key]
		arr.erase(terrain)
	_dirty = true
	print("[IrrigationManager] - ", terrain.card_name, " unregistered. Total: ", _terrains.size())

# ============================================================
# 主循环
# ============================================================
func _process(delta: float) -> void:
	_flow_timer += delta
	if _flow_timer >= update_interval or _dirty:
		var effective_delta := _flow_timer
		_flow_timer = 0.0
		_dirty = false
		_rebuild_adjacency()
		_process_flow(effective_delta)
		_check_eutrophication(effective_delta)

# ============================================================
# 邻接图构建（基于 Area2D 空间重叠）
# ============================================================
func _rebuild_adjacency() -> void:
	_adjacency.clear()
	# 清理已失效引用
	_terrains = _terrains.filter(func(t: TerrainCard): return is_instance_valid(t))

	for i in range(_terrains.size()):
		var a := _terrains[i] as TerrainCard
		if not is_instance_valid(a):
			continue
		for j in range(i + 1, _terrains.size()):
			var b := _terrains[j] as TerrainCard
			if not is_instance_valid(b):
				continue
			if _check_adjacent(a, b):
				if not _adjacency.has(a): _adjacency[a] = []
				if not _adjacency.has(b): _adjacency[b] = []
				_adjacency[a].append(b)
				_adjacency[b].append(a)

	flow_network_changed.emit()
	var pairs := _count_adjacent_pairs()
	print("[IrrigationManager] Graph rebuilt: ", _terrains.size(), " terrains, ", pairs, " connections")

func _check_adjacent(a: TerrainCard, b: TerrainCard) -> bool:
	var dist := a.global_position.distance_to(b.global_position)
	return dist <= connection_range

func _get_neighbors(terrain: TerrainCard) -> Array[TerrainCard]:
	var arr: Array = _adjacency.get(terrain, [])
	var result: Array[TerrainCard] = []
	for t in arr:
		if is_instance_valid(t):
			result.append(t as TerrainCard)
	return result

func _pair_key(a: TerrainCard, b: TerrainCard) -> String:
	var id_a := a.get_instance_id()
	var id_b := b.get_instance_id()
	return "%d-%d" % [mini(id_a, id_b), maxi(id_a, id_b)]

func _count_adjacent_pairs() -> int:
	var seen: Dictionary = {}
	for t in _adjacency.keys():
		for n in _adjacency[t]:
			seen[_pair_key(t, n)] = true
	return seen.size()

# ============================================================
# 滋润传导
# ============================================================
func _process_flow(effective_delta: float) -> void:
	var processed: Dictionary = {}  # 每对地貌只处理一次

	for terrain in _terrains:
		if not is_instance_valid(terrain):
			continue
		for neighbor in _get_neighbors(terrain):
			var pk := _pair_key(terrain, neighbor)
			if processed.has(pk):
				continue
			processed[pk] = true

			# 水源 → 水田
			if terrain.is_water_terrain() and neighbor.type == CardEnums.CardType.PADDY_FIELD:
				_flow_water_to_paddy(terrain, neighbor, effective_delta)
			elif neighbor.is_water_terrain() and terrain.type == CardEnums.CardType.PADDY_FIELD:
				_flow_water_to_paddy(neighbor, terrain, effective_delta)

			# 水田 ↔ 水田（高→低均衡）
			elif terrain.type == CardEnums.CardType.PADDY_FIELD and neighbor.type == CardEnums.CardType.PADDY_FIELD:
				_balance_paddy_pair(terrain, neighbor, effective_delta)

func _flow_water_to_paddy(source: TerrainCard, paddy: TerrainCard, effective_delta: float) -> void:
	# 鱼塘默认不对外供水
	if source.type == CardEnums.CardType.FISH_POND and not fish_pond_supplies_water:
		return

	var amount := flow_rate * effective_delta
	if paddy.moisture >= 100.0:
		return

	paddy.moisture = min(100.0, paddy.moisture + amount)
	moisture_flow.emit(source, paddy, amount)

func _balance_paddy_pair(a: TerrainCard, b: TerrainCard, effective_delta: float) -> void:
	var diff := a.moisture - b.moisture
	if abs(diff) < 1.0:
		return

	var max_transfer: float = flow_rate * effective_delta
	var transfer: float = clamp(diff * 0.3, -max_transfer, max_transfer)

	a.moisture = max(0.0, a.moisture - transfer)
	b.moisture = min(100.0, b.moisture + transfer)

	if transfer > 0:
		moisture_flow.emit(a, b, transfer)

# ============================================================
# 翻塘判定（富营养化 → 鱼全灭）
# ============================================================
func _check_eutrophication(effective_delta: float) -> void:
	for terrain in _terrains:
		if not is_instance_valid(terrain):
			continue
		# 仅检测水域类地貌
		if not terrain.is_water_terrain():
			continue

		var feces_count := terrain.count_children_of_type(CardEnums.CardType.FECES)
		var has_plants := _terrain_has_plants(terrain)

		if feces_count >= eutrophication_feces_threshold and not has_plants:
			var elapsed: float = _eutrophication_timers.get(terrain, 0.0) + effective_delta
			_eutrophication_timers[terrain] = elapsed

			if elapsed >= eutrophication_warning_time:
				# 💀 翻塘触发
				_trigger_eutrophication(terrain)
				_eutrophication_timers[terrain] = 0.0
		else:
			if _eutrophication_timers.has(terrain):
				_eutrophication_timers.erase(terrain)

func _terrain_has_plants(terrain: TerrainCard) -> bool:
	for c in terrain.get_stack_chain():
		if c.type in [CardEnums.CardType.WILD_RICE_SEED, CardEnums.CardType.WATER_CALTROP]:
			return true
	return false

func _trigger_eutrophication(terrain: TerrainCard) -> void:
	var fish_list: Array[BaseCard] = []
	for c in terrain.get_stack_chain():
		if c.type == CardEnums.CardType.FISH and is_instance_valid(c):
			fish_list.append(c)

	if fish_list.is_empty():
		print("[IrrigationManager] ⚠️ 翻塘警告 on ", terrain.card_name, " — 但该地块无鱼，跳过")
		return

	print("[IrrigationManager] 💀 翻塘！", terrain.card_name, " 富营养化 — ", fish_list.size(), " 条鱼全灭")
	for fish in fish_list:
		fish.health = 0.0  # 触发 BaseCard 死亡序列

# ============================================================
# 公开查询 API
# ============================================================

## 获取所有已注册地貌卡
func get_all_terrains() -> Array[TerrainCard]:
	_terrains = _terrains.filter(func(t: TerrainCard): return is_instance_valid(t))
	return _terrains.duplicate()

## 在指定位置范围内查找水源（池塘/大水塘）
func get_water_sources_near(position: Vector2, max_range: float) -> Array[TerrainCard]:
	var result: Array[TerrainCard] = []
	for t in _terrains:
		if not is_instance_valid(t):
			continue
		if t.type in [CardEnums.CardType.POND, CardEnums.CardType.BIG_POND]:
			if position.distance_to(t.global_position) <= max_range:
				result.append(t)
	return result

## 检查指定位置范围内是否有水源
func has_water_source_near(position: Vector2, max_range: float) -> bool:
	return not get_water_sources_near(position, max_range).is_empty()

## 获取与指定地块有水网连接的邻居
func get_flow_neighbors(terrain: TerrainCard) -> Array[TerrainCard]:
	return _get_neighbors(terrain)

## 获取从指定地块出发的"水流连接"（用于绘制连线）
## 返回: Array[Dictionary] — [{from: TerrainCard, to: TerrainCard, type: "water"|"balance"}]
func get_flow_connections_for(terrain: TerrainCard) -> Array:
	var result: Array = []
	var seen: Dictionary = {}

	for neighbor in _get_neighbors(terrain):
		if seen.has(neighbor):
			continue
		seen[neighbor] = true

		var flow_type := ""
		if terrain.is_water_terrain() and neighbor.type == CardEnums.CardType.PADDY_FIELD:
			flow_type = "water"
		elif neighbor.is_water_terrain() and terrain.type == CardEnums.CardType.PADDY_FIELD:
			flow_type = "water"
		elif terrain.type == CardEnums.CardType.PADDY_FIELD and neighbor.type == CardEnums.CardType.PADDY_FIELD:
			flow_type = "balance"
		else:
			continue

		result.append({"from": terrain, "to": neighbor, "type": flow_type})

	return result
