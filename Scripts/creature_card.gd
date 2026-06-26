# CreatureCard.gd — animal/crop/fish behavior
extends BaseCard
class_name CreatureCard

# ============================================================
# Exported properties
# ============================================================
@export var metabolism_rate: float = 10.0      # Progress per second (animals)
@export var base_crop_growth_rate: float = 5.0  # Percent per second (crops)
@export var feces_multiplier: float = 1.5       # Feces intensity multiplier
@export var over_capacity_crop_damage: float = 8.0  # Damage per second when over capacity
@export var prey_check_interval: float = 1.0    # Interaction check interval

# ============================================================
# Signals
# ============================================================
signal on_pest_detected(predator: CreatureCard, prey: PestCard)

# ============================================================
# State
# ============================================================
var _interaction_timer: float = 0.0

# ============================================================
# Lifecycle
# ============================================================
func _ready() -> void:
	super._ready()
	role = CardEnums.CardRole.CREATURE
	if health <= 0.0:
		health = 100.0

func _process(delta: float) -> void:
	super._process(delta)

	match type:
		CardEnums.CardType.ANIMAL:
			_process_animal_metabolism(delta)
			_process_animal_interactions(delta)
		CardEnums.CardType.CROP:
			_process_crop_growth(delta)

# ============================================================
# Animal metabolism — produce feces when progress fills
# ============================================================
func _process_animal_metabolism(delta: float) -> void:
	progress += metabolism_rate * delta

	if progress >= 100.0:
		progress = 0.0
		_spawn_feces()

# ============================================================
# Animal interactions — predation & betrayal
# ============================================================
func _process_animal_interactions(delta: float) -> void:
	_interaction_timer += delta
	if _interaction_timer < prey_check_interval:
		return
	_interaction_timer = 0.0

	var container: ContainerCard = get_container()
	if container == null:
		return

	# 1. Predation: look for pests in the container
	var pest: PestCard = _find_pest_in_container(container)
	if pest != null and is_instance_valid(pest):
		print("[Predation] ", card_name, " ate a pest ", pest.card_name, "!")
		on_pest_detected.emit(self, pest)
		play_predation_animation(pest.global_position)

		pest.queue_free()
		progress = 0.0
		_spawn_feces()
		play_produce_animation()
		return  # Skip betrayal this round

	# 2. Betrayal: too many animals — damage crops
	var animal_count: int = container.get_animal_count()
	if animal_count > container.capacity:
		print("[Betrayal] Overcapacity! Animals (", animal_count, "/", container.capacity, ") damage crops in ", container.card_name, ".")
		container.apply_animal_betrayal_damage(over_capacity_crop_damage * prey_check_interval)

# ============================================================
# Crop growth — feces accelerates progress
# ============================================================
func _process_crop_growth(delta: float) -> void:
	var feces_intensity: float = 0.0
	var child: BaseCard = stack_child

	while child != null:
		if child.type == CardEnums.CardType.FECES:
			feces_intensity += child.value_a
		child = child.stack_child

	var growth_rate: float = base_crop_growth_rate + feces_intensity * feces_multiplier
	growth_rate *= SolarTermEngine.crop_growth_speed_modifier

	progress += growth_rate * delta

	if progress >= 100.0:
		progress = 0.0
		print("[Crop] ", card_name, " matured! Harvested grain.")
		if CardSpawner.instance != null:
			CardSpawner.instance.spawn_resource_card(
				CardEnums.CardType.DRY_GRASS, "稻谷",
				global_position + Vector2(20, 20)
			)

# ============================================================
# Helpers
# ============================================================
func _spawn_feces() -> void:
	print("[Metabolism] ", card_name, " generated feces!")
	play_produce_animation()
	var offset: Vector2 = Vector2(randf_range(-15, 15), randf_range(-15, 15))
	if CardSpawner.instance != null:
		CardSpawner.instance.spawn_resource_card(
			CardEnums.CardType.FECES, "粪便卡", global_position + offset
		)

func _find_pest_in_container(container: ContainerCard) -> PestCard:
	for area in container.get_overlapping_areas():
		if area is PestCard and is_instance_valid(area):
			return area as PestCard
	return null
