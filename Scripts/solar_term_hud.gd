# SolarTermHUD.gd — 节气 HUD（顶部居中面板 + 倒计时 + 警告闪烁）
extends Node2D

# ============================================================
# 配置
# ============================================================
@export_group("布局")
@export var panel_width: float = 220.0
@export var panel_height: float = 48.0
@export var font_size_name: int = 20
@export var font_size_timer: int = 14

# ============================================================
# 内部节点
# ============================================================
var _bg_rect: ColorRect = null
var _name_label: Label = null
var _timer_label: Label = null

# 闪烁/警告状态
var _flash_time: float = 0.0
var _warning_active: bool = false

# 节气专属颜色
const TERM_COLORS := {
	CardEnums.SolarTerm.NONE:        Color(0.13, 0.15, 0.18, 0.75),  # 平日 — 暗灰
	CardEnums.SolarTerm.JINGZHE:     Color(0.08, 0.45, 0.08, 0.80),  # 惊蛰 — 深绿
	CardEnums.SolarTerm.MANGZHONG:   Color(0.65, 0.35, 0.05, 0.85),  # 芒种 — 土金
	CardEnums.SolarTerm.SHUANGJIANG: Color(0.15, 0.35, 0.60, 0.85),  # 霜降 — 冰蓝
}

const WARNING_COLOR := Color(0.7, 0.15, 0.05, 0.90)  # 警告 — 橙红

# ============================================================
# Lifecycle
# ============================================================
func _ready() -> void:
	z_index = 100  # 确保在所有其他节点之上
	_create_panel()
	_refresh_display()

	# 连接 SolarTermEngine 信号
	var ste := _get_engine()
	if ste:
		ste.term_changed.connect(_on_term_changed)
		ste.term_warning.connect(_on_term_warning)
	else:
		push_warning("[SolarTermHUD] 找不到 SolarTermEngine autoload")

func _process(delta: float) -> void:
	var ste := _get_engine()
	if not ste:
		return

	# 警告闪烁动画
	if _warning_active:
		_flash_time += delta
		var t := sin(_flash_time * 8.0) * 0.5 + 0.5  # ~4 Hz 正弦闪烁
		_bg_rect.color = lerp(TERM_COLORS[CardEnums.SolarTerm.NONE], WARNING_COLOR, t)

	# 实时倒计时
	_update_timer_label(ste)

# ============================================================
# UI 构建
# ============================================================
func _create_panel() -> void:
	# 背景矩形
	_bg_rect = ColorRect.new()
	_bg_rect.name = "TermBg"
	_bg_rect.size = Vector2(panel_width, panel_height)
	_bg_rect.position = Vector2(-panel_width * 0.5, 0)
	_bg_rect.color = TERM_COLORS[CardEnums.SolarTerm.NONE]
	add_child(_bg_rect)

	# 节气名称
	_name_label = Label.new()
	_name_label.name = "TermName"
	_name_label.position = Vector2(-panel_width * 0.5 + 10, 6)
	_name_label.size = Vector2(panel_width - 20, 22)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", font_size_name)
	_name_label.add_theme_color_override("font_color", Color.WHITE)
	_name_label.text = "平日"
	add_child(_name_label)

	# 倒计时
	_timer_label = Label.new()
	_timer_label.name = "TermTimer"
	_timer_label.position = Vector2(-panel_width * 0.5 + 10, 27)
	_timer_label.size = Vector2(panel_width - 20, 16)
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_timer_label.add_theme_font_size_override("font_size", font_size_timer)
	_timer_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	_timer_label.text = ""
	add_child(_timer_label)

# ============================================================
# 显示刷新
# ============================================================
func _refresh_display() -> void:
	var ste := _get_engine()
	if not ste:
		return

	var term := ste.current_term
	var term_name := ste.get_current_term_name()

	# 更新背景颜色
	_bg_rect.color = TERM_COLORS.get(term, TERM_COLORS[CardEnums.SolarTerm.NONE])

	# 更新名称
	if term == CardEnums.SolarTerm.NONE:
		_name_label.text = "☀ 平日"
	else:
		_name_label.text = _term_icon(term) + " " + term_name
	_name_label.add_theme_color_override("font_color", _name_color(term))

	# 更新倒计时
	_update_timer_label(ste)

func _update_timer_label(ste: SolarTermEngine) -> void:
	var remaining := ste.get_term_remaining()
	var mins := int(remaining) / 60
	var secs := int(remaining) % 60
	_timer_label.text = "⏳ %02d:%02d".format([mins, secs], "%02d")

func _stop_warning() -> void:
	_warning_active = false
	_flash_time = 0.0
	# 恢复当前节气颜色
	var ste := _get_engine()
	if ste:
		_bg_rect.color = TERM_COLORS.get(ste.current_term, TERM_COLORS[CardEnums.SolarTerm.NONE])

# ============================================================
# 信号回调
# ============================================================
func _on_term_changed(old_term: CardEnums.SolarTerm, new_term: CardEnums.SolarTerm) -> void:
	_stop_warning()
	_refresh_display()

	# 节气切入音效/动画钩子
	if new_term != CardEnums.SolarTerm.NONE:
		_play_term_enter_animation()

func _on_term_warning(next_term: CardEnums.SolarTerm, _seconds_remaining: float) -> void:
	if next_term == CardEnums.SolarTerm.NONE:
		return

	_warning_active = true
	_flash_time = 0.0
	_timer_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.2))  # 橙色倒计时文字

# ============================================================
# 视觉效果
# ============================================================
func _play_term_enter_animation() -> void:
	# 简单的缩放弹入效果（使用 Tween 或手动）
	_bg_rect.scale = Vector2(1.08, 1.08)
	var tw := create_tween()
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(_bg_rect, "scale", Vector2.ONE, 0.4)

	_name_label.modulate = Color.YELLOW
	var tw2 := create_tween()
	tw2.tween_property(_name_label, "modulate", Color.WHITE, 0.6)

# ============================================================
# 辅助
# ============================================================
func _get_engine() -> SolarTermEngine:
	return SolarTermEngine.instance

func _term_icon(term: CardEnums.SolarTerm) -> String:
	match term:
		CardEnums.SolarTerm.JINGZHE:     return "🐛"
		CardEnums.SolarTerm.MANGZHONG:   return "🌾"
		CardEnums.SolarTerm.SHUANGJIANG: return "❄️"
		_:                               return "☀"

func _name_color(term: CardEnums.SolarTerm) -> Color:
	match term:
		CardEnums.SolarTerm.JINGZHE:     return Color(0.4, 1.0, 0.5)   # 嫩绿
		CardEnums.SolarTerm.MANGZHONG:   return Color(1.0, 0.8, 0.2)   # 金黄
		CardEnums.SolarTerm.SHUANGJIANG: return Color(0.5, 0.7, 1.0)   # 冰蓝
		_:                               return Color(0.7, 0.7, 0.7)  # 灰白
