# SolarTermEngine.gd — 24 solar term cycle driver
extends Node
class_name SolarTermEngine

# ============================================================
# Singleton
# ============================================================
static var instance: SolarTermEngine = null

# ============================================================
# Static globals (accessed by other scripts)
# ============================================================
static var current_term: CardEnums.SolarTerm = CardEnums.SolarTerm.NONE
static var crop_growth_speed_modifier: float = 1.0

# ============================================================
# Exported properties
# ============================================================
@export var term_duration: float = 120.0  # Seconds per term

# ============================================================
# Signals
# ============================================================
signal term_changed(term_name: String)

# ============================================================
# State
# ============================================================
var _term_timer: float = 0.0
var _term_index: int = 0
var _term_cycle: Array[CardEnums.SolarTerm] = [
	CardEnums.SolarTerm.NONE,
	CardEnums.SolarTerm.JINGZHE,
	CardEnums.SolarTerm.MANGZHONG,
	CardEnums.SolarTerm.SHUANGJIANG,
]

# ============================================================
# Lifecycle
# ============================================================
func _enter_tree() -> void:
	instance = self

func _exit_tree() -> void:
	if instance == self:
		instance = null

func _ready() -> void:
	current_term = CardEnums.SolarTerm.NONE
	crop_growth_speed_modifier = 1.0
	_term_timer = 0.0

func _process(delta: float) -> void:
	_term_timer += delta
	if _term_timer >= term_duration:
		_term_timer = 0.0
		_rotate_solar_term()

	if current_term == CardEnums.SolarTerm.SHUANGJIANG:
		_process_shuangjiang_frost_damage(delta)

# ============================================================
# Term rotation
# ============================================================
func _rotate_solar_term() -> void:
	_term_index = (_term_index + 1) % _term_cycle.size()
	var old_term: CardEnums.SolarTerm = current_term
	current_term = _term_cycle[_term_index]

	var term_name_str: String = CardEnums.SolarTerm.keys()[current_term]
	term_changed.emit(term_name_str)
	print("[Solar Term Engine] Term changed to: ", term_name_str)

	# Cleanup old term
	if old_term == CardEnums.SolarTerm.SHUANGJIANG:
		crop_growth_speed_modifier = 1.0

	# Trigger new term events
	_trigger_term_events(current_term)

func _trigger_term_events(term: CardEnums.SolarTerm) -> void:
	match term:
		CardEnums.SolarTerm.JINGZHE:
			_trigger_jingzhe_events()
		CardEnums.SolarTerm.MANGZHONG:
			_trigger_mangzhong_events()
		CardEnums.SolarTerm.SHUANGJIANG:
			crop_growth_speed_modifier = 2.0
			print("[Solar Term Engine] Shuangjiang active: Crop growth rate +100%")

# ============================================================
# Jingzhe: spawn pests on all rice fields
# ============================================================
func _trigger_jingzhe_events() -> void:
	print("[Solar Term Engine] Jingzhe active: Spawning pests on all Rice Fields!")
	var farmlands: Array[ContainerCard] = []
	_find_farmlands(get_tree().root, farmlands)

	for farmland in farmlands:
		if farmland.card_name.contains("水稻田") or farmland.card_name.contains("Rice Field"):
			var pest_count: int = randi_range(3, 5)
			for i in range(pest_count):
				var offset: Vector2 = Vector2(randf_range(-20, 20), randf_range(-20, 20))
				if CardSpawner.instance != null:
					CardSpawner.instance.spawn_pest_card(farmland.global_position + offset)
			print("[Jingzhe Event] Spawned ", pest_count, " pests on ", farmland.card_name)

# ============================================================
# Mangzhong: drought — disable non-deep-water irrigation
# ============================================================
func _trigger_mangzhong_events() -> void:
	print("[Solar Term Engine] Mangzhong active: Drought! Disabling non-DeepWaterFishPond irrigation.")
	var containers: Array[ContainerCard] = []
	_find_containers(get_tree().root, containers)

	for c in containers:
		if c.type != CardEnums.CardType.DEEP_WATER_FISH_POND:
			c.is_irrigated = false

	if IrrigationManager.instance != null:
		IrrigationManager.instance.check_irrigation_linkage()

# ============================================================
# Shuangjiang: frost damage to exposed tropical creatures
# ============================================================
func _process_shuangjiang_frost_damage(delta: float) -> void:
	var creatures: Array[CreatureCard] = []
	_find_creatures(get_tree().root, creatures)

	for creature in creatures:
		if creature.card_name.contains("热带") or creature.card_name.to_lower().contains("tropical"):
			if creature.get_container() == null:
				print("[Frost Damage] Exposed tropical creature ", creature.card_name, " is losing health to frost!")
				creature.health -= 10.0 * delta

# ============================================================
# Scene tree search helpers
# ============================================================
func _find_farmlands(node: Node, farmlands: Array[ContainerCard]) -> void:
	if node is ContainerCard and node.type == CardEnums.CardType.FARMLAND and is_instance_valid(node):
		farmlands.append(node as ContainerCard)
	for i in range(node.get_child_count()):
		_find_farmlands(node.get_child(i), farmlands)

func _find_containers(node: Node, containers: Array[ContainerCard]) -> void:
	if node is ContainerCard and is_instance_valid(node):
		containers.append(node as ContainerCard)
	for i in range(node.get_child_count()):
		_find_containers(node.get_child(i), containers)

func _find_creatures(node: Node, creatures: Array[CreatureCard]) -> void:
	if node is CreatureCard and is_instance_valid(node):
		creatures.append(node as CreatureCard)
	for i in range(node.get_child_count()):
		_find_creatures(node.get_child(i), creatures)
