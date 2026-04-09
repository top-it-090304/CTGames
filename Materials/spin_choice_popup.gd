extends Control

signal option_selected(spins: int, cost: int, ticket_bonus: int)
signal canceled
signal replay_requested

const OPTION_COLOR_DEFAULT: Color = Color(0.63, 0.63, 0.65, 1.0)
const OPTION_COLOR_HOVER: Color = Color(0.84, 0.84, 0.86, 1.0)
const OPTION_COLOR_PRESSED: Color = Color(0.48, 0.48, 0.5, 1.0)
const OPTION_COLOR_SELECTED: Color = Color(0.92, 0.92, 0.94, 1.0)
const TITLE_COLOR: Color = Color(1.0, 0.53, 0.08, 1.0)

const MODE_CLOSED: int = 0
const MODE_IDLE: int = 1
const MODE_CHOICE: int = 2
const MODE_GAME_OVER: int = 3
const MODE_FAIL_RETRY: int = 4

@export_group("Click Zones")
@export_range(0.0, 1.0, 0.001) var hit_x_min: float = 0.18
@export_range(0.0, 1.0, 0.001) var hit_x_max: float = 0.82
@export_range(0.0, 1.0, 0.001) var row_a_y: float = 0.565
@export_range(0.01, 0.20, 0.001) var row_a_half: float = 0.070
@export_range(0.0, 1.0, 0.001) var row_b_y: float = 0.655
@export_range(0.01, 0.20, 0.001) var row_b_half: float = 0.070
@export_range(0.0, 1.0, 0.001) var row_cancel_y: float = 0.740
@export_range(0.01, 0.20, 0.001) var row_cancel_half: float = 0.070

@export_group("Idle Logo")
@export var jackpot_jail_logo: Texture2D

var _backdrop: ColorRect
var _panel: Panel
var _title: Label
var _option_a: Button
var _option_b: Button
var _cancel: Button
var _logo: TextureRect

var _a_spins: int = 0
var _a_cost: int = 0
var _a_ticket_bonus: int = 0

var _b_spins: int = 0
var _b_cost: int = 0
var _b_ticket_bonus: int = 0
var _selected_option: int = 0
var _mode: int = MODE_CLOSED

func _ready() -> void:
	if jackpot_jail_logo == null:
		jackpot_jail_logo = load("res://textures/jackpot_jail_logo.png") as Texture2D
		if jackpot_jail_logo == null:
			jackpot_jail_logo = load("res://textures/jackpot_jail_slot.png") as Texture2D
		if jackpot_jail_logo == null:
			jackpot_jail_logo = load("res://Objects/jackpot_jail_slot.png") as Texture2D
		if jackpot_jail_logo == null:
			jackpot_jail_logo = load("res://textures/jackpot_jail_logo_nofon.png") as Texture2D
	_ensure_ui()
	visible = false

func open_popup(
		a_spins: int,
		a_cost: int,
		a_ticket_bonus: int,
		b_spins: int,
		b_cost: int,
		b_ticket_bonus: int
	) -> void:
	_ensure_ui()
	_a_spins = a_spins
	_a_cost = a_cost
	_a_ticket_bonus = a_ticket_bonus
	_b_spins = b_spins
	_b_cost = b_cost
	_b_ticket_bonus = b_ticket_bonus

	_mode = MODE_CHOICE
	_set_idle_logo_visible(false)
	_backdrop.color = Color(0.0, 0.0, 0.0, 0.0)
	_title.visible = true
	_title.text = "Сколько спинов?"
	_set_choice_controls_visible(true)
	_option_a.disabled = false
	_option_b.disabled = false
	_option_a.text = "%d Спина(-ов) +%d TOK (-%d Ф)" % [_a_spins, _a_ticket_bonus, _a_cost]
	_option_b.text = "%d Спина(-ов) +%d TOK (-%d Ф)" % [_b_spins, _b_ticket_bonus, _b_cost]
	_cancel.text = "Отмена"
	_selected_option = 0
	_refresh_option_visuals()
	_bring_to_front()
	visible = true

func close_popup() -> void:
	_mode = MODE_CLOSED
	visible = false

func show_game_over(required_debt: int, deposited: int) -> void:
	_ensure_ui()
	_mode = MODE_FAIL_RETRY
	_set_idle_logo_visible(false)
	_backdrop.color = Color(0.0, 0.0, 0.0, 0.85)
	_title.visible = true
	_title.text = "У вас недостаточно денег!"
	_set_choice_controls_visible(true)
	var shortfall: int = maxi(required_debt - deposited, 0)
	_option_a.text = "Переиграть"
	_option_a.disabled = false
	_option_b.visible = true
	_option_b.disabled = true
	_option_b.text = "Не хватает: %d Ф" % shortfall if shortfall > 0 else "Долг: %d Ф" % required_debt
	_cancel.text = "Закрыть"
	_cancel.visible = false
	_selected_option = 1
	_refresh_option_visuals()
	_bring_to_front()
	visible = true

func show_jackpot_jail() -> void:
	_ensure_ui()
	_mode = MODE_IDLE
	_set_choice_controls_visible(false)
	_set_idle_logo_visible(true)
	_title.visible = false
	_selected_option = 0
	_bring_to_front()
	visible = true

func is_open() -> bool:
	if not visible:
		return false
	return _mode == MODE_CHOICE or _mode == MODE_GAME_OVER or _mode == MODE_FAIL_RETRY

func _bring_to_front() -> void:
	var parent_node: Node = get_parent()
	if parent_node != null:
		parent_node.move_child(self, parent_node.get_child_count() - 1)
	move_to_front()

func _on_option_a_pressed() -> void:
	if _mode == MODE_FAIL_RETRY:
		emit_signal("replay_requested")
		return
	if _mode != MODE_CHOICE:
		return
	if _option_a == null or _option_a.disabled:
		return
	if _selected_option != 1:
		_selected_option = 1
		_refresh_option_visuals()
		return
	emit_signal("option_selected", _a_spins, _a_cost, _a_ticket_bonus)

func _on_option_b_pressed() -> void:
	if _mode == MODE_FAIL_RETRY:
		return
	if _mode != MODE_CHOICE:
		return
	if _option_b == null or _option_b.disabled:
		return
	if _selected_option != 2:
		_selected_option = 2
		_refresh_option_visuals()
		return
	emit_signal("option_selected", _b_spins, _b_cost, _b_ticket_bonus)

func _on_cancel_pressed() -> void:
	_selected_option = 0
	_refresh_option_visuals()
	emit_signal("canceled")

func _apply_button_selection_colors(button: Button, selected: bool) -> void:
	if button == null:
		return
	button.add_theme_color_override("font_color", OPTION_COLOR_SELECTED if selected else OPTION_COLOR_DEFAULT)
	button.add_theme_color_override("font_hover_color", OPTION_COLOR_HOVER)
	button.add_theme_color_override("font_pressed_color", OPTION_COLOR_PRESSED)
	if selected:
		button.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.0))
		button.add_theme_constant_override("outline_size", 0)
	else:
		button.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.0))
		button.add_theme_constant_override("outline_size", 0)

func _refresh_option_visuals() -> void:
	_apply_button_selection_colors(_option_a, _selected_option == 1 and (_option_a == null or not _option_a.disabled))
	if _mode == MODE_FAIL_RETRY and _option_b != null and _option_b.disabled:
		# Show as plain dim info text, not as a pressable button.
		_option_b.add_theme_color_override("font_color", Color(0.55, 0.55, 0.57, 1.0))
		_option_b.add_theme_color_override("font_hover_color", Color(0.55, 0.55, 0.57, 1.0))
		_option_b.add_theme_color_override("font_pressed_color", Color(0.55, 0.55, 0.57, 1.0))
		_option_b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		_apply_button_selection_colors(_option_b, _selected_option == 2 and (_option_b == null or not _option_b.disabled))
		if _option_b != null:
			_option_b.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_button_selection_colors(_cancel, false)

func _set_choice_controls_visible(show: bool) -> void:
	if _option_a != null:
		_option_a.visible = show
	if _option_b != null:
		_option_b.visible = show
	if _cancel != null:
		_cancel.visible = show

func _set_idle_logo_visible(show: bool) -> void:
	if _backdrop != null:
		_backdrop.color = Color(0.0, 0.0, 0.0, 1.0) if show else Color(0.0, 0.0, 0.0, 0.0)
		_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE if show else Control.MOUSE_FILTER_STOP

	if _logo != null:
		_logo.texture = jackpot_jail_logo
		_logo.visible = show and jackpot_jail_logo != null
		if _logo.visible:
			_logo.move_to_front()

	if _panel != null:
		_panel.visible = (not show) or jackpot_jail_logo == null

func press_by_normalized_position(nx: float, ny: float) -> bool:
	if not is_open() or _panel == null:
		return false

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return false

	var screen_pos: Vector2 = Vector2(nx * viewport_size.x, ny * viewport_size.y)
	var order: Array[String] = ["Option7Button", "Option3Button", "CancelButton"]
	for name: String in order:
		var btn: BaseButton = _panel.get_node_or_null(name) as BaseButton
		if btn == null or btn.disabled or not btn.visible:
			continue
		if btn.get_global_rect().has_point(screen_pos):
			btn.emit_signal("pressed")
			return true

	return false

func _ensure_ui() -> void:
	if _panel != null:
		_apply_layout()
		return

	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 120

	for stale_name: String in ["TitleLabel", "JackpotLogo", "Option7Button", "Option3Button", "CancelButton"]:
		var stale: Node = get_node_or_null(stale_name)
		if stale != null:
			stale.queue_free()

	_backdrop = get_node_or_null("Backdrop") as ColorRect
	if _backdrop == null:
		_backdrop = ColorRect.new()
		_backdrop.name = "Backdrop"
		add_child(_backdrop)
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = Color(0.0, 0.0, 0.0, 0.0)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.z_index = 120

	_panel = get_node_or_null("Panel") as Panel
	if _panel == null:
		_panel = Panel.new()
		_panel.name = "Panel"
		add_child(_panel)
	_panel.z_index = 130
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.0, 0.0, 0.0, 1.0)
	panel_style.border_width_left = 0
	panel_style.border_width_top = 0
	panel_style.border_width_right = 0
	panel_style.border_width_bottom = 0
	panel_style.border_color = Color(0.0, 0.0, 0.0, 0.0)
	panel_style.corner_radius_top_left = 0
	panel_style.corner_radius_top_right = 0
	panel_style.corner_radius_bottom_left = 0
	panel_style.corner_radius_bottom_right = 0
	_panel.add_theme_stylebox_override("panel", panel_style)

	_title = _panel.get_node_or_null("TitleLabel") as Label
	if _title == null:
		_title = Label.new()
		_title.name = "TitleLabel"
		_panel.add_child(_title)
	_title.anchor_left = 0.0
	_title.anchor_top = 0.0
	_title.anchor_right = 1.0
	_title.anchor_bottom = 0.0
	_title.offset_left = 24.0
	_title.offset_top = 22.0
	_title.offset_right = -24.0
	_title.offset_bottom = 72.0
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 52)
	_title.add_theme_color_override("font_color", TITLE_COLOR)
	_title.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.0))
	_title.add_theme_constant_override("outline_size", 0)
	_title.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_title.scale = Vector2.ONE

	_logo = get_node_or_null("JackpotLogo") as TextureRect
	if _logo == null:
		_logo = TextureRect.new()
		_logo.name = "JackpotLogo"
		add_child(_logo)
	_logo.anchor_left = 0.0
	_logo.anchor_top = 0.0
	_logo.anchor_right = 1.0
	_logo.anchor_bottom = 1.0
	_logo.offset_left = 0.0
	_logo.offset_top = 0.0
	_logo.offset_right = 0.0
	_logo.offset_bottom = 0.0
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_SCALE
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_logo.z_index = 125
	_logo.visible = false

	_option_a = _panel.get_node_or_null("Option7Button") as Button
	if _option_a == null:
		_option_a = Button.new()
		_option_a.name = "Option7Button"
		_panel.add_child(_option_a)
	_option_a.anchor_left = 0.0
	_option_a.anchor_right = 1.0
	_option_a.anchor_top = 0.0
	_option_a.anchor_bottom = 0.0
	_option_a.offset_left = 34.0
	_option_a.offset_top = 98.0
	_option_a.offset_right = -34.0
	_option_a.offset_bottom = 150.0

	_option_b = _panel.get_node_or_null("Option3Button") as Button
	if _option_b == null:
		_option_b = Button.new()
		_option_b.name = "Option3Button"
		_panel.add_child(_option_b)
	_option_b.anchor_left = 0.0
	_option_b.anchor_right = 1.0
	_option_b.anchor_top = 0.0
	_option_b.anchor_bottom = 0.0
	_option_b.offset_left = 34.0
	_option_b.offset_top = 162.0
	_option_b.offset_right = -34.0
	_option_b.offset_bottom = 214.0

	_cancel = _panel.get_node_or_null("CancelButton") as Button
	if _cancel == null:
		_cancel = Button.new()
		_cancel.name = "CancelButton"
		_panel.add_child(_cancel)
	_cancel.anchor_left = 0.5
	_cancel.anchor_right = 0.5
	_cancel.anchor_top = 0.0
	_cancel.anchor_bottom = 0.0
	_cancel.offset_left = -110.0
	_cancel.offset_top = 238.0
	_cancel.offset_right = 110.0
	_cancel.offset_bottom = 284.0

	for b: Button in [_option_a, _option_b, _cancel]:
		b.focus_mode = Control.FOCUS_NONE
		b.flat = true
		b.mouse_filter = Control.MOUSE_FILTER_STOP
		b.add_theme_font_size_override("font_size", 34)
		b.add_theme_color_override("font_color", OPTION_COLOR_DEFAULT)
		b.add_theme_color_override("font_hover_color", OPTION_COLOR_HOVER)
		b.add_theme_color_override("font_pressed_color", OPTION_COLOR_PRESSED)
		b.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.0))
		b.add_theme_constant_override("outline_size", 0)
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		b.scale = Vector2.ONE

	_refresh_option_visuals()

	if not _option_a.pressed.is_connected(_on_option_a_pressed):
		_option_a.pressed.connect(_on_option_a_pressed)
	if not _option_b.pressed.is_connected(_on_option_b_pressed):
		_option_b.pressed.connect(_on_option_b_pressed)
	if not _cancel.pressed.is_connected(_on_cancel_pressed):
		_cancel.pressed.connect(_on_cancel_pressed)

	_apply_layout()

func _apply_layout() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0

	if _panel == null:
		return

	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = Vector2(1024.0, 768.0)

	var inset_x: float = clampf(viewport_size.x * 0.035, 10.0, 28.0)
	var inset_y: float = clampf(viewport_size.y * 0.035, 10.0, 28.0)
	var content_width: float = viewport_size.x - inset_x * 2.0
	var title_h: float = clampf(viewport_size.y * 0.14, 66.0, 118.0)
	var title_gap: float = clampf(viewport_size.y * 0.025, 8.0, 20.0)
	var button_h: float = clampf(viewport_size.y * 0.082, 36.0, 68.0)
	var button_gap: float = clampf(viewport_size.y * 0.014, 6.0, 14.0)
	var cancel_h: float = clampf(button_h * 0.94, 34.0, 62.0)
	var top_start: float = clampf(viewport_size.y * 0.40, 150.0, 310.0)
	var font_title: int = int(clampf(viewport_size.y * 0.078, 34.0, 70.0))
	var font_button: int = int(clampf(viewport_size.y * 0.062, 24.0, 48.0))
	var horizontal_pad: float = clampf(content_width * 0.05, 18.0, 42.0)

	_panel.anchor_left = 0.0
	_panel.anchor_top = 0.0
	_panel.anchor_right = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = inset_x
	_panel.offset_top = inset_y
	_panel.offset_right = -inset_x
	_panel.offset_bottom = -inset_y

	if _title != null:
		_title.offset_left = horizontal_pad
		_title.offset_top = top_start - title_h - title_gap
		_title.offset_right = -horizontal_pad
		_title.offset_bottom = top_start - title_gap
		_title.add_theme_font_size_override("font_size", font_title)
		_title.add_theme_color_override("font_color", TITLE_COLOR)

	if _option_a != null:
		_option_a.anchor_left = 0.0
		_option_a.anchor_right = 1.0
		_option_a.anchor_top = 0.0
		_option_a.anchor_bottom = 0.0
		_option_a.offset_left = horizontal_pad
		_option_a.offset_top = top_start
		_option_a.offset_right = -horizontal_pad
		_option_a.offset_bottom = top_start + button_h
		_option_a.add_theme_font_size_override("font_size", font_button)

	if _option_b != null:
		_option_b.anchor_left = 0.0
		_option_b.anchor_right = 1.0
		_option_b.anchor_top = 0.0
		_option_b.anchor_bottom = 0.0
		_option_b.offset_left = horizontal_pad
		_option_b.offset_top = top_start + button_h + button_gap
		_option_b.offset_right = -horizontal_pad
		_option_b.offset_bottom = top_start + button_h * 2.0 + button_gap
		_option_b.add_theme_font_size_override("font_size", font_button)

	if _cancel != null:
		_cancel.anchor_left = 0.0
		_cancel.anchor_right = 1.0
		_cancel.anchor_top = 0.0
		_cancel.anchor_bottom = 0.0
		_cancel.offset_left = horizontal_pad
		_cancel.offset_top = top_start + button_h * 2.0 + button_gap * 2.0
		_cancel.offset_right = -horizontal_pad
		_cancel.offset_bottom = top_start + button_h * 2.0 + button_gap * 2.0 + cancel_h
		_cancel.add_theme_font_size_override("font_size", int(clampf(font_button * 0.92, 22.0, 38.0)))
