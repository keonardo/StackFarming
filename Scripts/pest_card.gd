# PestCard.gd — pest that attaches to crops and damages them
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

# ============================================================
# Lifecycle
# ============================================================
func _ready() -> void:
	super._ready()
	role = CardEnums.CardRole.CREATURE
	type = CardEnums.CardType.PEST
	card_name = "害虫"
	if health <= 0.0:
		health = 50.0

func _process(delta: float) -> void:
	if _is_dragging:
		super._process(delta)
		_target_crop = null
		return

	super._process(delta)

	if health <= 0.0:
		return

	_timer += delta
	if _timer >= target_search_interval:
		_timer = 0.0
		_execute_pest_behavior(target_search_interval)

	# Smooth movement toward attached crop
	if _target_crop != null and is_instance_valid(_target_crop):
		global_position = global_position.lerp(
			_target_crop.global_position + Vector2(10, -10), delta * 5.0
		)

# ============================================================
# Pests don't stack — override
# ============================================================
func stack_on(new_parent: BaseCard) -> void:
	# Pests cannot participate in normal stacking
	if new_parent != null:
		unstack()

# ============================================================
# Pest behavior
# ============================================================
func _execute_pest_behavior(seconds: float) -> void:
	if _target_crop == null or not is_instance_valid(_target_crop) or _target_crop.health <= 0.0:
		_target_crop = null
		_find_new_target_crop()

	if _target_crop != null and is_instance_valid(_target_crop):
		print("[Pest Attack] Pest ", card_name, " is attacking crop ",
			_target_crop.card_name, ". Damaging health by ", damage_per_second * seconds, ".")
		_target_crop.health -= damage_per_second * seconds

func _find_new_target_crop() -> void:
	var container: ContainerCard = _find_current_container()
	if container == null:
		return

	var stack: Array[BaseCard] = container.get_stack_chain()
	var crops: Array[BaseCard] = []

	for card in stack:
		if card.type == CardEnums.CardType.CROP and card.health > 0.0:
			crops.append(card)

	if crops.size() > 0:
		var idx: int = randi_range(0, crops.size() - 1)
		_target_crop = crops[idx]
		print("[Pest] Attached to new crop target: ", _target_crop.card_name)

func _find_current_container() -> ContainerCard:
	for area in get_overlapping_areas():
		if area is ContainerCard and is_instance_valid(area):
			return area as ContainerCard
	return null
