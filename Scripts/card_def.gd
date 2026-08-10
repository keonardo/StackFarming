# CardDef.gd — 单张卡牌的定义资源
# 每张卡牌对应一个 .tres 文件放在 data/cards/ 目录下
# YARD 扫描目录后构建 Registry，运行时通过 string ID 查询
class_name CardDef
extends Resource

@export var card_type: int = 0       # CardEnums.CardType
@export var card_name: String = ""
@export var value_a: float = 100.0   # 默认 HP / 强度 / 承载力 / 耐久
@export var value_b: float = 0.0     # 默认 Progress / 存续 / 湿润 / 效率
