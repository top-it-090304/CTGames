extends Control

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

	var frame: ColorRect = get_node_or_null("Frame") as ColorRect
	if frame == null:
		frame = ColorRect.new()
		frame.name = "Frame"
		add_child(frame)
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.color = Color(0.01, 0.01, 0.01, 1.0)

	rounds_left_label = _ensure_label("RoundsLeftLabel", Vector2(36.0, 24.0), Vector2(940.0, 68.0), 44, Color(1.0, 0.55, 0.12, 1.0), HORIZONTAL_ALIGNMENT_LEFT)
	debt_title_label = _ensure_label("DebtTitleLabel", Vector2(36.0, 130.0), Vector2(250.0, 52.0), 36, Color(0.75, 0.75, 0.75, 1.0), HORIZONTAL_ALIGNMENT_LEFT)
	debt_value_label = _ensure_label("DebtValueLabel", Vector2(350.0, 130.0), Vector2(300.0, 52.0), 44, Color(1.0, 0.86, 0.08, 1.0), HORIZONTAL_ALIGNMENT_RIGHT)
	deposited_title_label = _ensure_label("DepositedTitleLabel", Vector2(36.0, 198.0), Vector2(320.0, 52.0), 36, Color(0.75, 0.75, 0.75, 1.0), HORIZONTAL_ALIGNMENT_LEFT)
	deposited_value_label = _ensure_label("DepositedValueLabel", Vector2(350.0, 198.0), Vector2(300.0, 52.0), 44, Color(1.0, 0.86, 0.08, 1.0), HORIZONTAL_ALIGNMENT_RIGHT)
	interest_title_label = _ensure_label("InterestTitleLabel", Vector2(36.0, 266.0), Vector2(300.0, 52.0), 36, Color(0.75, 0.75, 0.75, 1.0), HORIZONTAL_ALIGNMENT_LEFT)
	interest_value_label = _ensure_label("InterestValueLabel", Vector2(350.0, 266.0), Vector2(420.0, 52.0), 38, Color(1.0, 0.55, 0.12, 1.0), HORIZONTAL_ALIGNMENT_RIGHT)

func _ensure_label(name: String, pos: Vector2, size: Vector2, font_size: int, color: Color, align: HorizontalAlignment) -> Label:
	var lbl: Label = get_node_or_null(name) as Label
	if lbl == null:
		lbl = Label.new()
		lbl.name = name
		add_child(lbl)
	lbl.position = pos
	lbl.size = size
	lbl.horizontal_alignment = align
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	lbl.add_theme_constant_override("outline_size", 2)
	return lbl
