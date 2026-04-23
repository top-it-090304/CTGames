extends CanvasLayer

var pause_panel: Panel
var is_paused: bool = false
var quit_confirm_box: Panel
var quit_confirm_label: RichTextLabel
var quit_yes_btn: Button
var quit_no_btn: Button
var quit_choices: HBoxContainer
@onready var game = get_node("/root/Game")

# Переменная для определения, что именно мы подтверждаем
var confirm_mode: String = "" # "quit" или "restart"

const PIXEL_FONT: FontFile = preload("res://textures/pixeloidsans/PixeloidSans.ttf")

func _ready() -> void:
	pause_panel = get_node_or_null("PausePanel") as Panel
	if pause_panel == null:
		return
	pause_panel.visible = false
	_configure_visuals()
	_setup_quit_confirm()
	_setup_pause_button()

func _setup_pause_button() -> void:
	var pause_btn := get_node_or_null("PauseButton") as Button
	if pause_btn == null:
		return

	pause_btn.text = "≡"
	pause_btn.flat = true
	pause_btn.focus_mode = Control.FOCUS_NONE

	pause_btn.anchor_left    = 0.0
	pause_btn.anchor_right   = 0.0
	pause_btn.anchor_top     = 0.0
	pause_btn.anchor_bottom = 0.0
	pause_btn.offset_left    = 16.0
	pause_btn.offset_right   = 80.0
	pause_btn.offset_top     = 136.0
	pause_btn.offset_bottom = 220.0

	pause_btn.add_theme_font_override("font", PIXEL_FONT)
	pause_btn.add_theme_font_size_override("font_size", 112)
	pause_btn.add_theme_color_override("font_color",         Color(1.0, 1.0, 1.0, 1.0))
	pause_btn.add_theme_color_override("font_hover_color",   Color(1.0, 0.86, 0.08, 1.0))
	pause_btn.add_theme_color_override("font_pressed_color", Color(0.8, 0.65, 0.0,  1.0))
	pause_btn.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0,   1.0))
	pause_btn.add_theme_constant_override("outline_size", 3)
	pause_btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.0, 0.0, 0.0, 0.75)
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

	pause_btn.add_theme_stylebox_override("normal",  normal)
	pause_btn.add_theme_stylebox_override("hover",   hover)
	pause_btn.add_theme_stylebox_override("pressed", pressed)

	pause_btn.pressed.connect(_on_pause_button_pressed)
	pause_btn.visible = false

func _setup_quit_confirm() -> void:
	quit_confirm_box = Panel.new()
	quit_confirm_box.anchor_left    = 0.0
	quit_confirm_box.anchor_right   = 1.0
	quit_confirm_box.anchor_top     = 1.0
	quit_confirm_box.anchor_bottom = 1.0
	quit_confirm_box.offset_left    = 0.0
	quit_confirm_box.offset_right   = 0.0
	quit_confirm_box.offset_top     = -180.0
	quit_confirm_box.offset_bottom = 0.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.0, 0.0, 0.0, 1.0)
	quit_confirm_box.add_theme_stylebox_override("panel", bg)
	quit_confirm_box.visible = false
	add_child(quit_confirm_box)

	quit_confirm_label = RichTextLabel.new()
	quit_confirm_label.anchor_left    = 0.0
	quit_confirm_label.anchor_right   = 1.0
	quit_confirm_label.anchor_top     = 0.0
	quit_confirm_label.anchor_bottom = 1.0
	quit_confirm_label.offset_left    = 34.0
	quit_confirm_label.offset_right   = -34.0
	quit_confirm_label.offset_top     = 22.0
	quit_confirm_label.offset_bottom = -70.0
	quit_confirm_label.bbcode_enabled = false
	quit_confirm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quit_confirm_label.scroll_active = false
	quit_confirm_label.add_theme_font_override("normal_font", PIXEL_FONT)
	quit_confirm_label.add_theme_font_size_override("normal_font_size", 34)
	quit_confirm_label.add_theme_color_override("default_color", Color(1.0, 1.0, 1.0, 1.0))
	quit_confirm_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	quit_confirm_label.add_theme_constant_override("outline_size", 3)
	quit_confirm_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	quit_confirm_box.add_child(quit_confirm_label)

	quit_choices = HBoxContainer.new()
	quit_choices.anchor_left    = 1.0
	quit_choices.anchor_right   = 1.0
	quit_choices.anchor_top     = 1.0
	quit_choices.anchor_bottom = 1.0
	quit_choices.offset_left    = -230.0
	quit_choices.offset_right   = -18.0
	quit_choices.offset_top     = -106.0
	quit_choices.offset_bottom = -46.0
	quit_choices.alignment = BoxContainer.ALIGNMENT_END
	quit_choices.add_theme_constant_override("separation", 20)
	quit_confirm_box.add_child(quit_choices)

	quit_yes_btn = Button.new()
	quit_yes_btn.text = "Да"
	quit_no_btn = Button.new()
	quit_no_btn.text = "Нет"

	for btn: Button in [quit_yes_btn, quit_no_btn]:
		btn.flat = true
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_override("font", PIXEL_FONT)
		btn.add_theme_font_size_override("font_size", 56)
		btn.add_theme_color_override("font_color",         Color(1.0, 1.0, 1.0, 1.0))
		btn.add_theme_color_override("font_hover_color",   Color(1.0, 0.86, 0.08, 1.0))
		btn.add_theme_color_override("font_pressed_color", Color(0.8, 0.8, 0.8, 1.0))
		btn.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
		btn.add_theme_constant_override("outline_size", 2)
		btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		quit_choices.add_child(btn)

	quit_yes_btn.pressed.connect(_on_confirm_yes_pressed)
	quit_no_btn.pressed.connect(_on_quit_cancelled)

	var resume_btn   := pause_panel.get_node_or_null("ResumeButton")   as Button
	var restart_btn  := pause_panel.get_node_or_null("SettingsButton") as Button
	var quit_btn     := pause_panel.get_node_or_null("QuitButton")     as Button
	
	if resume_btn   != null:
		resume_btn.pressed.connect(_on_resume_pressed)
	if restart_btn != null:
		restart_btn.pressed.connect(_on_restart_pressed)
	if quit_btn     != null:
		quit_btn.pressed.connect(_on_quit_pressed)

func _configure_visuals() -> void:
	pause_panel.anchor_left    = 0.5
	pause_panel.anchor_right   = 0.5
	pause_panel.anchor_top     = 0.5
	pause_panel.anchor_bottom = 0.5
	pause_panel.offset_left    = -200.0
	pause_panel.offset_right   =  200.0
	pause_panel.offset_top     = -280.0
	pause_panel.offset_bottom =  280.0

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.88)
	style.corner_radius_top_left     = 12
	style.corner_radius_top_right    = 12
	style.corner_radius_bottom_left  = 12
	style.corner_radius_bottom_right = 12
	pause_panel.add_theme_stylebox_override("panel", style)

	var title := pause_panel.get_node_or_null("TitleLabel") as Label
	if title != null:
		title.anchor_left    = 0.0
		title.anchor_right   = 1.0
		title.anchor_top     = 0.0
		title.anchor_bottom = 0.0
		title.offset_left    = 0.0
		title.offset_right   = 0.0
		title.offset_top     = 40.0
		title.offset_bottom = 110.0
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		title.add_theme_font_override("font", PIXEL_FONT)
		title.add_theme_font_size_override("font_size", 56)
		title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.08, 1.0))
		title.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
		title.add_theme_constant_override("outline_size", 6)
		title.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	_configure_button("ResumeButton",   150.0)
	_configure_button("SettingsButton", 270.0)
	_configure_button("QuitButton",     390.0)
	
	var restart_btn = pause_panel.get_node_or_null("SettingsButton") as Button
	if restart_btn:
		restart_btn.text = "Новая игра"

func _configure_button(node_name: String, offset_top: float) -> void:
	var btn := pause_panel.get_node_or_null(node_name) as Button
	if btn == null:
		return

	btn.anchor_left    = 0.5
	btn.anchor_right   = 0.5
	btn.anchor_top     = 0.0
	btn.anchor_bottom = 0.0
	btn.offset_left    = -140.0
	btn.offset_right   =  140.0
	btn.offset_top     = offset_top
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

func _process(_delta: float) -> void:
	var pause_btn := get_node_or_null("PauseButton") as Button
	if pause_btn and not is_paused:
		# Если в главном скрипте Game заблокирован UI (например, открыт выбор спинов),
		# то кнопка паузы скрывается
		if game and game.has_method("is_ui_blocked"):
			pause_btn.visible = not game.is_ui_blocked()
		else:
			pause_btn.visible = true

func _on_pause_button_pressed() -> void:
	if not is_paused and _is_session_active():
		return
	_toggle_pause()

func _is_session_active() -> bool:
	var game_node := get_tree().get_root().get_node_or_null("Game")
	if game_node == null:
		return false
	var slot_ui = game_node.get_node_or_null("SubViewport/SlotUI")
	if slot_ui == null:
		return false
	var spinning: bool = false
	if slot_ui.has_method("is_spinning"):
		spinning = bool(slot_ui.call("is_spinning"))
	var has_spins: bool = slot_ui.get("spins_left") > 0
	
	# Проверка анимации награды
	var reward_active: bool = false
	var round_sys = game_node.get_node_or_null("RoundSystem")
	if round_sys != null and round_sys.has_method("is_reward_sequence_active"):
		reward_active = bool(round_sys.call("is_reward_sequence_active"))
		
	return spinning or has_spins or reward_active

func _toggle_pause() -> void:
	is_paused = !is_paused
	get_tree().paused = is_paused
	if pause_panel != null:
		pause_panel.visible = is_paused
	if not is_paused and quit_confirm_box != null:
		quit_confirm_box.visible = false
	var pause_btn := get_node_or_null("PauseButton") as Button
	if pause_btn != null:
		pause_btn.visible = not is_paused

func _on_resume_pressed() -> void:
	is_paused = false
	get_tree().paused = false
	if pause_panel != null:
		pause_panel.visible = false
	var pause_btn := get_node_or_null("PauseButton") as Button
	if pause_btn != null:
		pause_btn.visible = true

func _on_restart_pressed() -> void:
	confirm_mode = "restart"
	if pause_panel != null:
		pause_panel.visible = false
	quit_confirm_box.visible = true
	_type_text("Ты действительно хочешь начать всё сначала?")

func _on_quit_pressed() -> void:
	confirm_mode = "quit"
	if pause_panel != null:
		pause_panel.visible = false
	quit_confirm_box.visible = true
	_type_text("Думаешь выйти из игры так просто?")

func _type_text(text: String) -> void:
	quit_confirm_label.text = ""
	quit_choices.visible = false
	var char_i := 0
	while char_i <= text.length():
		quit_confirm_label.text = text.substr(0, char_i)
		char_i += 1
		await get_tree().create_timer(0.03).timeout
	quit_choices.visible = true

func _on_confirm_yes_pressed() -> void:
	if confirm_mode == "restart":
		# Логика из main_menu.gd для кнопки "Заново"
		SaveSystem.delete_save()
		get_tree().paused = false
		get_tree().change_scene_to_file("res://Materials/game.tscn")
	else:
		# Сохраняем прогресс перед обычным выходом
		if game != null and game.has_method("save_game"):
			game.save_game()
		get_tree().paused = false
		get_tree().quit()

func _on_quit_cancelled() -> void:
	quit_confirm_box.visible = false
	confirm_mode = ""
	# Возвращаем панель паузы
	if pause_panel != null:
		pause_panel.visible = true
