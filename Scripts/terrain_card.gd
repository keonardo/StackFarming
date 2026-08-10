# TerrainCard.gd — 地貌卡牌基类，委托行为到 behaviors/terrain_bhv.gd
extends BaseCard
class_name TerrainCard

@export var is_irrigated: bool = false

var _bhv: TerrainBehavior = null

func _ready() -> void:
	super._ready()
	role = CardEnums.CardRole.TERRAIN
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

func _process(delta: float) -> void:
	super._process(delta)
	if not is_instance_valid(self): return
	if _bhv: _bhv.process(delta)

func _exit_tree() -> void:
	var im := get_node_or_null("/root/IrrigationManager") as IrrigationManager
	if im:
		im.unregister_terrain(self)

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
	var pos: Vector2 = global_position; var kids: Array = []
	for c in get_stack_chain():
		if c != self and c != second: kids.append(c)
	for c in kids:
		if is_instance_valid(c): c.stack_parent = null
	second.queue_free(); queue_free()
	if CardSpawner.instance:
		var bp: BaseCard = CardSpawner.instance.spawn_card(CardEnums.CardType.BIG_POND, "大水塘", pos)
		if bp: for c in kids: c.call_deferred("stack_on", bp)

func _merge_fish_pond() -> void:
	var pos: Vector2 = global_position; var fish_ate: int = 0; var kids: Array = []
	for c in get_stack_chain():
		if c != self:
			if c.type == CardEnums.CardType.FISH and fish_ate < 2:
				fish_ate += 1; c.queue_free()
			else: kids.append(c)
	for c in kids: c.stack_parent = null
	queue_free()
	if CardSpawner.instance:
		var fp: BaseCard = CardSpawner.instance.spawn_card(CardEnums.CardType.FISH_POND, "鱼塘", pos)
		if fp: for c in kids: c.call_deferred("stack_on", fp)

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
