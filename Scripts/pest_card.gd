# PestCard.gd — pest that damages crops
extends BaseCard
class_name PestCard

# ============================================================
# Exported properties
# ============================================================
@export var damage_per_second: float = 5.0
@export var target_search_interval: float = 1.0

# ============================================================
# State
# ============================================================
var _target_crop: BaseCard = null
var _timer: float = 0.0

# ── 移动 AI 状态 ──
enum MoveState { IDLE, CHASE }
var move_state: MoveState = MoveState.IDLE
var _wander_dir: Vector2 = Vector2.RIGHT
var _turn_timer: float = 0.0
var _chase_target: BaseCard = null
var _cfg: Node = null  # GameConfig autoload reference

# ============================================================
# Lifecycle
# ============================================================
func _ready() -> void:
	super._ready()
	role = CardEnums.CardRole.CREATURE
	type = CardEnums.CardType.BUG
	card_name = "虫"
	_cfg = get_node_or_null("/root/GameConfig")

func _process(delta: float) -> void:
	super._process(delta)
	_process_movement(delta)

# ============================================================
# 移动 AI（M3/M4）
# ============================================================
func _process_movement(delta: float) -> void:
	if _is_dragging or _cfg == null:
		return

	var terrain: TerrainCard = get_terrain()

	# 1) 视野内找作物 → 追击
	var crop := _find_nearest_crop_in_range(terrain)
	if crop != null:
		move_state = MoveState.CHASE
		_chase_target = crop
	elif move_state == MoveState.CHASE:
		move_state = MoveState.IDLE
		_chase_target = null

	# 2) 按状态移动
	match move_state:
		MoveState.CHASE:
			_move_towards(_chase_target.global_position, _cfg.bug_chase_speed, delta)
		MoveState.IDLE:
			_wander(terrain, delta)

## 视野内找最近作物种子（全局遍历所有地貌卡的堆叠链）
func _find_nearest_crop_in_range(terrain: TerrainCard) -> BaseCard:
	var best: BaseCard = null
	var best_dist: float = _cfg.bug_vision_range

	var im := get_node_or_null("/root/IrrigationManager") as IrrigationManager
	if im == null:
		return null

	for t in im.get_all_terrains():
		if not is_instance_valid(t):
			continue
		for c in t.get_stack_chain():
			if c.type in [CardEnums.CardType.WILD_RICE_SEED, CardEnums.CardType.WATER_CALTROP] \
				and is_instance_valid(c) and c != self:
				var d: float = global_position.distance_to(c.global_position)
				if d < best_dist:
					best_dist = d
					best = c
	return best

func _move_towards(target_pos: Vector2, speed: float, delta: float) -> void:
	free_move = true
	var dir: Vector2 = target_pos - global_position
	if dir.length() > 4.0:
		var desired: Vector2 = global_position + dir.normalized() * speed * delta
		global_position = _apply_terrain_avoidance(desired)

## 空闲爬行：地貌范围随机小步 + 偶尔停顿，无地貌在出生点附近徘徊
func _wander(terrain: TerrainCard, delta: float) -> void:
	free_move = true
	_turn_timer -= delta
	if _turn_timer <= 0.0:
		_turn_timer = randf_range(_cfg.wander_turn_interval_min, _cfg.wander_turn_interval_max)
		_wander_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		if _wander_dir == Vector2.ZERO:
			_wander_dir = Vector2.RIGHT

	var desired: Vector2 = global_position + _wander_dir * _cfg.bug_idle_speed * delta
	desired = _apply_terrain_avoidance(desired)

	if terrain != null and is_instance_valid(terrain):
		var center: Vector2 = terrain.global_position
		var offset: Vector2 = desired - center
		if offset.length() > _cfg.bug_terrain_boundary:
			desired = center + offset.normalized() * _cfg.bug_terrain_boundary

	global_position = desired

## 软排斥避障：从其他地形卡推开（每帧推离叠加移动方向 → 形成绕行）
func _apply_terrain_avoidance(desired_pos: Vector2) -> Vector2:
	var result := desired_pos
	var own: TerrainCard = get_terrain()
	var im := get_node_or_null("/root/IrrigationManager") as IrrigationManager
	if im == null:
		return result
	for t in im.get_all_terrains():
		if not is_instance_valid(t) or t == own or t._is_dragging:
			continue
		var diff: Vector2 = result - t.global_position
		var d: float = diff.length()
		var clearance: float = _cfg.bug_terrain_clearance
		if d < clearance:
			if d < 0.1:
				diff = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
			result = t.global_position + diff.normalized() * clearance
	return result

# ============================================================
# Bugs can stack on terrain but not on other cards
# Other cards cannot stack on bugs (handled in base_card)
# ============================================================
func stack_on(new_parent: BaseCard) -> void:
	# Only allow stacking on terrain cards
	if new_parent != null and new_parent.role != CardEnums.CardRole.TERRAIN:
		return  # Reject: bugs don't stack on non-terrain
	super.stack_on(new_parent)
