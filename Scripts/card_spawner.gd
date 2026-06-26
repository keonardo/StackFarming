# CardSpawner.gd — singleton card factory
extends Node
class_name CardSpawner

# ============================================================
# Singleton
# ============================================================
static var instance: CardSpawner = null

# ============================================================
# Preloaded scenes
# ============================================================
var _resource_card_scene: PackedScene = null
var _creature_card_scene: PackedScene = null
var _container_card_scene: PackedScene = null
var _pest_card_scene: PackedScene = null

# ============================================================
# Lifecycle
# ============================================================
func _enter_tree() -> void:
	instance = self
	_resource_card_scene = load("res://Scenes/resource_card.tscn")
	_creature_card_scene = load("res://Scenes/creature_card.tscn")
	_container_card_scene = load("res://Scenes/container_card.tscn")
	_pest_card_scene = load("res://Scenes/pest_card.tscn")

func _exit_tree() -> void:
	if instance == self:
		instance = null

# ============================================================
# Spawn helpers
# ============================================================
func spawn_resource_card(card_type: CardEnums.CardType, card_name_str: String, position: Vector2) -> BaseCard:
	var card: BaseCard
	if _resource_card_scene != null:
		card = _resource_card_scene.instantiate() as BaseCard
	else:
		card = BaseCard.new()
		_add_collision_to_card(card)

	card.role = CardEnums.CardRole.RESOURCE
	card.type = card_type
	card.card_name = card_name_str
	card.value_a = 10.0   # Default intensity
	card.value_b = 60.0   # Default duration
	card.global_position = position

	get_tree().root.call_deferred("add_child", card)
	return card

func spawn_creature_card(card_type: CardEnums.CardType, card_name_str: String, position: Vector2) -> CreatureCard:
	var card: CreatureCard
	if _creature_card_scene != null:
		card = _creature_card_scene.instantiate() as CreatureCard
	else:
		card = CreatureCard.new()
		_add_collision_to_card(card)

	card.role = CardEnums.CardRole.CREATURE
	card.type = card_type
	card.card_name = card_name_str
	card.value_a = 100.0  # Default health
	card.value_b = 0.0    # Default progress
	card.global_position = position

	get_tree().root.call_deferred("add_child", card)
	return card

func spawn_pest_card(position: Vector2) -> PestCard:
	var card: PestCard
	if _pest_card_scene != null:
		card = _pest_card_scene.instantiate() as PestCard
	else:
		card = PestCard.new()
		_add_collision_to_card(card)

	card.role = CardEnums.CardRole.CREATURE
	card.type = CardEnums.CardType.PEST
	card.card_name = "害虫"
	card.value_a = 50.0   # Default health
	card.value_b = 0.0
	card.global_position = position

	get_tree().root.call_deferred("add_child", card)
	return card

func spawn_container_card(card_type: CardEnums.CardType, card_name_str: String, position: Vector2) -> ContainerCard:
	var card: ContainerCard
	if _container_card_scene != null:
		card = _container_card_scene.instantiate() as ContainerCard
	else:
		card = ContainerCard.new()
		_add_collision_to_card(card)

	card.role = CardEnums.CardRole.CONTAINER
	card.type = card_type
	card.card_name = card_name_str
	card.value_a = 5.0    # Default capacity
	card.value_b = 100.0  # Default moisture
	card.global_position = position

	get_tree().root.call_deferred("add_child", card)
	return card

# ============================================================
# Helpers
# ============================================================
func _add_collision_to_card(card: Area2D) -> void:
	var collision_shape := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = Vector2(80, 100)
	collision_shape.shape = rect_shape
	card.add_child(collision_shape)
