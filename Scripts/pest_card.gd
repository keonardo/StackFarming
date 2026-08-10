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

# ============================================================
# Lifecycle
# ============================================================
func _ready() -> void:
	super._ready()
	role = CardEnums.CardRole.CREATURE
	type = CardEnums.CardType.BUG
	card_name = "虫"

func _process(delta: float) -> void:
	super._process(delta)

# ============================================================
# Bugs can stack on terrain but not on other cards
# Other cards cannot stack on bugs (handled in base_card)
# ============================================================
func stack_on(new_parent: BaseCard) -> void:
	# Only allow stacking on terrain cards
	if new_parent != null and new_parent.role != CardEnums.CardRole.TERRAIN:
		return  # Reject: bugs don't stack on non-terrain
	super.stack_on(new_parent)
