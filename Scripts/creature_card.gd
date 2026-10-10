# CreatureCard.gd — 生物卡牌基类（M5 双态：动物 Avatar/Card）
extends BaseCard
class_name CreatureCard

var _behavior: RefCounted = null

# ── M5 Avatar 双态 ──
var is_animal: bool = false          # 是否为自由活物（动物）
var is_avatar: bool = false           # 当前是否处于 Avatar 态（小精灵）
var _avatar_node: Node2D = null       # Avatar 视觉（小圆徽章 + 血条）
var _avatar_bg: Panel = null
var _avatar_name: Label = null
var _avatar_health: ColorRect = null

func _ready() -> void:
	super._ready()
	role = CardEnums.CardRole.CREATURE
	# 动物判定（鸭子等）—— 作物（菰米/菱角）是静态内容物，不走 Avatar
	is_animal = CardEnums.is_animal_type(type)
	match type:
		CardEnums.CardType.DUCK:
			_behavior = DuckBehavior.new(self, get_node("/root/GameConfig"))
		CardEnums.CardType.WILD_RICE_SEED, CardEnums.CardType.WATER_CALTROP:
			_behavior = CropBehavior.new(self, get_node("/root/GameConfig"))

	if is_animal:
		_build_avatar_visual()
		set_avatar_mode(true)

func _process(delta: float) -> void:
	super._process(delta)
	if not is_instance_valid(self): return
	if _behavior: _behavior.process(delta)
	if is_animal:
		_update_avatar_visual()

# ============================================================
# M5 Avatar 视觉构建
# ============================================================
func _build_avatar_visual() -> void:
	_avatar_node = Node2D.new()
	_avatar_node.name = "AvatarVisual"
	add_child(_avatar_node)

	# 圆形徽章底色（水域禽类 → 淡蓝）
	_avatar_bg = Panel.new()
	_avatar_bg.name = "AvatarBG"
	_avatar_bg.size = Vector2(36, 36)
	_avatar_bg.position = Vector2(-18, -30)
	_avatar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.35, 0.6, 0.9, 0.95)
	sb.set_corner_radius_all(18)  # 圆形
	sb.border_color = Color(1, 1, 1, 0.6)
	sb.set_border_width_all(2)
	_avatar_bg.add_theme_stylebox_override("panel", sb)
	_avatar_node.add_child(_avatar_bg)

	# 名称首字
	_avatar_name = Label.new()
	_avatar_name.name = "AvatarName"
	_avatar_name.position = Vector2(-18, -30)
	_avatar_name.size = Vector2(36, 36)
	_avatar_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_avatar_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_avatar_name.add_theme_font_size_override("font_size", 18)
	_avatar_name.add_theme_color_override("font_color", Color.WHITE)
	var first := card_name.substr(0, 1) if not card_name.is_empty() else "?"
	_avatar_name.text = first
	_avatar_node.add_child(_avatar_name)

	# 头顶小血条
	_avatar_health = ColorRect.new()
	_avatar_health.name = "AvatarHealth"
	_avatar_health.size = Vector2(30, 4)
	_avatar_health.position = Vector2(-15, -44)
	_avatar_health.color = Color(0.3, 1.0, 0.3)
	_avatar_node.add_child(_avatar_health)

## 切换双态：true=Avatar（小精灵自由移动）；false=Card（完整面板）
func set_avatar_mode(avatar: bool) -> void:
	if not is_animal:
		return
	is_avatar = avatar
	if _avatar_node:
		_avatar_node.visible = avatar
	if avatar:
		panel_visibility_override = 0   # 强制隐藏完整面板（_update_visuals 尊重）
	else:
		panel_visibility_override = 1   # 强制显示完整面板
	if avatar:
		scale = Vector2.ONE  # Avatar 使用原尺寸的小徽章（collision 缩小由场景处理）

## 每帧刷新 Avatar 血条/位置
func _update_avatar_visual() -> void:
	if not is_avatar or _avatar_health == null:
		return
	var pct := clampf(health / 100.0, 0.0, 1.0)
	_avatar_health.scale.x = pct
	_avatar_health.color = Color(1.0, 0.3, 0.3) if pct < 0.3 else Color(0.3, 1.0, 0.3)

# ============================================================
# 拖拽双态切换（BaseCard 钩子）
# ============================================================
func _on_drag_begin() -> void:
	# 拖起动物 → 显示完整卡牌（Card 态可叠放/喂食/买卖）
	if is_animal:
		set_avatar_mode(false)

func _on_drag_end() -> void:
	# 松手后动物恢复 Avatar 自由游动（即使落回容器也是栖息地自由活动）
	if is_animal:
		set_avatar_mode(true)