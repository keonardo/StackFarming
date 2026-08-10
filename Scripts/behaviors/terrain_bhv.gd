# TerrainBehavior.gd — 地貌行为（GameConfig 由构造器注入）
class_name TerrainBehavior
extends RefCounted

var card: TerrainCard
var cfg: Node  # GameConfig autoload reference
var bug_spawn_timer: float = 0.0
var fish_spawn_timer: float = 0.0
var buff_timer: float = 0.0
var buff_multiplier: float = 1.0
var feces_cooldown: bool = false
var feces_cooldown_timer: float = 0.0

func _init(p_card: TerrainCard, p_cfg: Node) -> void:
	card = p_card
	cfg = p_cfg

func process(delta: float) -> void:
	if not is_instance_valid(card): return
	var ste := SolarTermEngine.instance
	match card.type:
		CardEnums.CardType.PADDY_FIELD:
			var decay_mult: float = ste.get_moisture_decay_multiplier() if ste else 1.0
			card.moisture -= cfg.moisture_decay * decay_mult * delta
			card.moisture = max(0.0, card.moisture)
		CardEnums.CardType.FISH_POND:
			fish_spawn_timer += delta
			if fish_spawn_timer >= cfg.fishpond_spawn_sec:
				fish_spawn_timer = 0.0
				var cnt: int = card.count_children_of_type(CardEnums.CardType.FISH)
				if cnt < card.capacity:
					var fpos: Vector2 = card.global_position + Vector2(randf_range(-30, 30), randf_range(-30, 30))
					if CardSpawner.instance:
						var fish: BaseCard = CardSpawner.instance.spawn_card(CardEnums.CardType.FISH, "鱼", fpos)
						if fish: fish.call_deferred("stack_on", card)
	_tick_timers(delta)
	if _has_crop(): _process_bugs(delta)

func _tick_timers(delta: float) -> void:
	if buff_timer > 0.0:
		buff_timer -= delta
		if buff_timer <= 0.0: buff_multiplier = 1.0
	if feces_cooldown:
		feces_cooldown_timer -= delta
		if feces_cooldown_timer <= 0.0: feces_cooldown = false

func _has_crop() -> bool:
	for c in card.get_stack_chain():
		if c.type in [CardEnums.CardType.WILD_RICE_SEED, CardEnums.CardType.WATER_CALTROP]: return true
	return false

func _process_bugs(delta: float) -> void:
	var ste := SolarTermEngine.instance
	var fc: int = card.count_children_of_type(CardEnums.CardType.FECES)
	var chance: float = cfg.bug_spawn_pct + float(fc) * cfg.feces_bug_bonus
	if ste:
		chance *= ste.get_bug_spawn_multiplier()
	var interval: float = max(5.0, cfg.bug_spawn_sec - float(fc) * cfg.feces_bug_faster)
	var cap: int = cfg.bug_max_field * (2 if fc >= cfg.feces_overload else 1)
	bug_spawn_timer += delta
	if bug_spawn_timer >= interval:
		bug_spawn_timer = 0.0
		if card.count_children_of_type(CardEnums.CardType.BUG) < cap and randf() < chance:
			var bpos: Vector2 = card.global_position + Vector2(randf_range(-30, 30), randf_range(-30, 30))
			if CardSpawner.instance:
				var bug: BaseCard = CardSpawner.instance.spawn_card(CardEnums.CardType.BUG, "虫", bpos)
				if bug: bug.call_deferred("stack_on", card)

func on_card_stacked(sc: BaseCard) -> bool:
	if card.type != CardEnums.CardType.PADDY_FIELD: return false
	if sc.type == CardEnums.CardType.WATER:
		card.moisture = min(100.0, card.moisture + sc.intensity); sc.queue_free(); return true
	if sc.type == CardEnums.CardType.FECES and not feces_cooldown:
		buff_multiplier = cfg.feces_buff_mult
		buff_timer = cfg.feces_buff_sec
		feces_cooldown = true
		feces_cooldown_timer = cfg.feces_cooldown
		sc.queue_free()
		return true
	if sc.type == CardEnums.CardType.FERTILIZER:
		buff_multiplier = cfg.fert_buff_mult
		buff_timer = cfg.fert_buff_sec
		sc.queue_free()
		return true
	return false

func get_growth_mult() -> float:
	var mm: float = 1.0
	if card.type == CardEnums.CardType.PADDY_FIELD:
		if card.moisture > cfg.crop_moisture_fast:     mm = cfg.crop_growth_fast
		elif card.moisture >= cfg.crop_moisture_slow:   mm = 1.0
		elif card.moisture > 0.0:                       mm = cfg.crop_growth_slow
		else:                                           mm = 0.0
	return max(buff_multiplier, mm)
