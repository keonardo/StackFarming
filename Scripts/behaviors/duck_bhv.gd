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
