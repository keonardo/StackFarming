# MarketManager.gd — 集市系统（GameData 可选，内置默认价格）
extends Node2D
class_name MarketManager

@export var game_data: GameData = null

var money: int = 0:
	set(v):
		money = v
		if _money_label: _money_label.text = "💰 %d" % money

var _money_label: Label = null
var _sell_zone: Area2D = null
var _sell_label: Label = null
var _notification_label: Label = null
var _notification_timer: float = 0.0
var _buy_panel: Panel = null
var _buy_panel_visible: bool = false

# ── 内置默认价格 ──
const _BUILTIN_PRICES := {
	30: {"name":"鱼","sell":3,"buy":-1},
	31: {"name":"鸭蛋","sell":3,"buy":-1},
	32: {"name":"鸭毛","sell":1,"buy":-1},
	33: {"name":"菰米","sell":4,"buy":-1},
	34: {"name":"菱角","sell":4,"buy":-1},
	37: {"name":"肥料","sell":5,"buy":-1},
	20: {"name":"鱼竿","sell":-1,"buy":5},
	21: {"name":"锄头","sell":-1,"buy":8},
	22: {"name":"引水车","sell":-1,"buy":12},
	23: {"name":"堆肥箱","sell":-1,"buy":10},
}

func _ready() -> void:
	_setup_market()

func _process(delta: float) -> void:
	if _notification_timer > 0.0:
		_notification_timer -= delta
		if _notification_timer <= 0.0:
			_notification_label.visible = false

func _setup_market() -> void:
	var vp_size := get_viewport().get_visible_rect().size

	_money_label = Label.new()
	_money_label.position = Vector2(10, 8)
	_money_label.text = "💰 0"
	_money_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	_money_label.add_theme_font_size_override("font_size", 22)
	add_child(_money_label)

	var sell_pos := Vector2(vp_size.x * 0.5, 36.0)
	var sell_size := Vector2(160, 48)

	_sell_zone = _make_zone("SellZone", sell_pos, sell_size, Color(0.1, 0.3, 0.1, 0.85))
	add_child(_sell_zone)

	_sell_label = Label.new()
	_sell_label.position = sell_pos - Vector2(70, 18)
	_sell_label.size = Vector2(140, 36)
	_sell_label.text = "📥 出售 (拖至此)"
	_sell_label.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7))
	_sell_label.add_theme_font_size_override("font_size", 14)
	_sell_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sell_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_sell_label)

	var buy_pos := Vector2(sell_pos.x + sell_size.x * 0.5 + 80, 36.0)
	var buy_size := Vector2(100, 48)
	var buy_zone := _make_zone("BuyZone", buy_pos, buy_size, Color(0.2, 0.15, 0.35, 0.85))
	buy_zone.input_event.connect(_on_buy_zone_clicked)
	buy_zone.input_pickable = true
	add_child(buy_zone)

	var buy_label := Label.new()
	buy_label.position = buy_pos - Vector2(50, 18)
	buy_label.size = Vector2(100, 36)
	buy_label.text = "🛒 购买"
	buy_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.5))
	buy_label.add_theme_font_size_override("font_size", 14)
	buy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	buy_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(buy_label)

	_buy_panel = Panel.new()
	_buy_panel.name = "BuyPanel"
	_buy_panel.position = Vector2(vp_size.x - 220, 60)
	_buy_panel.size = Vector2(200, 180)
	_buy_panel.visible = false
	_buy_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.08, 0.18, 0.95)
	panel_style.set_corner_radius_all(6)
	panel_style.content_margin_left = 8
	panel_style.content_margin_right = 8
	panel_style.content_margin_top = 6
	panel_style.content_margin_bottom = 6
	_buy_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_buy_panel)
	_build_buy_list()

	_notification_label = Label.new()
	_notification_label.position = Vector2(vp_size.x * 0.3, 80)
	_notification_label.size = Vector2(vp_size.x * 0.4, 36)
	_notification_label.add_theme_font_size_override("font_size", 18)
	_notification_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.0))
	_notification_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notification_label.visible = false
	add_child(_notification_label)

func _make_zone(zone_name: String, pos: Vector2, size: Vector2, color: Color) -> Area2D:
	var zone := Area2D.new()
	zone.name = zone_name; zone.position = pos
	zone.collision_layer = 1; zone.collision_mask = 1
	zone.monitoring = true; zone.monitorable = true
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size; shape.shape = rect; zone.add_child(shape)
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8); img.fill(Color.WHITE)
	var bg := Sprite2D.new(); bg.name = "BG"
	bg.texture = ImageTexture.create_from_image(img)
	bg.scale = size / 4.0; bg.modulate = color; bg.centered = true
	zone.add_child(bg)
	zone.set_meta("base_color", color)
	zone.set_meta("hover_color", Color(color.r * 1.5, color.g * 1.5, color.b * 1.5, 0.95))
	zone.area_entered.connect(func(a): _on_zone_hover(zone, true) if a is BaseCard else null)
	zone.area_exited.connect(func(a): _on_zone_hover(zone, false) if a is BaseCard else null)
	return zone

func _on_zone_hover(zone: Area2D, hover: bool) -> void:
	var bg: Sprite2D = zone.get_node_or_null("BG") as Sprite2D
	if bg: bg.modulate = zone.get_meta("hover_color" if hover else "base_color", Color.GRAY)

func _build_buy_list() -> void:
	for child in _buy_panel.get_children(): child.queue_free()
	var title := Label.new()
	title.text = "🛒 可购买工具"
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	title.add_theme_font_size_override("font_size", 15)
	title.size = Vector2(184, 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_buy_panel.add_child(title)

	var buyable := _get_buyable()
	var y := 28
	for entry in buyable:
		var nl := Label.new()
		nl.position = Vector2(4, y); nl.size = Vector2(70, 26)
		nl.text = "🔧 %s" % entry["name"]
		nl.add_theme_font_size_override("font_size", 13)
		_buy_panel.add_child(nl)

		var pl := Label.new()
		pl.position = Vector2(76, y); pl.size = Vector2(50, 26)
		pl.text = "%d💰" % entry["price"]
		pl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		pl.add_theme_font_size_override("font_size", 13)
		_buy_panel.add_child(pl)

		var btn := Button.new()
		btn.position = Vector2(130, y); btn.size = Vector2(56, 26)
		btn.text = "购买"
		btn.pressed.connect(_on_buy_tool.bind(entry))
		_buy_panel.add_child(btn)
		y += 30
	_buy_panel.size.y = y + 10

func _get_buyable() -> Array:
	var result: Array = []
	if game_data:
		for e in game_data.market_entries:
			if e.buy_price > 0: result.append({"type": e.card_type, "name": e.card_name, "price": e.buy_price})
		return result
	for ct in _BUILTIN_PRICES:
		var p = _BUILTIN_PRICES[ct]
		if p["buy"] > 0: result.append({"type": ct, "name": p["name"], "price": p["buy"]})
	return result

func _get_sell_price(ct: int) -> Dictionary:
	if game_data:
		var entry := game_data.get_market_entry(ct)
		if entry: return {"ok": entry.sell_price >= 0, "price": entry.sell_price}
	if _BUILTIN_PRICES.has(ct):
		var p = _BUILTIN_PRICES[ct]
		return {"ok": p["sell"] >= 0, "price": p["sell"]}
	return {"ok": false, "price": -1}

func _on_buy_zone_clicked(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_buy_panel_visible = not _buy_panel_visible
		_buy_panel.visible = _buy_panel_visible
		_build_buy_list()

func try_sell_card(card: BaseCard, _mouse_pos: Vector2) -> bool:
	if not _sell_zone or not is_instance_valid(_sell_zone): return false
	var hit := false
	for area in card.get_overlapping_areas():
		if area == _sell_zone: hit = true; break
	if not hit: return false
	if card.role == CardEnums.CardRole.TERRAIN:
		_show_notification("❌ 地貌不能出售"); return false

	var info := _get_sell_price(card.type)
	if not info["ok"]:
		_show_notification("❌ 此卡不能出售"); return false

	money += info["price"]
	_show_notification("✅ %s +%d💰" % [card.card_name, info["price"]])
	card.play_produce_animation()
	card.queue_free()
	return true

func _on_buy_tool(entry: Dictionary) -> void:
	if money < entry["price"]:
		_show_notification("❌ 钱不够！需要 %d💰" % entry["price"]); return
	money -= entry["price"]
	var spawn_pos := Vector2(
		get_viewport().get_visible_rect().size.x * 0.5 + randf_range(-60, 60),
		get_viewport().get_visible_rect().size.y * 0.5 + randf_range(-60, 60))
	if CardSpawner.instance:
		CardSpawner.instance.spawn_card(entry["type"], entry["name"], spawn_pos)
	_show_notification("🛒 购买 %s -%d💰" % [entry["name"], entry["price"]])
	_buy_panel_visible = false; _buy_panel.visible = false

func _show_notification(msg: String) -> void:
	_notification_label.text = msg
	_notification_label.visible = true
	_notification_timer = 2.0

func add_money(amount: int) -> void:
	money += amount
	_show_notification("+%d💰" % amount)
