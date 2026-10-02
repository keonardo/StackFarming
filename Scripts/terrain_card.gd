# TerrainCard.gd — 地貌卡牌基类，委托行为到 behaviors/terrain_bhv.gd
extends BaseCard
class_name TerrainCard

@export var is_irrigated: bool = false

## M1 地形尺寸（w×h 格），由类型查表
var terrain_size: Vector2i = Vector2i(1, 1)

const TERRAIN_SIZES := {
	CardEnums.CardType.POND:        Vector2i(2, 2),
	CardEnums.CardType.BIG_POND:    Vector2i(3, 2),
	CardEnums.CardType.FISH_POND:   Vector2i(3, 3),
	CardEnums.CardType.PADDY_FIELD: Vector2i(2, 2),
}

# ── M2 容器系统 ──
## 格位占用：相对格 Vector2i → 内容物卡（静态内容物占格）
var _slots: Dictionary = {}
## 反向映射：内容物卡 → 相对格 Vector2i
var _slot_owner: Dictionary = {}

var _bhv: TerrainBehavior = null

func _ready() -> void:
	super._ready()
	role = CardEnums.CardRole.TERRAIN
	terrain_size = TERRAIN_SIZES.get(type, Vector2i(1, 1))
	_resize_visual(terrain_size)
	match type:
		CardEnums.CardType.POND, CardEnums.CardType.BIG_POND, CardEnums.CardType.FISH_POND:
			is_irrigated = true
		_:
			is_irrigated = false
	_bhv = TerrainBehavior.new(self, get_node("/root/GameConfig"))
	on_card_stacked.connect(_on_stacked)

	# 注册到水流传导系统
	var im := get_node_or_null("/root/IrrigationManager") as IrrigationManager
	if im:
		im.register_terrain(self)

	# M1 登记网格足迹（位置已由 spawner 设定；初始冲突走跳跃语义，不是拖动回弹）
	call_deferred("_setup_grid_footprint", false)

## 按地形尺寸展开视觉：Panel 从左上角顶点向右下展开（与全局棋盘格求重合）
func _resize_visual(sz: Vector2i) -> void:
	var w_px := sz.x * 80.0
	var h_px := sz.y * 100.0

	# Panel = 容器表面，从 (0,0) 覆盖到 (w_px, h_px)
	var panel := get_node_or_null("Panel") as Control
	if panel:
		panel.offset_left = 0
		panel.offset_top = 0
		panel.offset_right = w_px
		panel.offset_bottom = h_px
		# 容器表面底色（水域蓝 / 农田绿等）
		var sb := StyleBoxFlat.new()
		sb.bg_color = _container_tint()
		sb.set_corner_radius_all(8)
		sb.border_color = Color(1, 1, 1, 0.25)
		sb.set_border_width_all(2)
		panel.add_theme_stylebox_override("panel", sb)

	# Collision 放大：节点锚点 = 左上顶点，shape 平移到面板中心对齐
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node and shape_node.shape is RectangleShape2D:
		(shape_node.shape as RectangleShape2D).size = Vector2(w_px, h_px)
		shape_node.position = Vector2(w_px * 0.5, h_px * 0.5)

	# 标签重摆到容器顶栏（不随格子拉伸）
	_layout_labels(panel, w_px)

	# 画格线
	queue_redraw()

## 地形底色：按水域/农田着色
func _container_tint() -> Color:
	match type:
		CardEnums.CardType.POND, CardEnums.CardType.BIG_POND, CardEnums.CardType.FISH_POND:
			return Color(0.12, 0.35, 0.75, 0.35)
		CardEnums.CardType.PADDY_FIELD:
			return Color(0.35, 0.55, 0.20, 0.30)
		_:
			return Color(0.5, 0.45, 0.30, 0.30)

## 标签集中到容器顶部
func _layout_labels(panel: Control, w_px: float) -> void:
	if panel == null:
		return
	var name_lbl := panel.get_node_or_null("NameLabel") as Label
	if name_lbl:
		name_lbl.offset_left = 6
		name_lbl.offset_right = w_px - 6
		name_lbl.offset_top = 4
		name_lbl.offset_bottom = 26

## M2 容器格线绘制：容器边缘实线 + 内部格线虚线（原点 = 左上角顶点）
func _draw() -> void:
	var sz := terrain_size
	if sz.x <= 0 or sz.y <= 0:
		return
	var w := sz.x * 80.0
	var h := sz.y * 100.0
	var o := Vector2.ZERO

	# 内部格线（浅灰，隐约表现棋盘格）
	var line := Color(1, 1, 1, 0.10)
	for x in range(1, sz.x):
		draw_line(o + Vector2(x * 80.0, 0), o + Vector2(x * 80.0, h), line, 1.5)
	for y in range(1, sz.y):
		draw_line(o + Vector2(0, y * 100.0), o + Vector2(w, y * 100.0), line, 1.5)

	# 容器边缘强调框
	draw_rect(Rect2(o, Vector2(w, h)), Color(1, 1, 1, 0.18), false, 2.0)

func _process(delta: float) -> void:
	super._process(delta)
	if not is_instance_valid(self): return
	if _bhv: _bhv.process(delta)

func _exit_tree() -> void:
	var im := get_node_or_null("/root/IrrigationManager") as IrrigationManager
	if im:
		im.unregister_terrain(self)
	# M1 释放网格足迹
	var gm := get_node_or_null("/root/GridManager") as GridManager
	if gm:
		gm.release_terrain_footprint(self)

# ── M1 网格足迹 ──
## 登记足迹。拖拽落位(is_drag_placement=true)冲突 → 回弹原位（禁止重叠）；
## 合成跳跃(false)冲突 → 就近空位展开。返回是否成功落地
func _setup_grid_footprint(is_drag_placement: bool = true) -> bool:
	var gm := get_node_or_null("/root/GridManager") as GridManager
	if gm == null:
		return false
	var origin: Vector2i = _origin_cell()
	var ok: bool = gm.register_terrain_footprint(self, terrain_size.x, terrain_size.y, origin)

	if not ok:
		if is_drag_placement:
			# 玩家拖动落位：格被占用 → 直接回弹原位，不允许重叠
			_rollback_to_pre_drag()
			return false
		# 新合成地形跳跃：就近找空位展开
		var free: Vector2i = gm.find_empty_area(origin, terrain_size.x, terrain_size.y)
		if free != Vector2i(-1, -1):
			gm.register_terrain_footprint(self, terrain_size.x, terrain_size.y, free)
			global_position = gm.cell_to_world(free)
			return true
	return ok

## 回弹到拖动前位置（含足迹重登记；若原位不可用则放弃）
func _rollback_to_pre_drag() -> void:
	var gm := get_node_or_null("/root/GridManager") as GridManager
	if gm == null:
		return
	global_position = _pre_drag_pos
	var origin: Vector2i = _origin_cell()
	gm.register_terrain_footprint(self, terrain_size.x, terrain_size.y, origin)

## 释放当前足迹（拖动/移除前调用）
func _release_grid_footprint() -> void:
	var gm := get_node_or_null("/root/GridManager") as GridManager
	if gm:
		gm.release_terrain_footprint(self)

func _on_stacked(stacked_card: BaseCard, _target: BaseCard) -> void:
	if _bhv and _bhv.on_card_stacked(stacked_card): return
	call_deferred("_check_stack_recipes")

# ── Stack recipes ──
func _check_stack_recipes() -> void:
	if not is_instance_valid(self): return
	if type == CardEnums.CardType.POND:
		for card in get_stack_chain():
			if card != self and card.type == CardEnums.CardType.POND:
				_merge_pond(card); return
	if type == CardEnums.CardType.BIG_POND:
		if count_children_of_type(CardEnums.CardType.FISH) >= 2:
			_merge_fish_pond()

func _merge_pond(second: BaseCard) -> void:
	var pos: Vector2 = global_position
	# 收集两个地形的内容物（_slot_owner），统一脱离后并入新地形
	var kids: Array = []
	kids.append_array(get_contents())
	if second is TerrainCard:
		kids.append_array((second as TerrainCard).get_contents())
	# 脱离栈关系（self/second 之间）
	if stack_parent != null:
		_detach_from_parent(stack_parent)
	if second.stack_parent != null:
		second._detach_from_parent(second.stack_parent)
	# 内容物全部脱离（容器+栈）
	for c in kids:
		if is_instance_valid(c):
			c._detach_all_relations()
	second.queue_free()
	queue_free()
	if CardSpawner.instance:
		var bp: BaseCard = CardSpawner.instance.spawn_card(CardEnums.CardType.BIG_POND, "大水塘", pos)
		if bp:
			for c in kids:
				if is_instance_valid(c):
					c.call_deferred("enter_container", bp as TerrainCard)

func _merge_fish_pond() -> void:
	var pos: Vector2 = global_position
	var fish_ate: int = 0; var kids: Array = []
	for c in get_contents():
		if c.type == CardEnums.CardType.FISH and fish_ate < 2:
			fish_ate += 1; c.queue_free()
		elif is_instance_valid(c):
			kids.append(c)
	# 脱离栈关系 + 内容物脱离
	if stack_parent != null:
		_detach_from_parent(stack_parent)
	for c in kids:
		if is_instance_valid(c):
			c._detach_all_relations()
	queue_free()
	if CardSpawner.instance:
		var fp: BaseCard = CardSpawner.instance.spawn_card(CardEnums.CardType.FISH_POND, "鱼塘", pos)
		if fp:
			for c in kids:
				if is_instance_valid(c):
					c.call_deferred("enter_container", fp as TerrainCard)

## 内容物进入容器的通知（承接 region 的 on_card_stacked 信号链路）
func notify_content_added(card: BaseCard) -> void:
	# 触发 on_card_stacked，供 terrain_bhv 处理（粪便/水/肥料叠上水田等）
	on_card_stacked.emit(card, self)
	# 触发堆叠配方检查（如池塘+什么呢，供未来扩展）
	call_deferred("_check_stack_recipes")

## 覆写：容器链 = self + 所有格位内容物（每个内容物自身可继续叠子链）
## 注：总纲 §5 —— 这是行为兼容桥，栈语义在 BaseCard.get_stack_chain 保留
func get_stack_chain() -> Array[BaseCard]:
	var chain: Array[BaseCard] = [self]
	chain.append_array(get_contents())
	# 栈子卡（如待合成的第二个地形）
	var sc: BaseCard = stack_child
	while sc != null:
		chain.append(sc)
		sc = sc.stack_child
	return chain

## 返回所有容器内容物（含内容物的栈子链），不含 self
func get_contents() -> Array[BaseCard]:
	var result: Array[BaseCard] = []
	for card in _slot_owner.keys():
		if card == null or not is_instance_valid(card):
			continue
		result.append(card)
		var sub: BaseCard = card.stack_child
		while sub != null:
			result.append(sub)
			sub = sub.stack_child
	return result

## 地形合成/销毁时：内容物全部脱离（统一走 _detach_all_relations）
func _drop_all_contents() -> void:
	for card in _slot_owner.keys():
		if card != null and is_instance_valid(card):
			card._detach_all_relations()
	_slots.clear()
	_slot_owner.clear()

## 当前内容物数量
func _content_count() -> int:
	return _slot_owner.size()

## 最大容量 = 占地格数（静态内容物硬上限，动物 M5 起不占格）
func max_content_count() -> int:
	return terrain_size.x * terrain_size.y

## 该卡是否允许进入本容器（M2 基础判定；类型上限/配方细分后议）
func can_accept_content(card: BaseCard) -> bool:
	if card == null or not is_instance_valid(card):
		return false
	# 工具永不进容器
	if card.role == CardEnums.CardRole.TOOL:
		return false
	# 地形卡：只作「本体合成」，不作内容物
	if card.role == CardEnums.CardRole.TERRAIN:
		return false
	# 容量检查
	return _content_count() < max_content_count()

## 为卡寻找最近空格并占位；返回占位格的世界中心坐标
## 返回 Vector2.INF 表示容器已满
func claim_content(card: BaseCard, hint_pos: Vector2) -> Vector2:
	if _slot_owner.has(card):
		return _slot_world_pos(_slot_owner[card])
	if not can_accept_content(card):
		return Vector2.INF

	var gm := get_node_or_null("/root/GridManager") as GridManager
	if gm == null:
		return Vector2.INF
	# 搜索起点与落位同源：左上格（origin），只用一组真值，避免中心/左上漂移
	var origin: Vector2i = _origin_cell()

	var best: Vector2i = Vector2i(-1, -1)
	var best_dist := INF
	for x in range(terrain_size.x):
		for y in range(terrain_size.y):
			var rel := Vector2i(x, y)
			if _slots.has(rel):
				continue
			var slot_world: Vector2 = gm.cell_to_world(origin + rel) + Vector2(GridManager.CELL_W * 0.5, GridManager.CELL_H * 0.5)
			var d := hint_pos.distance_to(slot_world)
			if d < best_dist:
				best = rel
				best_dist = d
	if best == Vector2i(-1, -1):
		return Vector2.INF

	_slots[best] = card
	_slot_owner[card] = best
	_apply_content_visual(card, true)
	return _slot_world_pos(best)

## 释放卡占用的格（取出/移除时）
func release_content(card: BaseCard) -> void:
	if not _slot_owner.has(card):
		return
	var rel: Vector2i = _slot_owner[card]
	_slots.erase(rel)
	_slot_owner.erase(card)
	_apply_content_visual(card, false)

## 容器内容物视觉：缩略显示（占格时缩到格内），取出恢复全尺寸
func _apply_content_visual(card: BaseCard, in_container: bool) -> void:
	if card == null or not is_instance_valid(card):
		return
	if in_container:
		card.scale = Vector2(0.55, 0.55)
		card.z_index = z_index + 1
	else:
		card.scale = Vector2.ONE
		card.z_index = z_index + 1

func _slot_world_pos(rel: Vector2i) -> Vector2:
	var gm := get_node_or_null("/root/GridManager") as GridManager
	if gm == null:
		return global_position
	var origin: Vector2i = _origin_cell()
	# cell_to_world 返回格左上角；内容物卡中心应停在格中心 → +半格
	var w := GridManager.CELL_W
	var h := GridManager.CELL_H
	return gm.cell_to_world(origin + rel) + Vector2(w * 0.5, h * 0.5)

## 面板左上角对应的格（单一真值源 = GridManager 已登记的足迹）
## global_position 是面板中心；足迹 rect.position 即地形覆盖的最左上格
func _origin_cell() -> Vector2i:
	var gm := get_node_or_null("/root/GridManager") as GridManager
	if gm == null:
		return Vector2i.ZERO
	# 已登记足迹 → 直接用它（登记后与 _setup_grid_footprint 一致）
	var rect := gm.get_footprint(self)
	if rect.size != Vector2i.ZERO:
		return rect.position
	# 未登记（如测试瞬建）：global_position = 左上角顶点 → 直接取整得到左上格
	return Vector2i(
		floori(global_position.x / GridManager.CELL_W),
		floori(global_position.y / GridManager.CELL_H)
	)

## M2：内容物在容器中的铺格位置（总纲 §3）
## 铁律：内容物一律落在棋盘格上；没有格位时回退左上格整数对齐，绝不回容器中心
func get_content_position(card: BaseCard) -> Vector2:
	if _slot_owner.has(card):
		return _slot_world_pos(_slot_owner[card])
	var gm := get_node_or_null("/root/GridManager") as GridManager
	if gm == null:
		return global_position
	# 异常兜底：左上格中心（仍是棋盘格，非容器中心）
	var origin: Vector2i = _origin_cell()
	return gm.cell_to_world(origin) + Vector2(GridManager.CELL_W * 0.5, GridManager.CELL_H * 0.5)

# ── Queries ──
func count_children_of_type(wanted: int) -> int:
	var n: int = 0
	for c in get_stack_chain():
		if c != self and c.type == wanted: n += 1
	return n

func get_duck_count() -> int:
	return count_children_of_type(CardEnums.CardType.DUCK)

func get_bug_list() -> Array[BaseCard]:
	var bugs: Array[BaseCard] = []
	for c in get_stack_chain():
		if c.type == CardEnums.CardType.BUG: bugs.append(c)
	return bugs

func get_ducks_sorted_by_instance_id() -> Array[BaseCard]:
	var ducks: Array[BaseCard] = []
	for c in get_stack_chain():
		if c.type == CardEnums.CardType.DUCK: ducks.append(c)
	ducks.sort_custom(func(a, b): return a.get_instance_id() < b.get_instance_id())
	return ducks

func is_water_terrain() -> bool:
	return type in [CardEnums.CardType.POND, CardEnums.CardType.BIG_POND, CardEnums.CardType.FISH_POND]

func get_growth_multiplier() -> float:
	if _bhv: return _bhv.get_growth_mult()
	return 1.0
