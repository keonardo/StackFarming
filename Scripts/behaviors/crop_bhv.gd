# CropBehavior.gd — 作物生长逻辑（GameConfig 由构造器注入）
class_name CropBehavior
extends RefCounted

var card: BaseCard
var cfg: Node  # GameConfig autoload reference

func _init(p_card: BaseCard, p_cfg: Node) -> void:
	card = p_card
	cfg = p_cfg

func process(delta: float) -> void:
	if not is_instance_valid(card): return
	match card.type:
		CardEnums.CardType.WILD_RICE_SEED: _process_wild_rice(delta)
		CardEnums.CardType.WATER_CALTROP:  _process_caltrop(delta)

func _process_wild_rice(delta: float) -> void:
	var terrain: TerrainCard = card.get_terrain()
	if not terrain or terrain.type != CardEnums.CardType.PADDY_FIELD: return
	var mult: float = terrain.get_growth_multiplier()
	var ste := SolarTermEngine.instance
	if ste:
		mult *= ste.get_growth_multiplier()
	if mult <= 0.0:
		card.health -= cfg.crop_dry_decay * delta
		return
	card.progress += cfg.crop_growth_rate * mult * delta
	if card.progress >= 100.0:
		_harvest(CardEnums.CardType.WILD_RICE, "菰米")
	_apply_bug_damage(delta, terrain)

func _process_caltrop(delta: float) -> void:
	var terrain: TerrainCard = card.get_terrain()
	if not terrain or not terrain.is_water_terrain(): return
	var mult: float = 1.0
	var ste := SolarTermEngine.instance
	if ste:
		mult *= ste.get_growth_multiplier()
	card.progress += cfg.crop_growth_rate * mult * delta
	if card.progress >= 100.0:
		_harvest(CardEnums.CardType.CALTROP, "菱角")
	_apply_bug_damage(delta, terrain)

func _harvest(product_type: int, product_name: String) -> void:
	card.progress = 0.0; card.play_produce_animation()
	var pos: Vector2 = card.global_position + Vector2(randf_range(-20, 20), randf_range(20, 40))
	if CardSpawner.instance:
		var p: BaseCard = CardSpawner.instance.spawn_card(product_type, product_name, pos)
		if p and is_instance_valid(card): p.call_deferred("stack_on", card)

func _apply_bug_damage(delta: float, terrain: TerrainCard) -> void:
	if not terrain: return
	var bug_count: int = terrain.count_children_of_type(CardEnums.CardType.BUG)
	if bug_count > 0:
		card.health -= cfg.crop_bug_damage * delta * float(bug_count)
