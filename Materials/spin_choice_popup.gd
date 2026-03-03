extends Control

signal option_selected(spins: int, cost: int, ticket_bonus: int)
signal canceled

const OPTION_COLOR_DEFAULT: Color = Color(0.78, 0.78, 0.78, 1.0)
const OPTION_COLOR_HOVER: Color = Color(0.98, 0.98, 0.98, 1.0)
const OPTION_COLOR_PRESSED: Color = Color(0.6, 0.6, 0.6, 1.0)
const OPTION_COLOR_SELECTED: Color = Color(1.0, 1.0, 1.0, 1.0)

var _panel: Panel
var _title: Label
var _option_a: Button
var _option_b: Button
var _cancel: Button

var _a_spins: int = 0
var _a_cost: int = 0
var _a_ticket_bonus: int = 0

var _b_spins: int = 0
var _b_cost: int = 0
var _b_ticket_bonus: int = 0
var _selected_option: int = 0

func _ready() -> void:
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

	_title.text = "Сколько спинов?"
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
	visible = false

func show_game_over(required_debt: int, deposited: int) -> void:
	_ensure_ui()
	_title.text = "Долг не погашен"
	_option_a.text = "Нужно: %d Ф" % required_debt
	_option_b.text = "Внесено: %d Ф" % deposited
	_cancel.text = "Закрыть"
	_option_a.disabled = true
	_option_b.disabled = true
	_selected_option = 0
	_refresh_option_visuals()
	_bring_to_front()
	visible = true

func is_open() -> bool:
	return visible

func _bring_to_front() -> void:
	var parent_node: Node = get_parent()
	if parent_node != null:
		parent_node.move_child(self, parent_node.get_child_count() - 1)
	move_to_front()

func _on_option_a_pressed() -> void:
	if _option_a == null or _option_a.disabled:
		return
	if _selected_option != 1:
		_selected_option = 1
		_refresh_option_visuals()
		return
	emit_signal("option_selected", _a_spins, _a_cost, _a_ticket_bonus)

func _on_option_b_pressed() -> void:
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
	var color_normal: Color = OPTION_COLOR_SELECTED if selected else OPTION_COLOR_DEFAULT
	var color_hover: Color = OPTION_COLOR_SELECTED if selected else OPTION_COLOR_HOVER
	var color_pressed: Color = OPTION_COLOR_SELECTED if selected else OPTION_COLOR_PRESSED
	button.add_theme_color_override("font_color", color_normal)
	button.add_theme_color_override("font_hover_color", color_hover)
	button.add_theme_color_override("font_pressed_color", color_pressed)

func _refresh_option_visuals() -> void:
	_apply_button_selection_colors(_option_a, _selected_option == 1 and (_option_a == null or not _option_a.disabled))
	_apply_button_selection_colors(_option_b, _selected_option == 2 and (_option_b == null or not _option_b.disabled))
	_apply_button_selection_colors(_cancel, false)

func _ensure_ui() -> void:
	if _panel != null:
		return

	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	for stale_name: String in ["TitleLabel", "Option7Button", "Option3Button", "CancelButton"]:
		var stale: Node = get_node_or_null(stale_name)
		if stale != null:
			stale.queue_free()

	var backdrop: ColorRect = get_node_or_null("Backdrop") as ColorRect
	if backdrop == null:
		backdrop = ColorRect.new()
		backdrop.name = "Backdrop"
		add_child(backdrop)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.0, 0.0, 0.0, 0.0)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP

	_panel = get_node_or_null("Panel") as Panel
	if _panel == null:
		_panel = Panel.new()
		_panel.name = "Panel"
		add_child(_panel)
	_panel.anchor_left = 0.312
	_panel.anchor_top = 0.474
	_panel.anchor_right = 0.5
	_panel.anchor_bottom = 0.571
	_panel.offset_left = -360.0
	_panel.offset_top = -180.0
	_panel.offset_right = 360.0
	_panel.offset_bottom = 180.0
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.0, 0.0, 0.0, 1.0)
	panel_style.border_width_left = 0
	panel_style.border_width_top = 0
	panel_style.border_width_right = 0
	panel_style.border_width_bottom = 0
	_panel.add_theme_stylebox_override("panel", panel_style)

	_title = _panel.get_node_or_null("TitleLabel") as Label
	if _title == null:
		_title = Label.new()
		_title.name = "TitleLabel"
		_panel.add_child(_title)
	_title.anchor_left = 0.075
	_title.anchor_top = -0.5
	_title.anchor_right = 1.0
	_title.anchor_bottom = 0.18
	_title.offset_left = 20.0
	_title.offset_top = 64.0
	_title.offset_right = -20.0
	_title.offset_bottom = 120.0
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 130)
	_title.add_theme_color_override("font_color", Color(1.0, 0.55, 0.12, 1.0))
	_title.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	_title.add_theme_constant_override("outline_size", 3)
	_title.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_title.scale = Vector2(1.04, 1.04)

	_option_a = _panel.get_node_or_null("Option7Button") as Button
	if _option_a == null:
		_option_a = Button.new()
		_option_a.name = "Option7Button"
		_panel.add_child(_option_a)
	_option_a.anchor_left = 0.09
	_option_a.anchor_right = 1.0
	_option_a.anchor_top = -0.1
	_option_a.anchor_bottom = 0.045
	_option_a.offset_left = 26.0
	_option_a.offset_top = 156.0
	_option_a.offset_right = -26.0
	_option_a.offset_bottom = 220.0

	_option_b = _panel.get_node_or_null("Option3Button") as Button
	if _option_b == null:
		_option_b = Button.new()
		_option_b.name = "Option3Button"
		_panel.add_child(_option_b)
	_option_b.anchor_left = 0.104
	_option_b.anchor_right = 1.0
	_option_b.anchor_top = 0.0
	_option_b.anchor_bottom = 0.0
	_option_b.offset_left = 26.0
	_option_b.offset_top = 232.0
	_option_b.offset_right = -26.0
	_option_b.offset_bottom = 296.0

	_cancel = _panel.get_node_or_null("CancelButton") as Button
	if _cancel == null:
		_cancel = Button.new()
		_cancel.name = "CancelButton"
		_panel.add_child(_cancel)
	_cancel.anchor_left = 0.267
	_cancel.anchor_right = 1.0
	_cancel.anchor_top = 0.0
	_cancel.anchor_bottom = 0.513
	_cancel.offset_left = 160.0
	_cancel.offset_top = 306.0
	_cancel.offset_right = -160.0
	_cancel.offset_bottom = 364.0

	for b: Button in [_option_a, _option_b, _cancel]:
		b.focus_mode = Control.FOCUS_NONE
		b.flat = true
		b.mouse_filter = Control.MOUSE_FILTER_STOP
		b.add_theme_font_size_override("font_size", 90)
		b.add_theme_color_override("font_color", OPTION_COLOR_DEFAULT)
		b.add_theme_color_override("font_hover_color", OPTION_COLOR_HOVER)
		b.add_theme_color_override("font_pressed_color", OPTION_COLOR_PRESSED)
		b.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
		b.add_theme_constant_override("outline_size", 3)
		b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		b.scale = Vector2(1.02, 1.02)

	_refresh_option_visuals()

	if not _option_a.pressed.is_connected(_on_option_a_pressed):
		_option_a.pressed.connect(_on_option_a_pressed)
	if not _option_b.pressed.is_connected(_on_option_b_pressed):
		_option_b.pressed.connect(_on_option_b_pressed)
	if not _cancel.pressed.is_connected(_on_cancel_pressed):
		_cancel.pressed.connect(_on_cancel_pressed)
