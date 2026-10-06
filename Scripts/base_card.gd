# BaseCard.gd — base class for all stackable cards
extends Area2D
class_name BaseCard

# Preload CJK font (applied to all labels at runtime)
const CJK_FONT = preload("res://fonts/simhei.ttf")
const WATER_SHADER := preload("res://shaders/water_ripple_border.gdshader")

# ============================================================
# Exported properties
# ============================================================
@export var role: CardEnums.CardRole = CardEnums.CardRole.CREATURE
@export var type: CardEnums.CardType = CardEnums.CardType.DUCK
@export var card_name: String = "Unnamed Card"
@export var show_debug_info: bool = true

@export var value_a: float = 0.0:
	set(v):
		value_a = v
		if role == CardEnums.CardRole.CREATURE and value_a <= 0.0 and not _is_dying:
			_is_dying = true
			on_health_zero()
		if role == CardEnums.CardRole.TOOL and value_a <= 0.0 and not _is_dying:
			_is_dying = true
			on_tool_broken()

@export var value_b: float = 0.0

# ============================================================
# Stack chain pointers
# ============================================================
var stack_parent: BaseCard = null
var stack_child: BaseCard = null

## 容器归属（总纲 §3）：我属于哪个地形容器（与 stack 完全分离）
## 内容物只用 container_parent 标识归属，绝不借用 stack_parent
var container_parent: TerrainCard = null

# ============================================================
# Signals
# ============================================================
signal stack_parent_changed(old_parent: BaseCard, new_parent: BaseCard)
signal stack_child_changed(old_child: BaseCard, new_child: BaseCard)
signal on_card_stacked(stacked_card: BaseCard, target_card: BaseCard)
signal health_zero(card: BaseCard)
signal tool_broken(card: BaseCard)
signal card_dropped_on_market(card: BaseCard)
signal card_dropped_on_labor_tool(card: BaseCard)
signal card_dropped_on_labor_target(card: BaseCard)

# ============================================================
# Semantic property accessors — Creature
# ============================================================
## Creature: ValueA = Hunger/Health
var health: float:
	get: return value_a if role == CardEnums.CardRole.CREATURE else 0.0
	set(v):
		if role == CardEnums.CardRole.CREATURE:
			value_a = max(0.0, v)

## Creature: ValueB = Progress
var progress: float:
	get: return value_b if role == CardEnums.CardRole.CREATURE else 0.0
	set(v):
		if role == CardEnums.CardRole.CREATURE:
			value_b = max(0.0, v)

# ============================================================
# Semantic property accessors — Resource
# ============================================================
var intensity: float:
	get: return value_a if role == CardEnums.CardRole.RESOURCE else 0.0
	set(v):
		if role == CardEnums.CardRole.RESOURCE:
			value_a = v

var duration: float:
	get: return value_b if role == CardEnums.CardRole.RESOURCE else 0.0
	set(v):
		if role == CardEnums.CardRole.RESOURCE:
			value_b = max(0.0, v)

# ============================================================
# Semantic property accessors — Terrain
# ============================================================
var capacity: float:
	get: return value_a if role == CardEnums.CardRole.TERRAIN else 0.0
	set(v):
		if role == CardEnums.CardRole.TERRAIN:
			value_a = max(0.0, v)

var moisture: float:
	get: return value_b if role == CardEnums.CardRole.TERRAIN else 0.0
	set(v):
		if role == CardEnums.CardRole.TERRAIN:
			value_b = max(0.0, v)

# ============================================================
# Semantic property accessors — Tool
# ============================================================
var durability: float:
	get: return value_a if role == CardEnums.CardRole.TOOL else 0.0
	set(v):
		if role == CardEnums.CardRole.TOOL:
			value_a = max(0.0, v)

var efficiency: float:
	get: return value_b if role == CardEnums.CardRole.TOOL else 0.0
	set(v):
		if role == CardEnums.CardRole.TOOL:
			value_b = v

# ============================================================
# Internal state
# ============================================================
var _is_dying: bool = false
var _is_dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _water_overlay: ColorRect = null   # 水纹着色器 overlay（仅地貌卡使用）

## 自由移动标志：为 true 时跳过堆叠吸附，由移动 AI 控制位置
var free_move: bool = false

## 产物浮动标志：产物生成后以浮动卡存在，不落位/不占格，等玩家拖取
var is_floating: bool = false
## 浮动基线 Y（正弦浮动围绕此值）
var _float_base_y: float = 0.0
## 浮动相位（避免多张卡同步跳动）
var _float_phase: float = 0.0

## 堆叠吸附目标位（stack_on 时解析；容器铺格/默认+35）
var _child_target_pos: Vector2 = Vector2.ZERO

## 容器拖拽跟随偏移：容器被拖时内容物保持相对位置（不吸格）
var _container_follow_offset: Vector2 = Vector2.ZERO

## 拖动前位置（落位冲突时回弹用）
var _pre_drag_pos: Vector2 = Vector2.ZERO

# ============================================================
# Lifecycle
# ============================================================
func _ready() -> void:
	input_pickable = true
	_apply_cjk_font_to_labels()
	call_deferred("_initialize_starting_stack")

func _apply_cjk_font_to_labels() -> void:
	_apply_font_recursive(self)

func _apply_font_recursive(node: Node) -> void:
	if node is Label:
		node.add_theme_font_override("font", CJK_FONT)
	for i in range(node.get_child_count()):
		_apply_font_recursive(node.get_child(i))

func _initialize_starting_stack() -> void:
	# 浮动产物不自动挂载 —— 等玩家主动拖取（M4）
	if is_floating:
		return
	# 初始化落位 —— 明确三态分流（总纲 §4/§6）：
	#   * 我是自由卡，附近有地形 → 看情况：地形×地形=合成入栈；非地形×地形=进容器
	#   * 附近有普通卡 → 入栈
	if stack_parent != null:
		return
	var target: BaseCard = _find_best_stack_target()
	if target == null:
		return
	if target is TerrainCard and role != CardEnums.CardRole.TERRAIN:
		enter_container(target as TerrainCard)
	else:
		stack_on(target)

func _process(delta: float) -> void:
	if _is_dragging:
		global_position = get_global_mouse_position() - _drag_offset
		# 拖拽落位预览：每帧刷新目标格与合法性
		_queue_redraw_drag_preview()
	elif is_floating:
		# 浮动卡（产物待取）：不上移动 AI、不推挤、不吸附，轻微上下浮动吸引注意
		var t: float = Time.get_ticks_msec() * 0.001
		global_position.y = _float_base_y + sin(t * 2.0 + _float_phase) * 3.0
		z_index = 10
	elif free_move:
		# 移动 AI 控制位置，跳过吸附 lerp，但仍维护 z_index
		z_index = container_parent.z_index + 1 if container_parent != null else (stack_parent.z_index + 1 if stack_parent != null else 0)
	elif container_parent != null and is_instance_valid(container_parent):
		# 容器内容物
		var t := container_parent
		if t._is_dragging:
			# 容器正在被拖：跟随（保持相对偏移，不被吸入格位）
			global_position = t.global_position + _container_follow_offset
			z_index = t.z_index + 1
		elif t.has_method("get_content_position") and t._slot_owner.has(self):
			# 容器静止：吸附到自己格位
			var target_pos: Vector2 = t.get_content_position(self)
			global_position = global_position.lerp(target_pos, delta * 18.0)
			z_index = t.z_index + 1
		else:
			z_index = t.z_index + 1
	elif stack_parent != null and is_instance_valid(stack_parent):
		# 栈子卡：吸附到栈偏移目标位
		var target_pos: Vector2 = _child_target_pos
		global_position = global_position.lerp(target_pos, delta * 18.0)
		z_index = stack_parent.z_index + 1
	else:
		z_index = 0
		_process_mutual_pushing(delta)

	if stack_child != null:
		stack_child.z_index = z_index + 1

	# Resource card duration countdown
	if role == CardEnums.CardRole.RESOURCE:
		duration -= delta
		if duration <= 0.0:
			print("[Resource] ", card_name, " duration expired. Removing.")
			_unstack_and_remove()
			return

	_update_visuals()
	_update_water_overlay()

# ============================================================
# Mutual pushing — prevent overlapping independent cards
# ============================================================
func _process_mutual_pushing(delta: float) -> void:
	if _is_dragging or stack_parent != null:
		return
	# 地形卡是静止锚点，不参与推挤（不被推开，也不推别人）
	if role == CardEnums.CardRole.TERRAIN:
		return

	for area in get_overlapping_areas():
		if area is BaseCard and is_instance_valid(area):
			var other_card: BaseCard = area as BaseCard
			var other_root: BaseCard = other_card.get_stack_root()
			if other_root != self and not other_root._is_dragging:
				# 不推挤地形卡
				if other_root.role == CardEnums.CardRole.TERRAIN:
					continue
				var diff: Vector2 = global_position - other_root.global_position
				var dist: float = diff.length()
				var push_threshold: float = 95.0

				if dist < push_threshold:
					var push_dir: Vector2
					if dist < 0.1:
						push_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
						dist = 1.0
					else:
						push_dir = diff / dist

					var force: float = (push_threshold - dist) * 12.0
					global_position += push_dir * force * delta

# ============================================================
# Visual updates (debug info overlay)
# ============================================================
func _update_visuals() -> void:
	var name_label: Label = get_node_or_null("Panel/NameLabel") as Label
	if name_label != null:
		name_label.text = card_name

	var panel: Control = get_node_or_null("Panel") as Control
	if panel != null:
		panel.visible = show_debug_info
	if not show_debug_info:
		return

	var val_a_label: Label = get_node_or_null("Panel/ValueALabel") as Label
	var val_b_label: Label = get_node_or_null("Panel/ValueBLabel") as Label
	var progress_bar: ProgressBar = get_node_or_null("Panel/ProgressBar") as ProgressBar

	match role:
		CardEnums.CardRole.CREATURE:
			if val_a_label != null:
				match type:
					CardEnums.CardType.DUCK:
						val_a_label.text = "饥饿: %.0f" % health
					_:
						val_a_label.text = "耐久: %.0f" % health
			if val_b_label != null:
				val_b_label.text = "进度: %.0f%%" % progress
			if progress_bar != null:
				progress_bar.visible = true
				progress_bar.value = progress

		CardEnums.CardRole.RESOURCE:
			if val_a_label != null:
				val_a_label.text = "含量: %.1f" % intensity
			if val_b_label != null:
				val_b_label.text = "保鲜: %.0fs" % duration
			if progress_bar != null:
				progress_bar.visible = false

		CardEnums.CardRole.TERRAIN:
			var terrain_card := self as TerrainCard
			var irrigated: bool = terrain_card.is_irrigated if terrain_card else false
			var status_str: String = "(润)" if irrigated else "(干)"
			if val_a_label != null:
				val_a_label.text = "承载: %.0f" % capacity
			if val_b_label != null:
				val_b_label.text = "湿润: %.0f %s" % [moisture, status_str]
			if progress_bar != null:
				progress_bar.visible = false

		CardEnums.CardRole.TOOL:
			if val_a_label != null:
				val_a_label.text = "耐久: %.0f" % durability
			if val_b_label != null:
				val_b_label.text = "效率: %.1fx" % efficiency
			if progress_bar != null:
				progress_bar.visible = false

# ============================================================
# Input handling — drag & drop
# ============================================================
## 全局拖拽锁：同一时刻只允许一张卡被拖拽
static var _drag_lock: BaseCard = null

func _input_event(viewport: Viewport, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# 若已有卡在拖拽（含本卡自己），忽略后续按下——最多一张卡跟手
			if _drag_lock != null:
				# 锁可能指向已 free 的卡：校验后清理，避免永久锁死
				if not is_instance_valid(_drag_lock):
					_drag_lock = null
				else:
					get_viewport().set_input_as_handled()
					return
			_is_dragging = true
			_drag_lock = self
			_drag_offset = get_global_mouse_position() - global_position
			# 记录拖动前位置（冲突回弹用）
			_pre_drag_pos = global_position
			z_index = 100
			# 拖走浮动产物 → 拿起即变真实卡（不再是待取浮动）
			is_floating = false
			# 拖动即取出：脱离所有父子关系（容器内容物/栈子卡都还原为自由卡）
			_detach_all_relations()
			# 拖动中的地形卡退出水网（不供水/不参与邻接/翻塘/漂移）
			_set_drag_system_participation(false)
			# M1 拖动中的地形卡释放网格足迹（腾出占地）
			_release_grid_footprint_hook()
			# 拖拽落位预览：显示目标棋盘格
			_show_drag_preview()
			get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	if _is_dragging and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_is_dragging = false
			_drag_lock = null
			z_index = 0
			# 拖动结束：隐藏落位预览
			_hide_drag_preview()
			# 拖动结束：地形卡回归水网
			_set_drag_system_participation(true)

			# Check if dropped on market UI
			if _check_drop_on_market():
				get_viewport().set_input_as_handled()
				return

			# Check if dropped on labor UI
			if _check_drop_on_labor():
				get_viewport().set_input_as_handled()
				return

			# Drop target resolution
			var target: BaseCard = _find_best_stack_target()
			var placed: bool = false
			if target != null:
				if target is TerrainCard and role != CardEnums.CardRole.TERRAIN:
					# 非地形卡 → 地形成容器
					placed = enter_container(target as TerrainCard)
				else:
					# 地形×地形（合成）或 卡叠卡（栈）
					stack_on(target)
					placed = true
			if not placed:
				# 自由放置 → 吸附最近网格格点（M0 网格系统）
				_snap_to_grid()
			# M1 地形卡落定后登记占地（冲突则就近空位）
			_setup_grid_footprint_hook()
			get_viewport().set_input_as_handled()

# ============================================================
# Drop target detection — Market & Labor (hook points)
# ============================================================
func _check_drop_on_market() -> bool:
	var market_manager = get_node_or_null("/root/Main/MarketManager")
	if market_manager and market_manager.has_method("try_sell_card"):
		var mouse_pos: Vector2 = get_global_mouse_position()
		return market_manager.try_sell_card(self, mouse_pos)
	return false

func _check_drop_on_labor() -> bool:
	var labor_manager = get_node_or_null("/root/Main/LaborManager")
	if labor_manager and labor_manager.has_method("try_accept_card"):
		var mouse_pos: Vector2 = get_global_mouse_position()
		return labor_manager.try_accept_card(self, mouse_pos)
	return false

# ============================================================
# Stack target finding — skip BUG (pests don't stack)
# ============================================================
func _find_best_stack_target() -> BaseCard:
	# 地形卡只找地形卡叠放（合成路径），绝不找普通卡/内容物
	# —— 否则会叠到容器内容物上造成链错乱崩溃
	if role == CardEnums.CardRole.TERRAIN:
		return _find_terrain_stack_target()

	# 非地形卡：优先选地形成容器（铺格），其次最近普通卡
	var best_terrain: TerrainCard = null
	var terrain_dist: float = 200.0
	var best_card: BaseCard = null
	var card_dist: float = 100.0

	for area in get_overlapping_areas():
		if area is BaseCard and area != self and is_instance_valid(area):
			var card: BaseCard = area as BaseCard
			# 拖动中的卡不在游戏体系内，不能作为堆叠目标
			if card._is_dragging:
				continue
			# BUGs don't participate in normal stacking
			if card.type == CardEnums.CardType.BUG:
				continue
			# TOOLs don't stack
			if card.role == CardEnums.CardRole.TOOL:
				continue
			# Can't stack on a card that already has a child
			if card.stack_child != null and card.stack_child != self:
				continue
			# Circular stack prevention
			if _is_in_our_stack_chain(card):
				continue

			var dist: float = global_position.distance_to(card.global_position)
			if card is TerrainCard:
				# 地形容器优先
				if dist < terrain_dist:
					terrain_dist = dist
					best_terrain = card as TerrainCard
			elif dist < card_dist:
				card_dist = dist
				best_card = card

	return best_terrain if best_terrain != null else best_card

# 地形卡专用：只找「可合成」的地形（有配方才叠），否则返回 null（落自由网格）
func _find_terrain_stack_target() -> BaseCard:
	var best: BaseCard = null
	var best_dist: float = 200.0
	for area in get_overlapping_areas():
		if area is BaseCard and area != self and is_instance_valid(area):
			var card: BaseCard = area as BaseCard
			if card._is_dragging:
				continue
			if card.type == CardEnums.CardType.BUG:
				continue
			if card is TerrainCard and _can_merge_terrain_with(card):
				var dist: float = global_position.distance_to(card.global_position)
				if dist < best_dist:
					best_dist = dist
					best = card
	return best

## 是否与目标地形有已知地形合成配方（无配方 → 不该叠放，落自由网格互斥）
func _can_merge_terrain_with(other: BaseCard) -> bool:
	if other == null or not is_instance_valid(other):
		return false
	# 池塘 + 池塘 → 大水塘
	if type == CardEnums.CardType.POND and other.type == CardEnums.CardType.POND:
		return true
	# （后续新配方在此扩展：大水塘+鱼→鱼塘是内容物配方，不走地形叠放）
	return false

func _is_in_our_stack_chain(card: BaseCard) -> bool:
	var current: BaseCard = self
	while current != null:
		if current == card:
			return true
		current = current.stack_child
	return false

## M0 网格吸附：自由放置时对齐最近格点（拖动释放调用）
## 地形卡 → 吸附到顶点（左上角格线交点）；普通卡 → 吸附到格中心
func _snap_to_grid() -> void:
	var gm := get_node_or_null("/root/GridManager") as GridManager
	if gm == null:
		return
	if role == CardEnums.CardRole.TERRAIN:
		global_position = gm.snap_to_vertex(global_position)
	else:
		global_position = gm.snap_to_grid(global_position)

## M1 钩子：释放地形足迹（拖起时调用）
func _release_grid_footprint_hook() -> void:
	if role == CardEnums.CardRole.TERRAIN:
		var t := self as TerrainCard
		if t:
			t._release_grid_footprint()

## M1 钩子：落定时重新登记地形足迹
## is_drag_placement=true 表示玩家拖动落位（冲突应回弹原位）；false=合成跳跃（冲突找空位）
func _setup_grid_footprint_hook(is_drag_placement: bool = true) -> void:
	if role == CardEnums.CardRole.TERRAIN:
		var t := self as TerrainCard
		if t:
			t._setup_grid_footprint(is_drag_placement)

# ============================================================
# Drag preview（落位棋盘格视觉提示）
# ============================================================
func _show_drag_preview() -> void:
	var dp := get_node_or_null("/root/DragPreview") as DragPreview
	if dp == null:
		return
	# 拖起即展示，具体位置由 _process 每帧刷新
	_queue_redraw_drag_preview()

func _hide_drag_preview() -> void:
	var dp := get_node_or_null("/root/DragPreview") as DragPreview
	if dp:
		dp.hide_preview()

## 拖动中每帧刷新预览：按角色推算落位格（地形=顶点矩形；普通=格中心单格）
func _queue_redraw_drag_preview() -> void:
	var dp := get_node_or_null("/root/DragPreview") as DragPreview
	var gm := get_node_or_null("/root/GridManager") as GridManager
	if dp == null or gm == null:
		return

	if role == CardEnums.CardRole.TERRAIN:
		# 地形：吸附到最近顶点 → 左上角格 + 覆盖 w×h
		var vertex := gm.snap_to_vertex(global_position)
		var origin := gm.world_to_cell(vertex)
		var t := self as TerrainCard
		var sz := t.terrain_size if t else Vector2i(1, 1)
		var valid := gm.can_fit(origin, sz.x, sz.y)
		dp.show_preview(origin, sz, valid)
	else:
		# 普通卡：落位 = 最近格中心 → 预览单格（用 center_cell 与 snap_to_grid 同源）
		var center := gm.snap_to_grid(global_position)
		var origin := gm.center_cell(center)
		dp.show_preview(origin, Vector2i(1, 1), true)

# ============================================================
# Stack / Container（总纲 §3、§4、§6）
# 两套关系完全分离：
#   stack_on  = 纯栈（stack_parent/child 单链）
#   enter/leave_container = 纯容器（container_parent + 容器 slots）
# ============================================================

## 纯栈：叠到父卡上（合成/普通叠放路径）
func stack_on(new_parent: BaseCard) -> void:
	if stack_parent == new_parent:
		return

	# 若当前是容器内容物，先离开容器（三态互斥）
	if container_parent != null:
		_leave_container()

	var old_parent: BaseCard = stack_parent
	if stack_parent != null:
		stack_parent.stack_child = null
		stack_parent.stack_child_changed.emit(self, null)

	stack_parent = new_parent
	if new_parent != null:
		if new_parent.stack_child != null and new_parent.stack_child != self:
			new_parent.stack_child.unstack()
		new_parent.stack_child = self
		new_parent.stack_child_changed.emit(null, self)
		new_parent.on_card_stacked.emit(self, new_parent)
		_child_target_pos = new_parent.global_position + Vector2(0, 35)
		global_position = _child_target_pos
		_play_stack_animation(new_parent)

	stack_parent_changed.emit(old_parent, new_parent)

func unstack() -> void:
	stack_on(null)

## 高层挂载入口（总纲 §6 转移矩阵）：自由 → 目标态
## 目标为地形成容器 → enter_container；否则 → stack_on（栈）
## 供行为脚本/AI 调用，避免它们误用 stack_on 往地形上挂
func attach_to(target: BaseCard) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	if target is TerrainCard and role != CardEnums.CardRole.TERRAIN:
		return enter_container(target as TerrainCard)
	stack_on(target)
	return true

## 纯容器：进入地形成容器（铺格，不走单链）
## 成功返回 true；被拒/满返回 false
func enter_container(terrain: TerrainCard) -> bool:
	if terrain == null or not is_instance_valid(terrain):
		return false
	if container_parent == terrain:
		return true
	# 若在栈上，先脱离
	if stack_parent != null:
		unstack()
	# 离开旧容器
	if container_parent != null:
		_leave_container()
	# 校验可进
	if not terrain.can_accept_content(self):
		return false
	var pos := terrain.claim_content(self, global_position)
	if pos == Vector2.INF:
		return false
	container_parent = terrain
	global_position = pos
	_child_target_pos = pos
	_container_follow_offset = pos - terrain.global_position
	terrain.notify_content_added(self)
	_play_stack_animation(terrain)
	return true

## 统一出容器：释放格位 + 清归属 + 恢复全尺寸
func _leave_container() -> void:
	if container_parent == null:
		return
	if is_instance_valid(container_parent):
		container_parent.release_content(self)
	container_parent = null
	_container_follow_offset = Vector2.ZERO
	scale = Vector2.ONE

## 销毁前统一脱离全部关系（总纲 §6 铁律）
func _detach_all_relations() -> void:
	if container_parent != null:
		_leave_container()
	if stack_parent != null:
		_detach_from_parent(stack_parent)
	if stack_child != null:
		var ch: BaseCard = stack_child
		ch.stack_parent = null
		ch.stack_parent_changed.emit(self, null)
		stack_child = null

# ============================================================
# Stack chain navigation
# ============================================================
func get_stack_root() -> BaseCard:
	var current: BaseCard = self
	while current.stack_parent != null:
		current = current.stack_parent
	return current

func get_terrain() -> TerrainCard:
	# 总纲 §5：容器归属优先；其次栈根若是地形
	if container_parent != null and is_instance_valid(container_parent):
		return container_parent
	var root: BaseCard = get_stack_root()
	if root is TerrainCard:
		return root as TerrainCard
	return null

## BaseCard 语义 = 纯栈链；TerrainCard 覆写为「self+容器内容物」（行为兼容桥，见总纲 §5 注）
func get_stack_chain() -> Array[BaseCard]:
	var chain: Array[BaseCard] = [self]
	var child: BaseCard = stack_child
	while child != null:
		chain.append(child)
		child = child.stack_child
	return chain

## 拖动参与度切换：地形卡在拖动期间退出水网，释放时回归
func _set_drag_system_participation(active: bool) -> void:
	if role != CardEnums.CardRole.TERRAIN:
		return
	var terrain := self as TerrainCard
	if terrain == null:
		return
	var im := get_node_or_null("/root/IrrigationManager") as IrrigationManager
	if im == null:
		return
	if active:
		im.register_terrain(terrain)
	else:
		im.unregister_terrain(terrain)

# ============================================================
# Removal helpers（总纲 §6 铁律）
# ============================================================
func _unstack_and_remove() -> void:
	_detach_all_relations()
	queue_free()

## 脱离指定栈父卡（容器不做栈父；总纲 §6）
func _detach_from_parent(parent: BaseCard) -> void:
	if parent == null:
		return
	parent.stack_child = null
	parent.stack_child_changed.emit(self, null)

# ============================================================
# Animation hooks
# ============================================================
func _play_stack_animation(target: BaseCard) -> void:
	scale = Vector2(0.8, 0.8)
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.15) \
		.set_trans(Tween.TRANS_ELASTIC) \
		.set_ease(Tween.EASE_OUT)

func play_unstack_animation() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.1)
	tween.tween_property(self, "scale", Vector2.ONE, 0.1)

func play_predation_animation(target_position: Vector2) -> void:
	var original_pos: Vector2 = global_position
	var tween: Tween = create_tween()
	tween.tween_property(self, "global_position", target_position, 0.08) \
		.set_trans(Tween.TRANS_QUAD) \
		.set_ease(Tween.EASE_IN)
	tween.tween_property(self, "global_position", original_pos, 0.12) \
		.set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_OUT)

func play_produce_animation() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.15, 1.15), 0.1)
	tween.tween_property(self, "scale", Vector2.ONE, 0.12)

func play_hit_animation() -> void:
	modulate = Color(1.0, 0.3, 0.3, 1.0)
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.2)

func play_death_animation() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.3)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.3)

# ============================================================
# Death transformation
# ============================================================
func on_health_zero() -> void:
	health_zero.emit(self)
	play_death_animation()
	print("[Card] ", card_name, " Health is zero. Transforming...")

	match type:
		CardEnums.CardType.DUCK:
			# Duck dies → Duck Feather
			_spawn_replacement(CardEnums.CardType.DUCK_FEATHER, "鸭毛")
		CardEnums.CardType.WILD_RICE_SEED, CardEnums.CardType.WATER_CALTROP:
			# Crop durability zero → destroyed, no replacement
			_detach_and_free()
			return
		_:
			_detach_and_free()
			return

	_detach_and_free()

# ============================================================
# Tool breakage
# ============================================================
func on_tool_broken() -> void:
	tool_broken.emit(self)
	play_death_animation()
	print("[Tool] ", card_name, " durability zero. Destroying...")
	_detach_and_free()

# ============================================================
# Internal helpers
# ============================================================
func _spawn_replacement(replacement_type: CardEnums.CardType, replacement_name: String) -> void:
	# 保留原关系上下文，供替代卡继承
	var container: TerrainCard = container_parent
	var parent: BaseCard = stack_parent
	var child: BaseCard = stack_child

	_detach_all_relations()

	if CardSpawner.instance != null:
		var new_card: BaseCard = CardSpawner.instance.spawn_card(replacement_type, replacement_name, global_position)
		if new_card != null:
			if container != null and is_instance_valid(container):
				new_card.enter_container(container)
			elif parent != null and is_instance_valid(parent):
				new_card.stack_on(parent)
			if child != null and is_instance_valid(child):
				child.stack_on(new_card)

# ============================================================
# Water ripple overlay (terrain cards only)
# ============================================================
func get_water_overlay() -> ColorRect:
	if _water_overlay: return _water_overlay
	if role != CardEnums.CardRole.TERRAIN: return null

	var panel: Control = get_node_or_null("Panel") as Control
	if not panel: return null

	var overlay := ColorRect.new()
	overlay.name = "WaterOverlay"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = -1

	var mat := ShaderMaterial.new()
	mat.shader = WATER_SHADER
	mat.set_shader_parameter("moisture_level", 0.0)
	overlay.material = mat

	panel.add_child(overlay)
	panel.move_child(overlay, 0)  # Behind all other panel children
	_water_overlay = overlay
	return overlay

func _update_water_overlay() -> void:
	if role != CardEnums.CardRole.TERRAIN: return
	var overlay := get_water_overlay()
	if not overlay: return
	var mat: ShaderMaterial = overlay.material as ShaderMaterial
	if not mat: return

	var terrain := self as TerrainCard
	if not terrain: return

	var level: float = clamp(moisture / 100.0, 0.0, 1.0)
	mat.set_shader_parameter("moisture_level", level)

	# Water terrain has full water color; paddy has blue tint
	if terrain.is_water_terrain():
		mat.set_shader_parameter("water_color", Color(0.15, 0.50, 0.95, 0.75))
	else:
		mat.set_shader_parameter("water_color", Color(0.25, 0.60, 0.85, 0.55))


func _detach_and_free() -> void:
	# 统一脱离：容器内容物 / 栈子卡 / 同时有子都一并处理（总纲 §6）
	_detach_all_relations()
	queue_free()
