extends Node2D

const COLUMNS := 5
const ROWS := 3
const REEL_SIZE := Vector2(130, 95)

const FINAL_PATTERN := [
	["lemon", "lemon", "lemon"],
	["lemon", "lemon", "lemon"],
	["lemon", "cherry", "lemon"],
	["lemon", "lemon", "lemon"],
	["bell", "lemon", "lemon"]
]

var _symbol_textures: Dictionary = {}
var _cells: Array = []
var _spin_button: Button
var _result_label: Label
var _spinning := false


func _ready() -> void:
	_load_symbol_textures()
	_build_ui()
	_apply_pattern(FINAL_PATTERN)


func _load_symbol_textures() -> void:
	var names := ["bell", "cherry", "chest", "clover", "diamond", "lemon", "seven"]
	for symbol_name in names:
		var path := "res://textures/%s.png" % symbol_name
		var texture := load(path) as Texture2D
		if texture != null:
			_symbol_textures[symbol_name] = texture


func _build_ui() -> void:
	for child in get_children():
		child.queue_free()

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.01, 0.01, 0.01, 0.95)
	root.add_child(bg)

	var frame := Panel.new()
	frame.position = Vector2(120, 60)
	frame.custom_minimum_size = Vector2(780, 360)
	frame.size = frame.custom_minimum_size
	frame.add_theme_stylebox_override("panel", _frame_style())
	root.add_child(frame)

	var reels_row := HBoxContainer.new()
	reels_row.position = Vector2(28, 24)
	reels_row.custom_minimum_size = Vector2(724, 300)
	reels_row.size = reels_row.custom_minimum_size
	reels_row.add_theme_constant_override("separation", 8)
	frame.add_child(reels_row)

	_cells.clear()
	for col in range(COLUMNS):
		var col_cells := []
		var reel_panel := Panel.new()
		reel_panel.custom_minimum_size = Vector2(REEL_SIZE.x, 300)
		reel_panel.add_theme_stylebox_override("panel", _reel_style())
		reels_row.add_child(reel_panel)

		var col_box := VBoxContainer.new()
		col_box.position = Vector2(8, 8)
		col_box.custom_minimum_size = Vector2(REEL_SIZE.x - 16.0, 284)
		col_box.size = col_box.custom_minimum_size
		col_box.add_theme_constant_override("separation", 6)
		reel_panel.add_child(col_box)

		for row in range(ROWS):
			var slot_bg := Panel.new()
			slot_bg.custom_minimum_size = REEL_SIZE
			slot_bg.add_theme_stylebox_override("panel", _cell_style())
			col_box.add_child(slot_bg)

			var icon := TextureRect.new()
			icon.set_anchors_preset(Control.PRESET_FULL_RECT)
			icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.position = Vector2(10, 6)
			icon.size = REEL_SIZE - Vector2(20, 12)
			slot_bg.add_child(icon)
			col_cells.append(icon)

		_cells.append(col_cells)

		if col < COLUMNS - 1:
			var separator := ColorRect.new()
			separator.custom_minimum_size = Vector2(3, 300)
			separator.color = Color(1.0, 0.49, 0.06, 0.7)
			reels_row.add_child(separator)

	_spin_button = Button.new()
	_spin_button.text = "SPIN"
	_spin_button.position = Vector2(340, 430)
	_spin_button.custom_minimum_size = Vector2(160, 54)
	_spin_button.add_theme_color_override("font_color", Color(1, 0.82, 0.55))
	_spin_button.add_theme_stylebox_override("normal", _button_style(Color(0.22, 0.06, 0.02)))
	_spin_button.add_theme_stylebox_override("hover", _button_style(Color(0.31, 0.08, 0.02)))
	_spin_button.add_theme_stylebox_override("pressed", _button_style(Color(0.45, 0.1, 0.03)))
	_spin_button.pressed.connect(_on_spin_pressed)
	root.add_child(_spin_button)

	_result_label = Label.new()
	_result_label.position = Vector2(120, 434)
	_result_label.size = Vector2(200, 40)
	_result_label.text = "Ready"
	_result_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.35))
	root.add_child(_result_label)


func _on_spin_pressed() -> void:
	if _spinning:
		return
	_spinning = true
	_spin_button.disabled = true
	_result_label.text = "Spinning..."

	for _step in range(18):
		_roll_all_cells()
		await get_tree().create_timer(0.06).timeout

	_apply_pattern(FINAL_PATTERN)
	_result_label.text = "Lemon hit!"
	_spin_button.disabled = false
	_spinning = false


func _roll_all_cells() -> void:
	for col in range(COLUMNS):
		for row in range(ROWS):
			_set_icon(col, row, _pick_symbol())


func _pick_symbol() -> String:
	var roll := randi_range(1, 100)
	if roll <= 55:
		return "lemon"
	if roll <= 63:
		return "bell"
	if roll <= 71:
		return "cherry"
	if roll <= 79:
		return "clover"
	if roll <= 87:
		return "chest"
	if roll <= 94:
		return "diamond"
	return "seven"


func _apply_pattern(pattern: Array) -> void:
	for col in range(COLUMNS):
		for row in range(ROWS):
			_set_icon(col, row, pattern[col][row])


func _set_icon(col: int, row: int, symbol_name: String) -> void:
	if not _symbol_textures.has(symbol_name):
		return
	var texture_rect: TextureRect = _cells[col][row]
	texture_rect.texture = _symbol_textures[symbol_name]


func _frame_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.02, 0.02, 1.0)
	style.border_color = Color(1.0, 0.49, 0.06, 1.0)
	style.border_width_left = 6
	style.border_width_top = 6
	style.border_width_right = 6
	style.border_width_bottom = 6
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	return style


func _reel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.01, 0.01, 0.01, 1.0)
	style.border_color = Color(0.86, 0.32, 0.07, 0.6)
	style.border_width_right = 1
	style.border_width_left = 1
	return style


func _cell_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.11, 0.01, 0.01, 0.95)
	style.border_color = Color(0.65, 0.12, 0.04, 0.9)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style


func _button_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(0.96, 0.53, 0.1, 1.0)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	return style
