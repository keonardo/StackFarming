# LaborManager.gd — 劳作区（GameData 可选，内置默认配方）
extends Area2D
class_name LaborManager

@export var game_data: GameData = null

var _stacked_cards: Array[BaseCard] = []
var _current_recipe: Dictionary = {}
var _labor_progress: float = 0.0

var _bg_sprite: Sprite2D = null
var _border_sprite: Sprite2D = null
var _progress_bg: Sprite2D = null
var _progress_fill: Sprite2D = null
var _result_label: Label = null

const SLOT_SIZE := Vector2(90, 110)

# ── 内置默认配方 ──
func _builtin_recipes() -> Array[Dictionary]:
	return [
		{"tool":20,"target":0,"result":30,"rname":"鱼","rcnt":1,"dur":2.0},
		{"tool":20,"target":1,"result":30,"rname":"鱼","rcnt":2,"dur":2.0},
		{"tool":20,"target":2,"result":30,"rname":"鱼","rcnt":2,"dur":1.5},
		{"tool":-1,"target":0,"result":35,"rname":"水","rcnt":1,"dur":1.5},
		{"tool":-1,"target":1,"result":35,"rname":"水","rcnt":2,"dur":1.5},
		{"tool":21,"target":1,"result":3,"rname":"水田","rcnt":1,"dur":4.0,
		 "bp1t":0,"bp1n":"池塘","bp1c":0.3,"bp2t":11,"bp2n":"菰米种","bp2c":0.2,"trans":true},
		{"tool":-1,"target":2,"result":1,"rname":"大水塘","rcnt":1,"dur":3.0},
		{"tool":-1,"target":1,"result":0,"rname":"池塘","rcnt":2,"dur":3.0},
		{"tool":23,"target":36,"result":37,"rname":"肥料","rcnt":1,"dur":3.0},
		{"tool":-1,"target":36,"result":-1,"rname":"销毁","rcnt":0,"dur":1.0},
	]

func _find_recipe(tool_type: int, target_type: int) -> Dictionary:
	if game_data:
		for r in game_data.labor_recipes:
			if r.tool_type == tool_type and r.target_type == target_type:
				return {"tool":r.tool_type,"target":r.target_type,
					"result":r.result_type,"rname":r.result_name,"rcnt":r.result_count,
					"dur":r.duration,
					"bp1t":r.byproduct1_type,"bp1n":r.byproduct1_name,"bp1c":r.byproduct1_chance,
					"bp2t":r.byproduct2_type,"bp2n":r.byproduct2_name,"bp2c":r.byproduct2_chance,
					"trans":r.is_transformation}
	for r in _builtin_recipes():
		if r["tool"] == tool_type and r["target"] == target_type:
			return r
	return {}

func _ready() -> void:
	var has_shape := false
	for child in get_children():
		if child is CollisionShape2D: has_shape = true; break
	if not has_shape:
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = SLOT_SIZE; shape.shape = rect; add_child(shape)
	collision_layer = 1; collision_mask = 1
	monitoring = true; monitorable = true
	_setup_visuals()
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

func _process(delta: float) -> void:
	_enforce_card_positions()
	_clean_stacked_cards()
	if _stacked_cards.size() > 0 and _current_recipe.is_empty():
		_check_recipes()
	if not _current_recipe.is_empty():
		var speed: float = 1.0
		for card in _stacked_cards:
			if is_instance_valid(card) and card.role == CardEnums.CardRole.TOOL:
				speed = card.efficiency; break
		_labor_progress += delta * speed
		_progress_fill.scale.x = minf(1.0, _labor_progress / _current_recipe["dur"])
		if _labor_progress >= _current_recipe["dur"]:
			_complete_labor()

func _setup_visuals() -> void:
	var vp_size := get_viewport().get_visible_rect().size
	position = Vector2(vp_size.x - 95.0, vp_size.y * 0.42)
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8); img.fill(Color.WHITE)

	_border_sprite = Sprite2D.new(); _border_sprite.name = "Border"
	_border_sprite.texture = ImageTexture.create_from_image(img)
	_border_sprite.scale = Vector2(SLOT_SIZE.x + 4, SLOT_SIZE.y + 4) / 4.0
	_border_sprite.modulate = Color(0.4, 0.4, 0.5, 0.6)
	_border_sprite.centered = true; _border_sprite.z_index = -1; add_child(_border_sprite)

	_bg_sprite = Sprite2D.new(); _bg_sprite.name = "BG"
	_bg_sprite.texture = ImageTexture.create_from_image(img)
	_bg_sprite.scale = SLOT_SIZE / 4.0
	_bg_sprite.modulate = Color(0.1, 0.08, 0.2, 0.85)
	_bg_sprite.centered = true; add_child(_bg_sprite)

	var title := Label.new()
	title.position = Vector2(-SLOT_SIZE.x * 0.5, -SLOT_SIZE.y * 0.5 - 24)
	title.size = Vector2(SLOT_SIZE.x, 20)
	title.text = "🔨 劳作"
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	title.add_theme_font_size_override("font_size", 16)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; add_child(title)

	_progress_bg = Sprite2D.new(); _progress_bg.name = "ProgressBG"
	_progress_bg.texture = ImageTexture.create_from_image(img)
	_progress_bg.scale = Vector2(SLOT_SIZE.x - 8, 10.0) / 4.0
	_progress_bg.modulate = Color(0.1, 0.1, 0.1, 0.8)
	_progress_bg.position = Vector2(0, SLOT_SIZE.y * 0.5 + 14)
	_progress_bg.centered = true; add_child(_progress_bg)

	_progress_fill = Sprite2D.new(); _progress_fill.name = "ProgressFill"
	_progress_fill.texture = ImageTexture.create_from_image(img)
	_progress_fill.scale = Vector2(SLOT_SIZE.x - 8, 10.0) / 4.0
	_progress_fill.modulate = Color(0.3, 0.9, 0.3, 0.95)
	_progress_fill.position = _progress_bg.position - Vector2(SLOT_SIZE.x * 0.5 - 4, 0)
	_progress_fill.centered = false; _progress_fill.offset = Vector2(0, -5)
	_progress_fill.scale.x = 0.0; add_child(_progress_fill)

	_result_label = Label.new()
	_result_label.position = Vector2(-SLOT_SIZE.x * 0.5, SLOT_SIZE.y * 0.5 + 28)
	_result_label.size = Vector2(SLOT_SIZE.x, 36)
	_result_label.text = "拖入卡牌"
	_result_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	_result_label.add_theme_font_size_override("font_size", 13)
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; add_child(_result_label)

func _on_area_entered(_area: Area2D) -> void:
	_bg_sprite.modulate = Color(0.2, 0.15, 0.4, 0.95)
	_border_sprite.modulate = Color(0.6, 0.7, 1.0, 0.9)

func _on_area_exited(_area: Area2D) -> void:
	_bg_sprite.modulate = Color(0.1, 0.08, 0.2, 0.85)
	_border_sprite.modulate = Color(0.4, 0.4, 0.5, 0.6)

func try_accept_card(card: BaseCard, _mouse_pos: Vector2) -> bool:
	if _stacked_cards.has(card): _stacked_cards.erase(card); _check_recipes(); return false
	if not _is_card_overlapping(card): return false
	if card.role not in [CardEnums.CardRole.TOOL, CardEnums.CardRole.TERRAIN, CardEnums.CardRole.RESOURCE]:
		return false
	if card.stack_parent: card.unstack()
	card._is_dragging = false
	_stacked_cards.append(card); _check_recipes(); return true

func _is_card_overlapping(card: BaseCard) -> bool:
	for area in card.get_overlapping_areas():
		if area == self: return true
	return false

func _enforce_card_positions() -> void:
	for i in range(_stacked_cards.size()):
		var card := _stacked_cards[i]
		if not is_instance_valid(card) or card._is_dragging: continue
		card.global_position = global_position + Vector2(0, (i - 0.5) * 30.0 - 10.0)
		card.visible = true
		if card.stack_parent != null: card.unstack()

func _clean_stacked_cards() -> void:
	var to_remove: Array[BaseCard] = []
	for card in _stacked_cards:
		if not is_instance_valid(card): to_remove.append(card)
		elif not card._is_dragging:
			if card.global_position.distance_to(global_position) > 160.0: to_remove.append(card)
			elif card.stack_parent != null: to_remove.append(card)
	for card in to_remove: _stacked_cards.erase(card)
	if to_remove.size() > 0: _check_recipes()

func _check_recipes() -> void:
	var tool_type: int = -1; var target_type: int = -1
	for card in _stacked_cards:
		if not is_instance_valid(card): continue
		if card.role == CardEnums.CardRole.TOOL: tool_type = card.type
		elif card.role in [CardEnums.CardRole.TERRAIN, CardEnums.CardRole.RESOURCE]: target_type = card.type

	if tool_type == -1 and target_type == -1: _stop_labor(); return

	var recipe := _find_recipe(tool_type, target_type)
	if recipe.is_empty():
		_stop_labor()
		_result_label.text = "不匹配" if _stacked_cards.size() > 0 else "拖入卡牌"
		_result_label.add_theme_color_override("font_color",
			Color(1.0, 0.4, 0.4) if _stacked_cards.size() > 0 else Color(0.5, 0.5, 0.5))
		return
	_result_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	if recipe == _current_recipe: _labor_progress = 0.0; _progress_fill.scale.x = 0.0
	else: _current_recipe = recipe; _labor_progress = 0.0; _progress_fill.scale.x = 0.0
	_result_label.text = "%s ×%d" % [recipe["rname"], recipe["rcnt"]]

func _stop_labor() -> void:
	_current_recipe.clear(); _labor_progress = 0.0; _progress_fill.scale.x = 0.0

func _complete_labor() -> void:
	var recipe := _current_recipe.duplicate(); _current_recipe.clear()
	_labor_progress = 0.0; _progress_fill.scale.x = 0.0
	var spawn_base := global_position + Vector2(-80, 0)

	if recipe.get("result", -1) >= 0:
		for i in range(recipe["rcnt"]):
			var off := Vector2(randf_range(-30, 30), randf_range(-30, 30))
			if CardSpawner.instance:
				CardSpawner.instance.spawn_card(recipe["result"], recipe["rname"], spawn_base + off)

	for bp in [["bp1t","bp1n","bp1c"], ["bp2t","bp2n","bp2c"]]:
		if recipe.get(bp[0], -1) >= 0 and randf() < recipe.get(bp[2], 0.0):
			var off := Vector2(randf_range(-50, 50), randf_range(-50, 50))
			if CardSpawner.instance:
				CardSpawner.instance.spawn_card(recipe[bp[0]], recipe[bp[1]], spawn_base + off)

	if recipe.get("target", 0) == CardEnums.CardType.FISH_POND and recipe.get("tool", -1) == -1:
		for i in range(2):
			var off := Vector2(randf_range(-30, 30), randf_range(-30, 30))
			if CardSpawner.instance:
				CardSpawner.instance.spawn_card(CardEnums.CardType.FISH, "鱼", spawn_base + off)

	var to_remove: Array[BaseCard] = []
	for card in _stacked_cards:
		if not is_instance_valid(card): to_remove.append(card); continue
		if card.role == CardEnums.CardRole.TOOL:
			var tool: ToolCard = card as ToolCard
			if tool and tool.has_method("consume_durability"):
				if not tool.consume_durability(1.0): to_remove.append(card); card.queue_free()
		elif card.role == CardEnums.CardRole.TERRAIN:
			if recipe.get("tool", -1) == CardEnums.CardType.HOE: to_remove.append(card); card.queue_free()
	for card in to_remove: _stacked_cards.erase(card)

	if _stacked_cards.size() > 0: _check_recipes()
	else:
		_result_label.text = "拖入卡牌"
		_result_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
