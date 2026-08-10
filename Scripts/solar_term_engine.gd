# SolarTermEngine.gd — 二十四节气引擎 (v1)
# Autoload — 周期性轮转节气卡（惊蛰/芒种/霜降），驱动全局事件
extends Node
class_name SolarTermEngine

# ============================================================
# Signals — UI 层监听用于提示/动画
# ============================================================
## 节气切换时发射
signal term_changed(old_term: CardEnums.SolarTerm, new_term: CardEnums.SolarTerm)
## 节气来临前 N 秒警告（用于 UI 倒计时提示）
signal term_warning(next_term: CardEnums.SolarTerm, seconds_remaining: float)

# ============================================================
# Singleton 访问器（RefCounted behavior 可通过 .instance 访问）
# ============================================================
static var instance: SolarTermEngine = null

# ============================================================
# 导出配置 — 全部在 Inspector 中可调
# ============================================================
@export_group("⏱️ 节气周期")
@export var gap_duration: float = 90.0        ## 节气间隔时长（秒）— 正常季节
@export var warning_time: float = 10.0         ## 节气来临前多少秒发警告

@export_group("🐛 惊蛰 (Jingzhe)")
@export var jingzhe_duration: float = 30.0
@export var jingzhe_bugs_per_field_min: int = 1
@export var jingzhe_bugs_per_field_max: int = 3
@export var jingzhe_bug_spawn_mult: float = 2.0   ## 虫害自然生成概率倍率

@export_group("🌾 芒种 (Mangzhong)")
@export var mangzhong_duration: float = 45.0
@export var mangzhong_moisture_drain_pct: float = 0.5  ## 初始瞬间削减比例
@export var mangzhong_decay_mult: float = 2.0           ## 湿润衰减速度倍率

@export_group("❄️ 霜降 (Shuangjiang)")
@export var shuangjiang_duration: float = 30.0
@export var shuangjiang_growth_mult: float = 0.5        ## 作物生长速度倍率

# ============================================================
# 内部状态
# ============================================================
var current_term: CardEnums.SolarTerm = CardEnums.SolarTerm.NONE
var term_timer: float = 0.0
var _term_sequence: Array[CardEnums.SolarTerm] = []   ## [JINGZHE, NONE, MANGZHONG, NONE, SHUANGJIANG, NONE]
var _seq_index: int = 0
var _warned: bool = false

func _enter_tree() -> void:
	instance = self

func _exit_tree() -> void:
	if instance == self:
		instance = null

func _ready() -> void:
	_build_sequence()
	term_timer = gap_duration  # 开局处于 "平日"，第一个节气在 gap_duration 秒后到来
	print("[SolarTermEngine] 节气引擎就绪，首个节气 ", _term_name(_term_sequence[0]), " 将在 ", gap_duration, "s 后到来")

func _build_sequence() -> void:
	_term_sequence = [
		CardEnums.SolarTerm.JINGZHE,
		CardEnums.SolarTerm.NONE,
		CardEnums.SolarTerm.MANGZHONG,
		CardEnums.SolarTerm.NONE,
		CardEnums.SolarTerm.SHUANGJIANG,
		CardEnums.SolarTerm.NONE,
	]

# ============================================================
# 主循环
# ============================================================
func _process(delta: float) -> void:
	term_timer -= delta

	# 平日 → 节气切换前 N 秒发出警告
	if current_term == CardEnums.SolarTerm.NONE and term_timer <= warning_time and not _warned:
		var next_term := _peek_next_term()
		if next_term != CardEnums.SolarTerm.NONE:
			_warned = true
			term_warning.emit(next_term, term_timer)
			print("[SolarTermEngine] ⚠️ ", _term_name(next_term), " 即将来临 (", snapped(term_timer, 0.1), "s)")

	if term_timer <= 0.0:
		_advance_term()

# ============================================================
# 节气切换
# ============================================================
func _peek_next_term() -> CardEnums.SolarTerm:
	return _term_sequence[_seq_index]

func _advance_term() -> void:
	var old_term := current_term
	var new_term := _term_sequence[_seq_index]
	_seq_index = (_seq_index + 1) % _term_sequence.size()

	_on_term_exit(old_term)
	current_term = new_term
	_on_term_enter(new_term)
	term_timer = _get_term_duration(new_term)
	_warned = false

	term_changed.emit(old_term, new_term)
	print("[SolarTermEngine] ", _term_name(old_term), " → ", _term_name(new_term),
		" (持续 ", _get_term_duration(new_term), "s)")

func _get_term_duration(term: CardEnums.SolarTerm) -> float:
	match term:
		CardEnums.SolarTerm.JINGZHE:    return jingzhe_duration
		CardEnums.SolarTerm.MANGZHONG:  return mangzhong_duration
		CardEnums.SolarTerm.SHUANGJIANG:return shuangjiang_duration
		_:                              return gap_duration

func _on_term_enter(term: CardEnums.SolarTerm) -> void:
	match term:
		CardEnums.SolarTerm.JINGZHE:    _trigger_jingzhe()
		CardEnums.SolarTerm.MANGZHONG:  _trigger_mangzhong()
		CardEnums.SolarTerm.SHUANGJIANG:_trigger_shuangjiang()

func _on_term_exit(_term: CardEnums.SolarTerm) -> void:
	pass  # 预留：清理持续效果标记

# ============================================================
# 🐛 惊蛰：在所有有作物的地块上刷虫
# ============================================================
func _trigger_jingzhe() -> void:
	var terrains := _get_all_terrains()
	var total_bugs := 0

	for terrain in terrains:
		if not is_instance_valid(terrain):
			continue
		if not _terrain_has_crop(terrain):
			continue

		var bug_count := randi_range(jingzhe_bugs_per_field_min, jingzhe_bugs_per_field_max)
		for _i in range(bug_count):
			var bpos := terrain.global_position + Vector2(randf_range(-35, 35), randf_range(-35, 35))
			if CardSpawner.instance:
				var bug := CardSpawner.instance.spawn_card(CardEnums.CardType.BUG, "虫", bpos)
				if bug:
					bug.call_deferred("stack_on", terrain)
					total_bugs += 1

	print("[SolarTermEngine] 🐛 惊蛰！", total_bugs, " 只虫苏醒，袭击农田")

# ============================================================
# 🌾 芒种：瞬间削减所有水田滋润度
# ============================================================
func _trigger_mangzhong() -> void:
	var terrains := _get_all_terrains()
	var affected := 0

	for terrain in terrains:
		if not is_instance_valid(terrain):
			continue
		if terrain.type == CardEnums.CardType.PADDY_FIELD:
			terrain.moisture = max(0.0, terrain.moisture * (1.0 - mangzhong_moisture_drain_pct))
			affected += 1

	print("[SolarTermEngine] 🌾 芒种！", affected, " 块水田滋润度骤降，烈日灼田")

# ============================================================
# ❄️ 霜降：杀灭所有虫子
# ============================================================
func _trigger_shuangjiang() -> void:
	var terrains := _get_all_terrains()
	var bugs_killed := 0

	for terrain in terrains:
		if not is_instance_valid(terrain):
			continue
		for card in terrain.get_stack_chain():
			if card.type == CardEnums.CardType.BUG and is_instance_valid(card):
				card.queue_free()
				bugs_killed += 1

	print("[SolarTermEngine] ❄️ 霜降！", bugs_killed, " 只虫冻毙，万物凝霜")

# ============================================================
# 内部辅助
# ============================================================
func _get_all_terrains() -> Array[TerrainCard]:
	var im := get_node_or_null("/root/IrrigationManager") as IrrigationManager
	if im:
		return im.get_all_terrains()
	return []

func _terrain_has_crop(terrain: TerrainCard) -> bool:
	for c in terrain.get_stack_chain():
		if c.type in [CardEnums.CardType.WILD_RICE_SEED, CardEnums.CardType.WATER_CALTROP]:
			return true
	return false

func _term_name(term: CardEnums.SolarTerm) -> String:
	match term:
		CardEnums.SolarTerm.JINGZHE:    return "惊蛰"
		CardEnums.SolarTerm.MANGZHONG:  return "芒种"
		CardEnums.SolarTerm.SHUANGJIANG:return "霜降"
		_:                              return "平日"

# ============================================================
# 公开 API — 供 Behavior 查询以调整每帧行为
# ============================================================

## 当前作物生长倍率（霜降期间 = 0.5，其他 = 1.0）
func get_growth_multiplier() -> float:
	if current_term == CardEnums.SolarTerm.SHUANGJIANG:
		return shuangjiang_growth_mult
	return 1.0

## 当前虫害自然生成概率倍率（惊蛰期间 = 2.0，其他 = 1.0）
func get_bug_spawn_multiplier() -> float:
	if current_term == CardEnums.SolarTerm.JINGZHE:
		return jingzhe_bug_spawn_mult
	return 1.0

## 当前水田湿润衰减倍率（芒种期间 = 2.0，其他 = 1.0）
func get_moisture_decay_multiplier() -> float:
	if current_term == CardEnums.SolarTerm.MANGZHONG:
		return mangzhong_decay_mult
	return 1.0

## 获取当前节气可读名称
func get_current_term_name() -> String:
	return _term_name(current_term)

## 获取当前节气剩余时间（秒）
func get_term_remaining() -> float:
	return max(0.0, term_timer)

## 当前是否为节气（非平日）
func is_in_term() -> bool:
	return current_term != CardEnums.SolarTerm.NONE

## 返回即将到来的下一个节气（平日期间查询），若当前已是节气则返回 NONE
func get_upcoming_term() -> CardEnums.SolarTerm:
	if current_term != CardEnums.SolarTerm.NONE:
		return CardEnums.SolarTerm.NONE
	return _peek_next_term()
