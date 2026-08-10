# CardSpawner.gd — singleton card factory（YARD Registry 优先）
extends Node
class_name CardSpawner

static var instance: CardSpawner = null

## YARD Registry — 唯一数据源，每张卡牌一个 .tres
@export var card_registry: Resource = null  # 在场景中指向 res://cards_registry.tres

## 当 registry 不可用时回退到内置值
## 格式: value_a, value_b
const _FALLBACK := {
	# Creatures
	10: [100.0, 0.0],   # DUCK
	11: [100.0, 0.0],   # WILD_RICE_SEED
	12: [80.0, 0.0],    # WATER_CALTROP
	13: [30.0, 0.0],    # BUG
	# Resources
	30: [5.0, 120.0],   # FISH
	31: [8.0, 90.0],    # DUCK_EGG
	32: [2.0, 120.0],   # DUCK_FEATHER
	33: [6.0, 180.0],   # WILD_RICE
	34: [7.0, 150.0],   # CALTROP
	35: [30.0, 60.0],   # WATER
	36: [10.0, 90.0],   # FECES
	37: [15.0, 180.0],  # FERTILIZER
	# Terrains
	0: [4.0, 100.0],    # POND
	1: [6.0, 100.0],    # BIG_POND
	2: [10.0, 100.0],   # FISH_POND
	3: [4.0, 80.0],     # PADDY_FIELD
	# Tools
	20: [10.0, 1.0],    # FISHING_ROD
	21: [15.0, 1.0],    # HOE
	22: [20.0, 30.0],   # WATERWHEEL
	23: [15.0, 1.0],    # COMPOST_BIN
	24: [999.0, 0.5],   # LABORER
}

# ── card_type → string_id 映射（用于 Registry.load_entry）──
# 文件名不含扩展名即为 YARD Registry 中的 string_id
const _TYPE_TO_ID := {
	# Terrain
	0: "pond", 1: "big_pond", 2: "fish_pond", 3: "paddy_field",
	# Creatures
	10: "duck", 11: "wild_rice_seed", 12: "water_caltrop", 13: "bug",
	# Tools
	20: "fishing_rod", 21: "hoe", 22: "waterwheel", 23: "compost_bin", 24: "laborer",
	# Resources
	30: "fish", 31: "duck_egg", 32: "duck_feather", 33: "wild_rice",
	34: "caltrop", 35: "water", 36: "feces", 37: "fertilizer",
}

var creature_scene: PackedScene
var resource_scene: PackedScene
var terrain_scene: PackedScene
var tool_scene: PackedScene

func _enter_tree() -> void:
	instance = self
	creature_scene = load("res://Scenes/creature_card.tscn")
	resource_scene = load("res://Scenes/resource_card.tscn")
	terrain_scene  = load("res://Scenes/container_card.tscn")
	tool_scene     = load("res://Scenes/tool_card.tscn")

func _exit_tree() -> void:
	if instance == self: instance = null

# ── 解析数值：Registry → GameData → Fallback ──
# priority: 1) card_registry  2) fallback
func _get_vals(ct: int) -> Array:
	if card_registry and card_registry.has_string_id(_TYPE_TO_ID.get(ct, "")):
		var def: CardDef = card_registry.load_entry(_TYPE_TO_ID[ct])
		if def:
			return [def.value_a, def.value_b]
	if _FALLBACK.has(ct):
		return _FALLBACK[ct]
	return [100.0, 0.0]

# ── 从 Registry 读取卡牌名称（优先），否则 fallback 到 CardEnums ──
func _get_name(ct: int, nm: String) -> String:
	if nm and not nm.is_empty():
		return nm
	if card_registry and card_registry.has_string_id(_TYPE_TO_ID.get(ct, "")):
		var def: CardDef = card_registry.load_entry(_TYPE_TO_ID[ct])
		if def and not def.card_name.is_empty():
			return def.card_name
	return CardEnums.default_name(ct)

func spawn_card(ct: int, nm: String = "", pos: Vector2 = Vector2.ZERO) -> BaseCard:
	match CardEnums.role_from_type(ct):
		CardEnums.CardRole.CREATURE: return sp_c(ct, nm, pos)
		CardEnums.CardRole.RESOURCE:  return sp_r(ct, nm, pos)
		CardEnums.CardRole.TERRAIN:   return sp_t(ct, nm, pos)
		CardEnums.CardRole.TOOL:      return sp_k(ct, nm, pos)
	return null

func sp_c(ct: int, nm: String, pos: Vector2) -> BaseCard:
	var c: BaseCard = _make(creature_scene, BaseCard.new())
	var v := _get_vals(ct)
	c.role = 0; c.type = ct; c.card_name = _get_name(ct, nm)
	c.value_a = v[0]; c.value_b = v[1]
	c.global_position = pos; get_tree().root.call_deferred("add_child", c); return c

func sp_r(ct: int, nm: String, pos: Vector2) -> BaseCard:
	var c: BaseCard = _make(resource_scene, BaseCard.new())
	var v := _get_vals(ct)
	c.role = 1; c.type = ct; c.card_name = _get_name(ct, nm)
	c.intensity = v[0]; c.duration = v[1]
	c.global_position = pos; get_tree().root.call_deferred("add_child", c); return c

func sp_t(ct: int, nm: String, pos: Vector2) -> BaseCard:
	var c: TerrainCard = _make_terrain(terrain_scene)
	var v := _get_vals(ct)
	c.role = 2; c.type = ct; c.card_name = _get_name(ct, nm)
	c.capacity = v[0]; c.moisture = v[1]
	c.global_position = pos; get_tree().root.call_deferred("add_child", c); return c

func sp_k(ct: int, nm: String, pos: Vector2) -> BaseCard:
	var c: ToolCard = _make_tool(tool_scene)
	var v := _get_vals(ct)
	c.role = 3; c.type = ct; c.card_name = _get_name(ct, nm)
	c.durability = v[0]; c.efficiency = v[1]
	c.global_position = pos; get_tree().root.call_deferred("add_child", c); return c

func _make(scene: PackedScene, fallback: BaseCard) -> BaseCard:
	if scene: return scene.instantiate()
	var c = fallback; _add_col(c); return c

func _make_terrain(scene: PackedScene) -> TerrainCard:
	if scene: return scene.instantiate()
	var c = TerrainCard.new(); _add_col(c); return c

func _make_tool(scene: PackedScene) -> ToolCard:
	if scene:
		var inst = scene.instantiate()
		if inst is ToolCard: return inst
	var c = ToolCard.new(); _add_col(c); return c

func _add_col(card: Area2D) -> void:
	var s = CollisionShape2D.new(); var r = RectangleShape2D.new()
	r.size = Vector2(80, 100); s.shape = r; card.add_child(s)
