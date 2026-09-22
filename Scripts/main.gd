# Main.gd — 主场景脚本，开局硬编码生成卡牌
extends Node2D

func _ready() -> void:
	# 等 CardSpawner 就绪后生成开局卡牌
	await get_tree().process_frame
	await get_tree().process_frame

	_spawn_starting_cards()

func _spawn_starting_cards() -> void:
	var sp := CardSpawner.instance
	if not sp: return

	# 布局：地形卡 2×2（160×200）错开网格摆放，避免放大后重叠
	sp.spawn_card(3, "水田", Vector2(320, 300))    # 左上 农田
	sp.spawn_card(0, "池塘", Vector2(600, 300))    # 居中 水域
	sp.spawn_card(10, "鸭子", Vector2(600, 270))   # 池塘内
	sp.spawn_card(10, "鸭子", Vector2(640, 310))   # 池塘内
	sp.spawn_card(20, "鱼竿", Vector2(920, 300))   # 右侧 工具
