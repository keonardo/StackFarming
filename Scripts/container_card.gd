# ContainerCard.gd — farmland, river, canal, deep-water pond
extends BaseCard
class_name ContainerCard

# ============================================================
# Exported properties
# ============================================================
@export var is_irrigated: bool = false
@export var dry_health_decay_per_second: float = 15.0
@export var feces_pond_turning_threshold: int = 3

# ============================================================
# Signals
# ============================================================
signal pond_turned(container: ContainerCard)

# ============================================================
# State
# ============================================================
var _survival_timer: float = 0.0

# ============================================================
# Lifecycle
# ============================================================
func _ready() -> void:
	super._ready()
	role = CardEnums.CardRole.CONTAINER
	if capacity <= 0.0:
		capacity = 5.0
	if moisture <= 0.0:
		moisture = 100.0

func _process(delta: float) -> void:
	super._process(delta)

	_survival_timer += delta
	if _survival_timer >= 1.0:
		_survival_timer = 0.0
		_check_survival_and_imbalance(1.0)

# ============================================================
# Ecology check: moisture pressure + pond turning
# ============================================================
func _check_survival_and_imbalance(seconds: float) -> void:
	var stack: Array[BaseCard] = get_stack_chain()

	var feces_count: int = 0
	var crop_count: int = 0
	var aquatic_creatures: Array[BaseCard] = []
	var fish_creatures: Array[BaseCard] = []

	for card in stack:
		if card == self:
			continue

		match card.type:
			CardEnums.CardType.FECES:
				feces_count += 1
			CardEnums.CardType.CROP:
				crop_count += 1
				if card.card_name.contains("水稻") or card.card_name.to_lower().contains("rice"):
					aquatic_creatures.append(card)
			CardEnums.CardType.FISH:
				aquatic_creatures.append(card)
				fish_creatures.append(card)

	# 1. Moisture pressure: if not irrigated, aquatic creatures lose health
	if not is_irrigated:
		for creature in aquatic_creatures:
			if is_instance_valid(creature) and creature.health > 0.0:
				print("[Moisture Pressure] ", creature.card_name, " on ", card_name,
					" is drying out! Health -", dry_health_decay_per_second * seconds)
				creature.health -= dry_health_decay_per_second * seconds

	# 2. Pond turning: too much feces, no crops → kill all fish
	if feces_count >= feces_pond_turning_threshold and crop_count == 0:
		if fish_creatures.size() > 0:
			printerr("[POND TURNING] ", card_name, " flipped pond! Too much feces (",
				feces_count, ") and no crops. Fish are dying!")
			pond_turned.emit(self)

			for fish in fish_creatures:
				if is_instance_valid(fish) and fish.health > 0.0:
					fish.health = 0.0

# ============================================================
# Container queries
# ============================================================
func get_animal_count() -> int:
	var stack: Array[BaseCard] = get_stack_chain()
	var count: int = 0
	for card in stack:
		if card.type == CardEnums.CardType.ANIMAL:
			count += 1
	return count

func apply_animal_betrayal_damage(damage: float) -> void:
	var stack: Array[BaseCard] = get_stack_chain()
	for card in stack:
		if card.type == CardEnums.CardType.CROP and is_instance_valid(card) and card.health > 0.0:
			print("[Betrayal Damage] Crop ", card.card_name, " damaged by animals. Health -", damage)
			card.health -= damage
