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

	sp.spawn_card(0, "池塘", Vector2(300, 300))
	sp.spawn_card(3, "水田", Vector2(300, 355))
	sp.spawn_card(20, "鱼竿", Vector2(420, 300))
	sp.spawn_card(10, "鸭子", Vector2(340, 340))
	sp.spawn_card(10, "鸭子", Vector2(500, 340))
