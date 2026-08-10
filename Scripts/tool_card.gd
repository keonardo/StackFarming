# ToolCard.gd — tool card base (fishing rod, hoe, waterwheel, etc.)
extends BaseCard
class_name ToolCard

# ============================================================
# Exported properties
# ============================================================
@export var tool_durability: float = 10.0:
	get: return value_a
	set(v): value_a = max(0.0, v)

@export var tool_efficiency: float = 1.0:
	get: return value_b
	set(v): value_b = v

# ============================================================
# Exported properties — Waterwheel
# ============================================================
@export var waterwheel_interval: float = 5.0    # Seconds between irrigations
@export var waterwheel_range: float = 250.0      # Pond detection radius (px)
@export var waterwheel_moisture: float = 30.0    # Moisture added per tick

# ============================================================
# State
# ============================================================
var _waterwheel_timer: float = 0.0

# ============================================================
# Lifecycle
# ============================================================
func _ready() -> void:
	super._ready()
	role = CardEnums.CardRole.TOOL
	if durability <= 0.0:
		durability = tool_durability
	if efficiency <= 0.0:
		efficiency = tool_efficiency

func _process(delta: float) -> void:
	super._process(delta)

	if not is_instance_valid(self):
		return

	if type == CardEnums.CardType.WATERWHEEL:
		_process_waterwheel(delta)

# ============================================================
# Waterwheel: passive irrigation on paddy fields
# ============================================================
func _process_waterwheel(delta: float) -> void:
	# Find paddy field we're overlapping
	var paddy := _find_overlapping_paddy()
	if not paddy:
		return

	# Check for water source nearby (pond/big pond, NOT fish pond)
	if not _has_water_source_nearby():
		return

	# Irrigation tick
	_waterwheel_timer += delta * efficiency
	if _waterwheel_timer >= waterwheel_interval:
		_waterwheel_timer = 0.0
		_irrigate_paddy(paddy)

func _find_overlapping_paddy() -> TerrainCard:
	for area in get_overlapping_areas():
		if area is TerrainCard and is_instance_valid(area) and area.type == CardEnums.CardType.PADDY_FIELD:
			return area as TerrainCard
	return null

func _has_water_source_nearby() -> bool:
	# 使用 IrrigationManager 的水网查询，而非手动遍历场景树
	var im := get_node_or_null("/root/IrrigationManager") as IrrigationManager
	if im:
		return im.has_water_source_near(global_position, waterwheel_range)
	# 降级：手动遍历
	var terrain_cards: Array[Node] = []
	_collect_terrain_cards(get_tree().root, terrain_cards)
	for node in terrain_cards:
		if node is TerrainCard and is_instance_valid(node):
			if node.type in [CardEnums.CardType.POND, CardEnums.CardType.BIG_POND]:
				if global_position.distance_to(node.global_position) <= waterwheel_range:
					return true
	return false

func _collect_terrain_cards(node: Node, result: Array[Node]) -> void:
	if node is TerrainCard:
		result.append(node)
	for child in node.get_children():
		_collect_terrain_cards(child, result)

func _irrigate_paddy(paddy: TerrainCard) -> void:
	# Add moisture to paddy
	paddy.moisture = min(100.0, paddy.moisture + waterwheel_moisture)
	print("[Waterwheel] Irrigating ", paddy.card_name, " → Moisture: ", paddy.moisture)

	# Consume durability (on_tool_broken handles queue_free via base_card setter)
	var still_ok: bool = consume_durability(1.0)
	if not still_ok and is_instance_valid(self) and not _is_dying:
		print("[Waterwheel] Durability zero — waterwheel destroyed!")
		queue_free()

# ============================================================
# Generic: consume durability
# ============================================================
func consume_durability(amount: float = 1.0) -> bool:
	durability -= amount
	if durability <= 0.0:
		durability = 0.0
		return false  # Tool is now broken
	return true       # Tool still has durability left
