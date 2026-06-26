# BaseCard.gd — base class for all stackable cards
extends Area2D
class_name BaseCard

# Preload CJK font (applied to all labels at runtime)
const CJK_FONT = preload("res://fonts/simhei.ttf")

# ============================================================
# Exported properties
# ============================================================
@export var role: CardEnums.CardRole = CardEnums.CardRole.CREATURE
@export var type: CardEnums.CardType = CardEnums.CardType.ANIMAL
@export var card_name: String = "Unnamed Card"
@export var show_debug_info: bool = true

@export var value_a: float = 0.0:
	set(v):
		value_a = v
		if role == CardEnums.CardRole.CREATURE and value_a <= 0.0 and not _is_dying:
			_is_dying = true
			on_health_zero()

@export var value_b: float = 0.0

# ============================================================
# Stack chain pointers
# ============================================================
var stack_parent: BaseCard = null
var stack_child: BaseCard = null

# ============================================================
# Signals
# ============================================================
signal stack_parent_changed(old_parent: BaseCard, new_parent: BaseCard)
signal stack_child_changed(old_child: BaseCard, new_child: BaseCard)
signal on_card_stacked(stacked_card: BaseCard, target_card: BaseCard)
signal health_zero(card: BaseCard)

# ============================================================
# Semantic property accessors
# ============================================================
## Creature: ValueA = Health
var health: float:
	get: return value_a if role == CardEnums.CardRole.CREATURE else 0.0
	set(v):
		if role == CardEnums.CardRole.CREATURE:
			value_a = max(0.0, v)

## Creature: ValueB = Progress
var progress: float:
	get: return value_b if role == CardEnums.CardRole.CREATURE else 0.0
	set(v):
		if role == CardEnums.CardRole.CREATURE:
			value_b = max(0.0, v)

## Resource: ValueA = Intensity
var intensity: float:
	get: return value_a if role == CardEnums.CardRole.RESOURCE else 0.0
	set(v):
		if role == CardEnums.CardRole.RESOURCE:
			value_a = v

## Resource: ValueB = Duration
var duration: float:
	get: return value_b if role == CardEnums.CardRole.RESOURCE else 0.0
	set(v):
		if role == CardEnums.CardRole.RESOURCE:
			value_b = max(0.0, v)

## Container: ValueA = Capacity
var capacity: float:
	get: return value_a if role == CardEnums.CardRole.CONTAINER else 0.0
	set(v):
		if role == CardEnums.CardRole.CONTAINER:
			value_a = max(0.0, v)

## Container: ValueB = Moisture
var moisture: float:
	get: return value_b if role == CardEnums.CardRole.CONTAINER else 0.0
	set(v):
		if role == CardEnums.CardRole.CONTAINER:
			value_b = max(0.0, v)

# ============================================================
# Internal state
# ============================================================
var _is_dying: bool = false
var _is_dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO

# ============================================================
# Lifecycle
# ============================================================
func _ready() -> void:
	input_pickable = true
	_apply_cjk_font_to_labels()
	call_deferred("_initialize_starting_stack")

func _apply_cjk_font_to_labels() -> void:
	# Walk all children recursively and set the CJK font on every Label
	_apply_font_recursive(self)

func _apply_font_recursive(node: Node) -> void:
	if node is Label:
		node.add_theme_font_override("font", CJK_FONT)
	for i in range(node.get_child_count()):
		_apply_font_recursive(node.get_child(i))

func _initialize_starting_stack() -> void:
	if stack_parent == null:
		var target: BaseCard = _find_best_stack_target()
		if target != null:
			stack_on(target)

func _process(delta: float) -> void:
	if _is_dragging:
		global_position = get_global_mouse_position() - _drag_offset
	elif stack_parent != null:
		var target_pos: Vector2 = stack_parent.global_position + Vector2(0, 35)
		global_position = global_position.lerp(target_pos, delta * 18.0)
		z_index = stack_parent.z_index + 1
	else:
		z_index = 0
		_process_mutual_pushing(delta)

	if stack_child != null:
		stack_child.z_index = z_index + 1

	# Resource card duration countdown
	if role == CardEnums.CardRole.RESOURCE:
		duration -= delta
		if duration <= 0.0:
			print("[Resource] ", card_name, " duration expired. Removing.")
			_unstack_and_remove()
			return

	_update_visuals()

# ============================================================
# Mutual pushing — prevent overlapping independent cards
# ============================================================
func _process_mutual_pushing(delta: float) -> void:
	if _is_dragging or stack_parent != null:
		return

	for area in get_overlapping_areas():
		if area is BaseCard and is_instance_valid(area):
			var other_card: BaseCard = area as BaseCard
			var other_root: BaseCard = other_card.get_stack_root()
			if other_root != self and not other_root._is_dragging:
				var diff: Vector2 = global_position - other_root.global_position
				var dist: float = diff.length()
				var push_threshold: float = 95.0

				if dist < push_threshold:
					var push_dir: Vector2
					if dist < 0.1:
						push_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
						dist = 1.0
					else:
						push_dir = diff / dist

					var force: float = (push_threshold - dist) * 12.0
					global_position += push_dir * force * delta

# ============================================================
# Visual updates (debug info overlay)
# ============================================================
func _update_visuals() -> void:
	var name_label: Label = get_node_or_null("Panel/NameLabel") as Label
	if name_label != null:
		name_label.text = card_name

	var panel: Control = get_node_or_null("Panel") as Control
	if panel != null:
		panel.visible = show_debug_info
	if not show_debug_info:
		return

	var val_a_label: Label = get_node_or_null("Panel/ValueALabel") as Label
	var val_b_label: Label = get_node_or_null("Panel/ValueBLabel") as Label
	var progress_bar: ProgressBar = get_node_or_null("Panel/ProgressBar") as ProgressBar

	match role:
		CardEnums.CardRole.CREATURE:
			if val_a_label != null:
				val_a_label.text = "HP: %.0f" % health
			if val_b_label != null:
				val_b_label.text = "Prog: %.0f%%" % progress
			if progress_bar != null:
				progress_bar.visible = true
				progress_bar.value = progress

		CardEnums.CardRole.RESOURCE:
			if val_a_label != null:
				val_a_label.text = "Int: %.1f" % intensity
			if val_b_label != null:
				val_b_label.text = "Dur: %.0fs" % duration
			if progress_bar != null:
				progress_bar.visible = false

		CardEnums.CardRole.CONTAINER:
			var irrigated: bool = false
			if self is ContainerCard:
				irrigated = (self as ContainerCard).is_irrigated
			var status_str: String = "(Irr)" if irrigated else "(Dry)"
			if val_a_label != null:
				val_a_label.text = "Cap: %.0f" % capacity
			if val_b_label != null:
				val_b_label.text = "Moist: %.0f %s" % [moisture, status_str]
			if progress_bar != null:
				progress_bar.visible = false

# ============================================================
# Input handling — drag & drop
# ============================================================
func _input_event(viewport: Viewport, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_is_dragging = true
			_drag_offset = get_global_mouse_position() - global_position
			z_index = 100
			if stack_parent != null:
				unstack()
			get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	if _is_dragging and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_is_dragging = false
			z_index = 0
			var target: BaseCard = _find_best_stack_target()
			if target != null:
				stack_on(target)
			get_viewport().set_input_as_handled()

# ============================================================
# Stack target finding
# ============================================================
func _find_best_stack_target() -> BaseCard:
	var best_target: BaseCard = null
	var min_distance: float = 100.0

	for area in get_overlapping_areas():
		if area is BaseCard and area != self and is_instance_valid(area):
			var card: BaseCard = area as BaseCard
			# Pests don't participate in stacking
			if card.type == CardEnums.CardType.PEST or type == CardEnums.CardType.PEST:
				continue
			# Can't stack on a card that already has a child
			if card.stack_child != null and card.stack_child != self:
				continue
			# Circular stack prevention
			if _is_in_our_stack_chain(card):
				continue

			var dist: float = global_position.distance_to(card.global_position)
			if dist < min_distance:
				min_distance = dist
				best_target = card

	return best_target

func _is_in_our_stack_chain(card: BaseCard) -> bool:
	var current: BaseCard = self
	while current != null:
		if current == card:
			return true
		current = current.stack_child
	return false

# ============================================================
# Stack / Unstack
# ============================================================
func stack_on(new_parent: BaseCard) -> void:
	if stack_parent == new_parent:
		return

	var old_parent: BaseCard = stack_parent
	if stack_parent != null:
		stack_parent.stack_child = null
		stack_parent.stack_child_changed.emit(self, null)

	stack_parent = new_parent
	if new_parent != null:
		if new_parent.stack_child != null and new_parent.stack_child != self:
			new_parent.stack_child.unstack()
		new_parent.stack_child = self
		new_parent.stack_child_changed.emit(null, self)
		new_parent.on_card_stacked.emit(self, new_parent)
		global_position = new_parent.global_position + Vector2(0, 35)
		_play_stack_animation(new_parent)

	stack_parent_changed.emit(old_parent, new_parent)

func unstack() -> void:
	stack_on(null)

# ============================================================
# Stack chain navigation
# ============================================================
func get_stack_root() -> BaseCard:
	var current: BaseCard = self
	while current.stack_parent != null:
		current = current.stack_parent
	return current

func get_container() -> ContainerCard:
	var root: BaseCard = get_stack_root()
	if root is ContainerCard:
		return root as ContainerCard
	return null

func get_stack_chain() -> Array[BaseCard]:
	var chain: Array[BaseCard] = [self]
	var child: BaseCard = stack_child
	while child != null:
		chain.append(child)
		child = child.stack_child
	return chain

func _unstack_and_remove() -> void:
	var parent: BaseCard = stack_parent
	var child: BaseCard = stack_child

	if parent != null:
		parent.stack_child = null
		parent.stack_child_changed.emit(self, null)
	if child != null:
		child.stack_parent = null
		child.stack_parent_changed.emit(self, null)
	queue_free()

# ============================================================
# Animation hooks
# ============================================================
func _play_stack_animation(target: BaseCard) -> void:
	scale = Vector2(0.8, 0.8)
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.15) \
		.set_trans(Tween.TRANS_ELASTIC) \
		.set_ease(Tween.EASE_OUT)

func play_unstack_animation() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.1)
	tween.tween_property(self, "scale", Vector2.ONE, 0.1)

func play_predation_animation(target_position: Vector2) -> void:
	var original_pos: Vector2 = global_position
	var tween: Tween = create_tween()
	tween.tween_property(self, "global_position", target_position, 0.08) \
		.set_trans(Tween.TRANS_QUAD) \
		.set_ease(Tween.EASE_IN)
	tween.tween_property(self, "global_position", original_pos, 0.12) \
		.set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_OUT)

func play_produce_animation() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.15, 1.15), 0.1)
	tween.tween_property(self, "scale", Vector2.ONE, 0.12)

func play_hit_animation() -> void:
	modulate = Color(1.0, 0.3, 0.3, 1.0)
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.2)

func play_death_animation() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.3)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.3)

# ============================================================
# Death transformation
# ============================================================
func on_health_zero() -> void:
	health_zero.emit(self)
	play_death_animation()
	print("[Card] ", card_name, " Health is zero. Transforming...")

	var replacement_type: CardEnums.CardType = CardEnums.CardType.DRY_GRASS
	var replacement_name: String = "枯草"

	if type == CardEnums.CardType.FISH:
		replacement_type = CardEnums.CardType.DEAD_FISH
		replacement_name = "死鱼"

	# Detach from stack
	var parent: BaseCard = stack_parent
	var child: BaseCard = stack_child

	if parent != null:
		parent.stack_child = null
		parent.stack_child_changed.emit(self, null)
	if child != null:
		child.stack_parent = null
		child.stack_parent_changed.emit(self, null)

	# Spawn replacement card
	if CardSpawner.instance != null:
		var new_card: BaseCard = CardSpawner.instance.spawn_resource_card(
			replacement_type, replacement_name, global_position
		)
		if new_card != null:
			if parent != null:
				new_card.stack_on(parent)
			if child != null:
				child.stack_on(new_card)

	queue_free()
