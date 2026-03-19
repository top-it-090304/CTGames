extends CanvasLayer

var pause_panel: Panel
var is_paused: bool = false

const PIXEL_FONT: FontFile = preload("res://textures/pixeloidsans/PixeloidSans.ttf")

func _ready() -> void:
	pause_panel = get_node_or_null("PausePanel") as Panel
	if pause_panel == null:
		return
	pause_panel.visible = false
	_configure_visuals()

	var resume_btn   := pause_panel.get_node_or_null("ResumeButton")   as Button
	var settings_btn := pause_panel.get_node_or_null("SettingsButton") as Button
	var quit_btn     := pause_panel.get_node_or_null("QuitButton")     as Button
	if resume_btn   != null: resume_btn.pressed.connect(_on_resume_pressed)
	if settings_btn != null: settings_btn.pressed.connect(_on_settings_pressed)
	if quit_btn     != null: quit_btn.pressed.connect(_on_quit_pressed)

func _configure_visuals() -> void:
	# --- Панель по центру экрана (увеличена под 3 кнопки) ---
	pause_panel.anchor_left   = 0.5
	pause_panel.anchor_right  = 0.5
	pause_panel.anchor_top    = 0.5
	pause_panel.anchor_bottom = 0.5
	pause_panel.offset_left   = -200.0
	pause_panel.offset_right  =  200.0
	pause_panel.offset_top    = -280.0
	pause_panel.offset_bottom =  280.0

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.88)
	style.corner_radius_top_left     = 12
	style.corner_radius_top_right    = 12
	style.corner_radius_bottom_left  = 12
	style.corner_radius_bottom_right = 12
	pause_panel.add_theme_stylebox_override("panel", style)

	# --- Заголовок ---
	var title := pause_panel.get_node_or_null("TitleLabel") as Label
	if title != null:
		title.anchor_left   = 0.0
		title.anchor_right  = 1.0
		title.anchor_top    = 0.0
		title.anchor_bottom = 0.0
		title.offset_left   = 0.0
		title.offset_right  = 0.0
		title.offset_top    = 40.0
		title.offset_bottom = 110.0
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		title.add_theme_font_override("font", PIXEL_FONT)
		title.add_theme_font_size_override("font_size", 56)
		title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.08, 1.0))
		title.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
		title.add_theme_constant_override("outline_size", 6)
		title.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	# --- Три кнопки равноудалённо ---
	_configure_button("ResumeButton",   150.0)
	_configure_button("SettingsButton", 270.0)
	_configure_button("QuitButton",     390.0)

func _configure_button(node_name: String, offset_top: float) -> void:
	var btn := pause_panel.get_node_or_null(node_name) as Button
	if btn == null:
		return

	btn.anchor_left   = 0.5
	btn.anchor_right  = 0.5
	btn.anchor_top    = 0.0
	btn.anchor_bottom = 0.0
	btn.offset_left   = -140.0
	btn.offset_right  =  140.0
	btn.offset_top    = offset_top
	btn.offset_bottom = offset_top + 80.0

	btn.add_theme_font_override("font", PIXEL_FONT)
	btn.add_theme_font_size_override("font_size", 32)
	btn.add_theme_color_override("font_color",         Color(1.0, 1.0, 1.0, 1.0))
	btn.add_theme_color_override("font_hover_color",   Color(1.0, 0.86, 0.08, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color(0.8, 0.65, 0.0,  1.0))
	btn.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0,   1.0))
	btn.add_theme_constant_override("outline_size", 3)
	btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.15, 0.15, 0.15, 0.9)
	normal.corner_radius_top_left     = 8
	normal.corner_radius_top_right    = 8
	normal.corner_radius_bottom_left  = 8
	normal.corner_radius_bottom_right = 8

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.25, 0.22, 0.05, 1.0)
	hover.corner_radius_top_left     = 8
	hover.corner_radius_top_right    = 8
	hover.corner_radius_bottom_left  = 8
	hover.corner_radius_bottom_right = 8

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(0.18, 0.15, 0.02, 1.0)
	pressed.corner_radius_top_left     = 8
	pressed.corner_radius_top_right    = 8
	pressed.corner_radius_bottom_left  = 8
	pressed.corner_radius_bottom_right = 8

	btn.add_theme_stylebox_override("normal",  normal)
	btn.add_theme_stylebox_override("hover",   hover)
	btn.add_theme_stylebox_override("pressed", pressed)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_ESCAPE:
			_toggle_pause()
			get_viewport().set_input_as_handled()

func _toggle_pause() -> void:
	is_paused = !is_paused
	get_tree().paused = is_paused
	if pause_panel != null:
		pause_panel.visible = is_paused

func _on_resume_pressed() -> void:
	is_paused = false
	get_tree().paused = false
	if pause_panel != null:
		pause_panel.visible = false

func _on_settings_pressed() -> void:
	pass # сюда потом добавишь логику настроек

func _on_quit_pressed() -> void:
	get_tree().paused = false
	get_tree().quit()
