extends Control

const COLOR_BG: Color = Color(0.0, 0.0, 0.0, 1.0)
const COLOR_LINE: Color = Color(1.0, 0.47, 0.10, 0.9)
const COLOR_TITLE: Color = Color(0.98, 0.53, 0.10, 1.0)
const COLOR_VALUE: Color = Color(1.0, 0.86, 0.08, 1.0)

var rounds_left_label: Label
var debt_title_label: Label
var debt_value_label: Label
var deposited_title_label: Label
var deposited_value_label: Label
var interest_title_label: Label
var interest_value_label: Label


func _ready() -> void:
	_ensure_ui()


func set_data(rounds_left: int, debt_target: int, deposited: int, interest_percent: float, interest_amount: int) -> void:
	_ensure_ui()
	rounds_left_label.text = "☠ %d ROUNDS LEFT ☠" % maxi(rounds_left, 0)
	debt_title_label.text = "DEBT:"
	debt_value_label.text = "%d Ф" % maxi(debt_target, 0)
	deposited_title_label.text = "DEPOSITED:"
	deposited_value_label.text = "%d Ф" % maxi(deposited, 0)
	interest_title_label.text = "INTEREST:"
	interest_value_label.text = "%.1f%% (%dФ)" % [interest_percent, maxi(interest_amount, 0)]


func _ensure_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.x < 2.0 or viewport_size.y < 2.0:
		viewport_size = Vector2(640.0, 400.0)

	var frame: ColorRect = get_node_or_null("Frame") as ColorRect
	if frame == null:
		frame = ColorRect.new()
		frame.name = "Frame"
		add_child(frame)
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.position = Vector2.ZERO
	frame.size = viewport_size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.z_index = -100
	frame.color = COLOR_BG

	var left: float = 22.0
	var right: float = viewport_size.x - 22.0
	var width: float = right - left

	_ensure_line("LineTop", Vector2(left, 72.0), Vector2(width, 2.0))
	_ensure_line("LineMid1", Vector2(left, 154.0), Vector2(width, 2.0))
	_ensure_line("LineMid2", Vector2(left, 236.0), Vector2(width, 2.0))
	_ensure_line("LineBottom", Vector2(left, 318.0), Vector2(width, 2.0))

	rounds_left_label = _ensure_label("RoundsLeftLabel", Vector2(left, 16.0), Vector2(width, 48.0), 50, COLOR_TITLE, HORIZONTAL_ALIGNMENT_LEFT)
	debt_title_label = _ensure_label("DebtTitleLabel", Vector2(left, 88.0), Vector2(250.0, 48.0), 28, COLOR_TITLE, HORIZONTAL_ALIGNMENT_LEFT)
	debt_value_label = _ensure_label("DebtValueLabel", Vector2(left + 258.0, 78.0), Vector2(width - 258.0, 58.0), 56, COLOR_VALUE, HORIZONTAL_ALIGNMENT_RIGHT)
	deposited_title_label = _ensure_label("DepositedTitleLabel", Vector2(left, 170.0), Vector2(250.0, 48.0), 28, COLOR_TITLE, HORIZONTAL_ALIGNMENT_LEFT)
	deposited_value_label = _ensure_label("DepositedValueLabel", Vector2(left + 258.0, 160.0), Vector2(width - 258.0, 58.0), 56, COLOR_VALUE, HORIZONTAL_ALIGNMENT_RIGHT)
	interest_title_label = _ensure_label("InterestTitleLabel", Vector2(left, 252.0), Vector2(250.0, 44.0), 28, COLOR_TITLE, HORIZONTAL_ALIGNMENT_LEFT)
	interest_value_label = _ensure_label("InterestValueLabel", Vector2(left + 258.0, 276.0), Vector2(width - 258.0, 36.0), 32, COLOR_TITLE, HORIZONTAL_ALIGNMENT_RIGHT)


func _ensure_line(name: String, pos: Vector2, line_size: Vector2) -> ColorRect:
	var line: ColorRect = get_node_or_null(name) as ColorRect
	if line == null:
		line = ColorRect.new()
		line.name = name
		add_child(line)
	line.position = pos
	line.size = line_size
	line.color = COLOR_LINE
	return line


func _ensure_label(name: String, pos: Vector2, label_size: Vector2, font_size: int, color: Color, align: HorizontalAlignment) -> Label:
	var lbl: Label = get_node_or_null(name) as Label
	if lbl == null:
		lbl = Label.new()
		lbl.name = name
		add_child(lbl)
	lbl.position = pos
	lbl.size = label_size
	lbl.horizontal_alignment = align
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	lbl.add_theme_constant_override("outline_size", 1)
	return lbl
