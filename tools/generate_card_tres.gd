# generate_card_tres.gd — Run with: Godot --headless --path . --script tools/generate_card_tres.gd
# Creates all CardDef .tres files in data/cards/ with proper UIDs
@tool
extends SceneTree

const OUTPUT_DIR := "res://data/cards/"

# ── All Card Definitions ──
# [file_name, card_type, card_name, value_a, value_b]
const CARDS := [
	# Terrain (0-9)
	["pond", 0, "池塘", 4.0, 100.0],
	["big_pond", 1, "大水塘", 6.0, 100.0],
	["fish_pond", 2, "鱼塘", 10.0, 100.0],
	["paddy_field", 3, "水田", 4.0, 80.0],
	# Creatures (10-19)
	["duck", 10, "鸭子", 100.0, 0.0],
	["wild_rice_seed", 11, "菰米种", 100.0, 0.0],
	["water_caltrop", 12, "菱角", 80.0, 0.0],
	["bug", 13, "虫", 30.0, 0.0],
	# Tools (20-29)
	["fishing_rod", 20, "鱼竿", 10.0, 1.0],
	["hoe", 21, "锄头", 15.0, 1.0],
	["waterwheel", 22, "引水车", 20.0, 30.0],
	["compost_bin", 23, "堆肥箱", 15.0, 1.0],
	# Resources (30-39)
	["fish", 30, "鱼", 5.0, 120.0],
	["duck_egg", 31, "鸭蛋", 8.0, 90.0],
	["duck_feather", 32, "鸭毛", 2.0, 120.0],
	["wild_rice", 33, "菰米", 6.0, 180.0],
	["caltrop", 34, "菱角(果实)", 7.0, 150.0],
	["water", 35, "水", 30.0, 60.0],
	["feces", 36, "粪便", 10.0, 90.0],
	["fertilizer", 37, "肥料", 15.0, 180.0],
]

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var card_def_script: Script = load("res://Scripts/card_def.gd") as Script
	var count := 0

	for card in CARDS:
		var def := CardDef.new()
		def.card_type = card[1]
		def.card_name = card[2]
		def.value_a   = card[3]
		def.value_b   = card[4]

		var path: String = OUTPUT_DIR + card[0] + ".tres"
		var save_err: Error = ResourceSaver.save(def, path, ResourceSaver.FLAG_CHANGE_PATH)
		if save_err != OK:
			printerr("FAILED to save: ", path, " error: ", error_string(save_err))
			continue

		# Assign a unique UID so YARD can register this resource
		var uid_int := ResourceUID.create_id()
		ResourceSaver.set_uid(path, uid_int)
		if not ResourceUID.has_id(uid_int):
			ResourceUID.add_id(uid_int, path)

		print("CREATED: ", path, " -> ", card[2])
		count += 1

	print("\nDone. Created ", count, " card definition files in ", OUTPUT_DIR)
	quit(0)
