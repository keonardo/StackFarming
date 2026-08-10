# GameData.gd — 所有卡牌定义、配方、价格的唯一数据源
# 在 Godot 检查器中编辑 game_data.tres 即可调整全部数值
class_name GameData
extends Resource

# ═══════════════════════════════════════════════════════════════
# 子资源类型定义
# CardDef 已独立为全局类 Scripts/card_def.gd
# ═══════════════════════════════════════════════════════════════

class MarketEntry extends Resource:
	@export var card_type: int = 0
	@export var card_name: String = ""
	@export var sell_price: int = -1     # -1 表示不可出售
	@export var buy_price: int = -1      # -1 表示不可购买

class LaborRecipeDef extends Resource:
	@export var tool_type: int = -1      # -1 = 无需工具
	@export var target_type: int = 0
	@export var result_type: int = 0     # -1 = 只销毁
	@export var result_name: String = ""
	@export var result_count: int = 1
	@export var duration: float = 3.0    # 劳作时间（秒）
	@export var byproduct1_type: int = -1
	@export var byproduct1_name: String = ""
	@export var byproduct1_chance: float = 0.0
	@export var byproduct2_type: int = -1
	@export var byproduct2_name: String = ""
	@export var byproduct2_chance: float = 0.0
	@export var is_transformation: bool = false   # 是否销毁目标地块

class StartingCardDef extends Resource:
	@export var card_type: int = 0
	@export var card_name: String = ""
	@export var position: Vector2 = Vector2(400, 300)
	@export var value_a: float = 0.0    # 0 = 使用 CardDef 默认值
	@export var value_b: float = 0.0

# ═══════════════════════════════════════════════════════════════
# 数据数组（在检查器中添加/删除条目）
# ═══════════════════════════════════════════════════════════════

@export var card_defs: Array[CardDef] = []
@export var market_entries: Array[MarketEntry] = []
@export var labor_recipes: Array[LaborRecipeDef] = []
@export var starting_cards: Array[StartingCardDef] = []

# ═══════════════════════════════════════════════════════════════
# 查询方法
# ═══════════════════════════════════════════════════════════════

func get_card_def(ct: int) -> CardDef:
	for d in card_defs:
		if d.card_type == ct: return d
	return null

func get_market_entry(ct: int) -> MarketEntry:
	for e in market_entries:
		if e.card_type == ct: return e
	return null

func get_buyable_tools() -> Array[MarketEntry]:
	var result: Array[MarketEntry] = []
	for e in market_entries:
		if e.buy_price > 0: result.append(e)
	return result
