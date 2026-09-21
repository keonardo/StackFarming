# TestTool — 验证 stack_on 容器/普通堆叠位置修复 (M2)
# 运行: godot --headless --path . --script res://tools/test_stack_position.gd
extends SceneTree

var _fail: int = 0
var _frame: int = 0
var _nodes: Array = []
var _phase: int = 0

func _initialize() -> void:
	pass

func _process(_delta: float) -> bool:
	_frame += 1
	match _phase:
		0:
			if _frame < 3: return false  # 等资源/autoload 就绪
			_phase = 1
			_setup()
		1:
			_finish()
			return true
	return false

func _check(label: String, cond: bool) -> void:
	if cond:
		print("  ✔ ", label)
	else:
		_fail += 1
		print("  ✘ ", label)

func _setup() -> void:
	print("[TestStack] start (frame=", _frame, ")")

	var terrain_scene: PackedScene = load("res://Scenes/container_card.tscn")
	var pond: BaseCard = terrain_scene.instantiate()
	pond.type = CardEnums.CardType.POND
	root.add_child(pond)
	pond.global_position = Vector2(300, 300)
	_nodes.append(pond)
	print("  池塘类型=", pond.type, " role=", pond.role)

	var res_scene: PackedScene = load("res://Scenes/resource_card.tscn")
	var egg: BaseCard = res_scene.instantiate()
	egg.type = CardEnums.CardType.DUCK_EGG
	egg.role = CardEnums.CardRole.RESOURCE
	root.add_child(egg)
	egg.global_position = Vector2(340, 310)
	_nodes.append(egg)

	# ========== 场景一：容器堆叠（鸭蛋 → 池塘）==========
	egg.stack_on(pond)
	print("  [容器] stack_parent=", egg.stack_parent, " pos=", egg.global_position)
	_check("容器堆叠后 stack_parent 为池塘", egg.stack_parent == pond)
	_check("容器堆叠位置非 (0,0)", egg.global_position != Vector2.ZERO)
	_check("容器铺格（非默认+35）", egg.global_position.distance_to(pond.global_position + Vector2(0,35)) > 5.0)

	# ========== 场景二：普通堆叠（第二颗蛋叠到第一颗蛋）==========
	var egg2: BaseCard = res_scene.instantiate()
	egg2.type = CardEnums.CardType.DUCK_EGG
	egg2.role = CardEnums.CardRole.RESOURCE
	root.add_child(egg2)
	egg2.global_position = Vector2(380, 340)
	_nodes.append(egg2)

	egg2.stack_on(egg)
	print("  [普通] egg2 stack_parent 类型=", egg2.stack_parent)
	_check("普通堆叠 stack_parent 为 egg", egg2.stack_parent == egg)
	_check("普通堆叠位置非 (0,0)", egg2.global_position != Vector2.ZERO)
	_check("普通堆叠位置 ≈ 父+35", egg2.global_position.distance_to(egg.global_position + Vector2(0,35)) < 5.0)

	# ========== 场景三：容器继续放（第3张进池塘，验证铺格）==========
	var egg3: BaseCard = res_scene.instantiate()
	egg3.type = CardEnums.CardType.DUCK_EGG
	egg3.role = CardEnums.CardRole.RESOURCE
	root.add_child(egg3)
	egg3.global_position = Vector2(500, 300)
	_nodes.append(egg3)
	egg3.stack_on(pond)
	print("  [容器2] egg3 stack_parent=", egg3.stack_parent, " pos=", egg3.global_position)
	_check("第二内容物仍可进容器", egg3.stack_parent == pond)
	_check("第二内容物铺格非默认+35", egg3.global_position.distance_to(pond.global_position + Vector2(0,35)) > 5.0)

func _finish() -> void:
	print("")
	if _fail == 0:
		print("[TestStack] 全部通过 ✔")
	else:
		print("[TestStack] 失败 ", _fail, " 项 ✘")
	quit(_fail)