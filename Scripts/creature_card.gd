# CreatureCard.gd — 生物卡牌基类，委托行为到 behaviors/*.gd
extends BaseCard
class_name CreatureCard

var _behavior: RefCounted = null

func _ready() -> void:
	super._ready()
	role = CardEnums.CardRole.CREATURE
	match type:
		CardEnums.CardType.DUCK:
			_behavior = DuckBehavior.new(self, get_node("/root/GameConfig"))
		CardEnums.CardType.WILD_RICE_SEED, CardEnums.CardType.WATER_CALTROP:
			_behavior = CropBehavior.new(self, get_node("/root/GameConfig"))

func _process(delta: float) -> void:
	super._process(delta)
	if not is_instance_valid(self): return
	if _behavior: _behavior.process(delta)
