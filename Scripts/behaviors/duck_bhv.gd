# DuckBehavior.gd — 鸭子专用行为（GameConfig 由构造器注入）
class_name DuckBehavior
extends RefCounted

var card: BaseCard
var cfg: Node                # GameConfig autoload reference
var hatch_timer: float = 0.0
var hatching_egg: BaseCard = null
var feces_timer: float = 0.0
var eat_cooldown: float = 0.0
var betrayal_timer: float = 0.0   # 背叛攻击冷却

# ── 移动 AI 状态 ──
enum MoveState { IDLE, CHASE, RETURN }
var move_state: MoveState = MoveState.IDLE
var _wander_dir: Vector2 = Vector2.RIGHT
var _turn_timer: float = 0.0
var _chase_target: BaseCard = null

func _init(p_card: BaseCard, p_cfg: Node) -> void:
	card = p_card
	cfg = p_cfg

func process(delta: float) -> void:
	if not is_instance_valid(card): return
	var terrain: TerrainCard = card.get_terrain()
	var on_water: bool = terrain != null and terrain.is_water_terrain()

	if on_water:
		card.health = min(100.0, card.health + cfg.duck_hunger_rate_water * delta)
		if card.health >= cfg.duck_full_threshold:
			card.progress += cfg.duck_egg_rate * delta
			if card.progress >= cfg.duck_egg_max:
				_lay_egg(terrain)
	else:
		card.health += cfg.duck_hunger_rate_land * delta

	if on_water:
		feces_timer += delta
		if feces_timer >= cfg.duck_feces_interval:
			feces_timer = 0.0
			_spawn_feces(terrain)

	_check_eat_bug()
	if terrain != null and _can_hatch(terrain):
		_process_hatch(delta, terrain)

	# 背叛机制：无害虫且鸭子超载 → 转攻作物/鱼苗
	betrayal_timer -= delta
	if terrain != null and betrayal_timer <= 0.0:
		_check_betrayal(terrain)

	# 移动 AI
	_process_movement(delta, terrain)

func _lay_egg(_terrain: TerrainCard) -> void:
	card.progress = 0.0
	card.play_produce_animation()
	var pos: Vector2 = card.global_position + Vector2(randf_range(-20, 20), randf_range(20, 40))
	if CardSpawner.instance:
		var egg: BaseCard = CardSpawner.instance.spawn_card(CardEnums.CardType.DUCK_EGG, "鸭蛋", pos)
		if egg and is_instance_valid(card): egg.call_deferred("stack_on", card)

func _spawn_feces(terrain: TerrainCard) -> void:
	var pos: Vector2 = card.global_position + Vector2(randf_range(-15, 15), randf_range(15, 30))
	if CardSpawner.instance:
		var feces: BaseCard = CardSpawner.instance.spawn_card(CardEnums.CardType.FECES, "粪便", pos)
		if feces and is_instance_valid(card): feces.call_deferred("stack_on", card)

func _check_eat_bug() -> void:
	eat_cooldown -= 0.016
	if eat_cooldown > 0.0 or card.health >= cfg.duck_full_threshold: return
	for area in card.get_overlapping_areas():
		if area is BaseCard and is_instance_valid(area) and area.type == CardEnums.CardType.BUG:
			eat_cooldown = 0.5
			card.health = min(100.0, card.health + cfg.duck_eat_bug_fill)
			card.play_produce_animation()
			area.queue_free()
			return

## 背叛机制：地块无害虫且鸭子数量超过承载上限 → 攻击作物/鱼苗
func _check_betrayal(terrain: TerrainCard) -> void:
	betrayal_timer = cfg.duck_betrayal_interval

	# 前提：地块无害虫
	if terrain.get_bug_list().size() > 0:
		return
	# 前提：鸭子数量超过承载上限
	if terrain.get_duck_count() <= cfg.max_ducks_per_pond:
		return

	var target: BaseCard = _find_betrayal_target(terrain)
	if target == null:
		return

	# 执行攻击
	card.play_predation_animation(target.global_position)
	_damage_betrayal_target(target)

## 在堆叠链中找可攻击目标：优先作物种子（有 health），其次鱼苗（用 intensity）
func _find_betrayal_target(terrain: TerrainCard) -> BaseCard:
	var fish_target: BaseCard = null
	for c in terrain.get_stack_chain():
		if not is_instance_valid(c) or c == card:
			continue
		match c.type:
			CardEnums.CardType.WILD_RICE_SEED, CardEnums.CardType.WATER_CALTROP:
				return c  # 作物种子优先，有 health
			CardEnums.CardType.FISH:
				if fish_target == null:
					fish_target = c
	return fish_target

## 伤害结算：作物扣 health，鱼扣 intensity
func _damage_betrayal_target(target: BaseCard) -> void:
	var dmg: float = cfg.duck_betrayal_damage
	match target.type:
		CardEnums.CardType.WILD_RICE_SEED, CardEnums.CardType.WATER_CALTROP:
			target.health -= dmg
			target.play_hit_animation()
		CardEnums.CardType.FISH:
			target.intensity -= dmg
			target.play_hit_animation()
			if target.intensity <= 0.0:
				target.queue_free()

# ============================================================
# 移动 AI（M1/M2 + 归巢）
# ============================================================
func _process_movement(delta: float, terrain: TerrainCard) -> void:
	# 拖拽中不抢控制权
	if card._is_dragging:
		return

	# 1) 检测视野内是否有虫 → 追击
	var bug := _find_nearest_bug_in_range(terrain)
	if bug != null:
		move_state = MoveState.CHASE
		_chase_target = bug
	elif move_state == MoveState.CHASE:
		# 目标消失/离远 → 回空闲
		move_state = MoveState.IDLE
		_chase_target = null

	# 2) 归巢判定：无地貌 → 游向最近水域；到达后吸附栖水恢复 IDLE
	if move_state != MoveState.CHASE:
		var water := _find_nearest_water()
		if terrain == null:
			if water == null or not is_instance_valid(water):
				# 无水域可归 → 原地自由游动
				move_state = MoveState.IDLE
				_chase_target = null
			elif card.global_position.distance_to(water.global_position) <= 90.0:
				# 已到水域 → 吸附到水域栖息，恢复正常行为
				card.call_deferred("stack_on", water)
				move_state = MoveState.IDLE
				_chase_target = null
			elif card.global_position.distance_to(water.global_position) > cfg.duck_return_threshold:
				# 离水域过远 → 主动归巢
				move_state = MoveState.RETURN
				_chase_target = water
			else:
				# 距水域不算远 → 不强制归巢，自由游动
				move_state = MoveState.IDLE
		else:
			move_state = MoveState.IDLE

	# 3) 按状态移动
	match move_state:
		MoveState.CHASE:
			_move_towards(_chase_target.global_position, cfg.duck_chase_speed, delta)
		MoveState.RETURN:
			if _chase_target != null and is_instance_valid(_chase_target):
				_move_towards(_chase_target.global_position, cfg.duck_idle_speed, delta)
			else:
				move_state = MoveState.IDLE
		MoveState.IDLE:
			_wander(terrain, cfg.duck_terrain_boundary, cfg.duck_idle_speed, delta)

## 视野内找最近虫（全局遍历所有地貌卡的堆叠链）
func _find_nearest_bug_in_range(terrain: TerrainCard) -> BaseCard:
	var best: BaseCard = null
	var best_dist: float = cfg.duck_vision_range

	var im := card.get_node_or_null("/root/IrrigationManager") as IrrigationManager
	if im == null:
		return null

	for t in im.get_all_terrains():
		if not is_instance_valid(t):
			continue
		for c in t.get_stack_chain():
			if c.type == CardEnums.CardType.BUG and is_instance_valid(c) and c != card:
				var d: float = card.global_position.distance_to(c.global_position)
				if d < best_dist:
					best_dist = d
					best = c
	return best

## 找最近水域地貌
func _find_nearest_water() -> TerrainCard:
	var im := card.get_node_or_null("/root/IrrigationManager") as IrrigationManager
	if im == null:
		return null
	var best: TerrainCard = null
	var best_dist: float = INF
	for t in im.get_all_terrains():
		if not is_instance_valid(t):
			continue
		if t.is_water_terrain() and not t._is_dragging:
			var d: float = card.global_position.distance_to(t.global_position)
			if d < best_dist:
				best_dist = d
				best = t
	return best

func _move_towards(target_pos: Vector2, speed: float, delta: float) -> void:
	card.free_move = true
	var dir: Vector2 = target_pos - card.global_position
	if dir.length() > 4.0:
		var desired: Vector2 = card.global_position + dir.normalized() * speed * delta
		card.global_position = _apply_terrain_avoidance(desired)

## 空闲巡逻：地貌范围内随机漫步，无地貌自由漂移
func _wander(terrain: TerrainCard, boundary: float, speed: float, delta: float) -> void:
	card.free_move = true
	_turn_timer -= delta
	if _turn_timer <= 0.0:
		_turn_timer = randf_range(cfg.wander_turn_interval_min, cfg.wander_turn_interval_max)
		_wander_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		if _wander_dir == Vector2.ZERO:
			_wander_dir = Vector2.RIGHT

	var desired: Vector2 = card.global_position + _wander_dir * speed * delta
	desired = _apply_terrain_avoidance(desired)

	# 边界约束：有地貌则拉回范围内
	if terrain != null and is_instance_valid(terrain):
		var center: Vector2 = terrain.global_position
		var offset: Vector2 = desired - center
		if offset.length() > boundary:
			desired = center + offset.normalized() * boundary

	card.global_position = desired

## 软排斥避障：将目标位置从其他地形卡推开（每帧推离叠加移动方向 → 形成绕行）
func _apply_terrain_avoidance(desired_pos: Vector2) -> Vector2:
	var result := desired_pos
	var own: TerrainCard = card.get_terrain()
	var im := card.get_node_or_null("/root/IrrigationManager") as IrrigationManager
	if im == null:
		return result
	for t in im.get_all_terrains():
		if not is_instance_valid(t) or t == own or t._is_dragging:
			continue
		var diff: Vector2 = result - t.global_position
		var d: float = diff.length()
		var clearance: float = cfg.duck_terrain_clearance
		if d < clearance:
			if d < 0.1:
				diff = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
			result = t.global_position + diff.normalized() * clearance
	return result

func _can_hatch(terrain: TerrainCard) -> bool:
	if terrain.type not in [CardEnums.CardType.BIG_POND, CardEnums.CardType.FISH_POND]: return false
	if terrain.get_duck_count() < 2: return false
	var ducks: Array[BaseCard] = terrain.get_ducks_sorted_by_instance_id()
	if ducks.size() < 2 or ducks[0] != card: return false
	for c in terrain.get_stack_chain():
		if c.type == CardEnums.CardType.DUCK_EGG and is_instance_valid(c):
			if not hatching_egg or not is_instance_valid(hatching_egg): hatching_egg = c; hatch_timer = 0.0
			return true
	return false

func _process_hatch(delta: float, terrain: TerrainCard) -> void:
	if not hatching_egg or not is_instance_valid(hatching_egg): hatching_egg = null; hatch_timer = 0.0; return
	if terrain.get_duck_count() < 2: hatching_egg = null; hatch_timer = 0.0; return
	hatch_timer += delta
	if hatch_timer >= cfg.duck_hatch_time:
		var pos: Vector2 = hatching_egg.global_position + Vector2(randf_range(-10, 10), 10)
		hatching_egg.queue_free(); hatching_egg = null; hatch_timer = 0.0
		if CardSpawner.instance:
			var duck: BaseCard = CardSpawner.instance.spawn_card(CardEnums.CardType.DUCK, "鸭子", pos)
			if duck and is_instance_valid(card): duck.call_deferred("stack_on", card)
		card.play_produce_animation()
