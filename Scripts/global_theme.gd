# global_theme.gd — autoload that sets CJK default font at startup
extends Node

func _ready() -> void:
	# Load the CJK font and apply as the default theme font
	var font_file = load("res://fonts/NotoSansSC-Regular.ttf")
	if font_file:
		var theme = Theme.new()
		theme.default_font = font_file
		theme.default_font_size = 13
		get_tree().root.theme = theme
		print("[GlobalTheme] CJK font loaded and applied.")
	else:
		printerr("[GlobalTheme] Failed to load CJK font!")
