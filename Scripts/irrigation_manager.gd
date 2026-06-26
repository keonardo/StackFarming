# IrrigationManager.gd — water flow network and fecal drift
extends Node
class_name IrrigationManager

# ============================================================
# Singleton
# ============================================================
static var instance: IrrigationManager = null

# ============================================================
# Exported properties
# ============================================================
@export var connection_distance: float = 160.0     # BFS connection radius (px)
@export var drift_distance: float = 250.0          # Max drift neighbor distance (px)
@export var drift_interval: float = 5.0            # Drift check interval (s)
@export var linkage_check_interval: float = 1.0    # Irrigation BFS interval (s)

# ============================================================
# State
# ============================================================
var _drift_timer: float = 0.0
var _linkage_timer: float = 0.0

# ============================================================
# Lifecycle
# ============================================================
func _enter_tree() -> void:
	instance = self

func _exit_tree() -> void:
	if instance == self:
		instance = null

func _process(delta: float) -> void:
	_linkage_timer += delta
	if _linkage_timer >= linkage_check_interval:
		_linkage_timer = 0.0
		check_irrigation_linkage()

	_drift_timer += delta
	if _drift_timer >= drift_interval:
		_drift_timer = 0.0
		_process_substance_drift()

# ============================================================
# Irrigation BFS — propagate moisture from rivers through canals
# ============================================================
func check_irrigation_linkage() -> void:
	var rivers: Array[BaseCard] = []
	var canals: Array[BaseCard] = []
	var containers: Array[ContainerCard] = []

	_find_cards_in_tree(get_tree().root, rivers, canals, containers)

	# BFS from all river sources
	var queue: Array[BaseCard] = []
	var visited: Dictionary = {}  # BaseCard -> true

	for river in rivers:
		queue.append(river)
		visited[river] = true

	var irrigated: Dictionary = {}  # ContainerCard -> true

	while queue.size() > 0:
		var current: BaseCard = queue.pop_front()

		if current is ContainerCard:
			irrigated[current] = true

		# Spread to nearby canals
		for canal in canals:
			if not visited.has(canal) and current.global_position.distance_to(canal.global_position) <= connection_distance:
				visited[canal] = true
				queue.append(canal)

		# Spread to nearby containers
		for c in containers:
			if not visited.has(c) and current.global_position.distance_to(c.global_position) <= connection_distance:
				visited[c] = true
				queue.append(c)

	# Update irrigation status
	for c in containers:
		var is_linked: bool = irrigated.has(c)

		# Mangzhong drought overrides
		if SolarTermEngine.current_term == CardEnums.SolarTerm.MANGZHONG:
			if c.type != CardEnums.CardType.DEEP_WATER_FISH_POND:
				c.is_irrigated = false
				continue

		c.is_irrigated = is_linked

# ============================================================
# Substance drift — excess feces flows downstream
# ============================================================
func _process_substance_drift() -> void:
	var rivers: Array[BaseCard] = []
	var canals: Array[BaseCard] = []
	var containers: Array[ContainerCard] = []

	_find_cards_in_tree(get_tree().root, rivers, canals, containers)

	for upstream in containers:
		var stack: Array[BaseCard] = upstream.get_stack_chain()
		var feces_cards: Array[BaseCard] = []

		for card in stack:
			if card.type == CardEnums.CardType.FECES and is_instance_valid(card):
				feces_cards.append(card)

		# If more than 1 feces card, drift the top extra one downstream
		if feces_cards.size() > 1:
			var downstream_target: ContainerCard = null
			var max_y_diff: float = 0.0

			for potential in containers:
				if potential == upstream:
					continue
				var dist: float = upstream.global_position.distance_to(potential.global_position)
				if dist <= drift_distance:
					var y_diff: float = potential.global_position.y - upstream.global_position.y
					if y_diff > 25.0 and y_diff > max_y_diff:
						max_y_diff = y_diff
						downstream_target = potential

			if downstream_target != null:
				var extra_feces: BaseCard = feces_cards[feces_cards.size() - 1]
				print("[Irrigation Fecal Drift] Feces card ", extra_feces.card_name,
					" drifted from ", upstream.card_name, " downstream to ", downstream_target.card_name)

				extra_feces.unstack()
				extra_feces.global_position = downstream_target.global_position + \
					Vector2(randf_range(-10, 10), randf_range(-10, 10))
				extra_feces.stack_on(downstream_target)

# ============================================================
# Scene tree search
# ============================================================
func _find_cards_in_tree(node: Node, rivers: Array[BaseCard], canals: Array[BaseCard], containers: Array[ContainerCard]) -> void:
	if node is BaseCard and is_instance_valid(node):
		var card: BaseCard = node as BaseCard
		match card.type:
			CardEnums.CardType.RIVER:
				rivers.append(card)
			CardEnums.CardType.CANAL:
				canals.append(card)
		if card is ContainerCard:
			containers.append(card as ContainerCard)

	for i in range(node.get_child_count()):
		_find_cards_in_tree(node.get_child(i), rivers, canals, containers)
