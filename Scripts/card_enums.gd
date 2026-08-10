# CardEnums.gd — 四类卡牌枚举体系
class_name CardEnums

# ============================================================
# 卡牌角色 (Card Role)
# ============================================================
enum CardRole {
	CREATURE = 0,  # 生物 — ValueA=饥饿/耐久, ValueB=进度
	RESOURCE = 1,  # 资源 — ValueA=强度/含量, ValueB=存续时间
	TERRAIN  = 2,  # 地貌 — ValueA=承载力, ValueB=环境值
	TOOL     = 3,  # 工具 — ValueA=耐久, ValueB=效率
}

# ============================================================
# 卡牌类型 (Card Type) — 按角色分段
#   0-9:   地貌 (Terrain)
#  10-19:  生物 (Creature)
#  20-29:  工具 (Tool)
#  30-39:  资源 (Resource)
# ============================================================
enum CardType {
	# --- 地貌 (0-9) ---
	POND          = 0,   # 池塘
	BIG_POND      = 1,   # 大水塘
	FISH_POND     = 2,   # 鱼塘
	PADDY_FIELD   = 3,   # 水田

	# --- 生物 (10-19) ---
	DUCK          = 10,  # 鸭子
	WILD_RICE_SEED = 11, # 菰米种
	WATER_CALTROP  = 12, # 菱角
	BUG           = 13,  # 虫

	# --- 工具 (20-29) ---
	FISHING_ROD  = 20,  # 鱼竿
	HOE          = 21,  # 锄头
	WATERWHEEL   = 22,  # 引水车
	COMPOST_BIN  = 23,  # 堆肥箱
	LABORER      = 24,  # 长工

	# --- 资源 (30-39) ---
	FISH          = 30,  # 鱼
	DUCK_EGG      = 31,  # 鸭蛋
	DUCK_FEATHER  = 32,  # 鸭毛
	WILD_RICE     = 33,  # 菰米
	FECES         = 36,  # 粪便
	FERTILIZER    = 37,  # 肥料
	CALTROP       = 34,  # 菱角(果实)
	WATER         = 35,  # 水
}

# ============================================================
# 从 CardType 推断 CardRole
# ============================================================
static func role_from_type(card_type: CardType) -> CardRole:
	if card_type < 10:
		return CardRole.TERRAIN
	elif card_type < 20:
		return CardRole.CREATURE
	elif card_type < 30:
		return CardRole.TOOL
	else:
		return CardRole.RESOURCE

# ============================================================
# 从 CardType 获取默认卡牌名称
# ============================================================
static func default_name(card_type: CardType) -> String:
	match card_type:
		CardType.POND:           return "池塘"
		CardType.BIG_POND:       return "大水塘"
		CardType.FISH_POND:      return "鱼塘"
		CardType.PADDY_FIELD:    return "水田"
		CardType.DUCK:           return "鸭子"
		CardType.WILD_RICE_SEED: return "菰米种"
		CardType.WATER_CALTROP:  return "菱角"
		CardType.BUG:            return "虫"
		CardType.FISHING_ROD:    return "鱼竿"
		CardType.HOE:            return "锄头"
		CardType.WATERWHEEL:     return "引水车"
		CardType.FISH:           return "鱼"
		CardType.DUCK_EGG:       return "鸭蛋"
		CardType.DUCK_FEATHER:   return "鸭毛"
		CardType.WILD_RICE:      return "菰米"
		CardType.CALTROP:        return "菱角"
		CardType.WATER:          return "水"
		CardType.COMPOST_BIN:    return "堆肥箱"
		CardType.LABORER:        return "长工"
		CardType.FECES:          return "粪便"
		CardType.FERTILIZER:     return "肥料"
		_:                       return "未知卡牌"

# ============================================================
# 旧节气枚举保留
# ============================================================
enum SolarTerm { NONE, JINGZHE, MANGZHONG, SHUANGJIANG }
