extends Panel

var _slot_ui: Control
var _title: Label
var _hint: Label
var _board_input: TextEdit
var _apply_button: Button
var _jackpot_button: Button
var _self_test_button: Button
var _clear_button: Button
var _close_button: Button
var _result_label: RichTextLabel

func _ready() -> void:
	_ensure_ui()
	visible = false

func set_slot_ui_target(slot_ui: Control) -> void:
	_slot_ui = slot_ui

func _ensure_ui() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2(24.0, 150.0)
	size = Vector2(560.0, 420.0)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.02, 0.02, 0.02, 0.95)
	panel_style.border_color = Color(1.0, 0.48, 0.12, 1.0)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	add_theme_stylebox_override("panel", panel_style)

	_title = _ensure_label("TitleLabel", Vector2(18.0, 12.0), Vector2(300.0, 34.0), 24, Color(1.0, 0.58, 0.14, 1.0))
	_title.text = "Тест комбинаций"

	_hint = _ensure_label("HintLabel", Vector2(18.0, 48.0), Vector2(520.0, 72.0), 14, Color(0.85, 0.85, 0.85, 1.0))
	_hint.text = "Вводи 3 строки по 5 символов через пробел. Можно: 1-7, лимон, вишня, клевер, колокол, алмаз, сундук, семерки."
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD

	_board_input = get_node_or_null("BoardInput") as TextEdit
	if _board_input == null:
		_board_input = TextEdit.new()
		_board_input.name = "BoardInput"
		add_child(_board_input)
	_board_input.position = Vector2(18.0, 126.0)
	_board_input.size = Vector2(524.0, 112.0)
	_board_input.wrap_mode = TextEdit.LINE_WRAPPING_NONE
	_board_input.text = "1 1 1 1 1\n1 1 1 1 1\n1 1 1 1 1"

	_apply_button = _ensure_button("ApplyButton", "Показать и проверить", Vector2(18.0, 252.0), Vector2(220.0, 42.0))
	_jackpot_button = _ensure_button("JackpotButton", "Джекпот", Vector2(248.0, 252.0), Vector2(104.0, 42.0))
	_self_test_button = _ensure_button("SelfTestButton", "Тест таблицы", Vector2(362.0, 252.0), Vector2(128.0, 42.0))
	_clear_button = _ensure_button("ClearButton", "Очистить", Vector2(18.0, 306.0), Vector2(90.0, 42.0))
	_close_button = _ensure_button("CloseButton", "X", Vector2(502.0, 10.0), Vector2(42.0, 36.0))

	_result_label = get_node_or_null("ResultLabel") as RichTextLabel
	if _result_label == null:
		_result_label = RichTextLabel.new()
		_result_label.name = "ResultLabel"
		add_child(_result_label)
	_result_label.position = Vector2(18.0, 354.0)
	_result_label.size = Vector2(524.0, 52.0)
	_result_label.bbcode_enabled = false
	_result_label.scroll_active = false
	_result_label.fit_content = false
	_result_label.text = "Здесь будет результат проверки."

	if not _apply_button.pressed.is_connected(_on_apply_pressed):
		_apply_button.pressed.connect(_on_apply_pressed)
	if not _jackpot_button.pressed.is_connected(_on_jackpot_pressed):
		_jackpot_button.pressed.connect(_on_jackpot_pressed)
	if not _self_test_button.pressed.is_connected(_on_self_test_pressed):
		_self_test_button.pressed.connect(_on_self_test_pressed)
	if not _clear_button.pressed.is_connected(_on_clear_pressed):
		_clear_button.pressed.connect(_on_clear_pressed)
	if not _close_button.pressed.is_connected(_on_close_pressed):
		_close_button.pressed.connect(_on_close_pressed)

func _ensure_label(name: String, pos: Vector2, rect_size: Vector2, font_size: int, color: Color) -> Label:
	var label: Label = get_node_or_null(name) as Label
	if label == null:
		label = Label.new()
		label.name = name
		add_child(label)
	label.position = pos
	label.size = rect_size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 2)
	return label

func _ensure_button(name: String, text_value: String, pos: Vector2, rect_size: Vector2) -> Button:
	var button: Button = get_node_or_null(name) as Button
	if button == null:
		button = Button.new()
		button.name = name
		add_child(button)
	button.position = pos
	button.size = rect_size
	button.text = text_value
	button.focus_mode = Control.FOCUS_NONE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.08, 1.0)
	style.border_color = Color(1.0, 0.48, 0.12, 1.0)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_outline_color", Color.BLACK)
	button.add_theme_constant_override("outline_size", 2)
	button.add_theme_font_size_override("font_size", 18)
	if name == "CloseButton":
		button.add_theme_font_size_override("font_size", 20)
		var close_style: StyleBoxFlat = StyleBoxFlat.new()
		close_style.bg_color = Color(0.35, 0.08, 0.08, 1.0)
		close_style.border_color = Color(1.0, 0.78, 0.78, 1.0)
		close_style.border_width_left = 2
		close_style.border_width_top = 2
		close_style.border_width_right = 2
		close_style.border_width_bottom = 2
		button.add_theme_stylebox_override("normal", close_style)
		button.add_theme_stylebox_override("hover", close_style)
		button.add_theme_stylebox_override("pressed", close_style)
	return button

func _on_apply_pressed() -> void:
	if _slot_ui == null:
		_result_label.text = "SlotUI не найден."
		return
	var parsed: Dictionary = _parse_board_text(_board_input.text)
	if not parsed.get("ok", false):
		_result_label.text = String(parsed.get("error", "Ошибка ввода."))
		return
	var board: Array = parsed.get("board", []) as Array
	if _slot_ui.has_method("debug_apply_and_evaluate_board"):
		var result: Dictionary = _slot_ui.call("debug_apply_and_evaluate_board", board) as Dictionary
		_result_label.text = _format_result(result)
		visible = true

func _on_jackpot_pressed() -> void:
	_board_input.text = "1 1 1 1 1\n1 1 1 1 1\n1 1 1 1 1"

func _on_clear_pressed() -> void:
	_board_input.text = ""
	_result_label.text = "Здесь будет результат проверки."

func _on_self_test_pressed() -> void:
	if _slot_ui == null:
		_result_label.text = "SlotUI не найден."
		return
	var report: Dictionary = _run_paytable_self_test()
	var passed: int = int(report.get("passed", 0))
	var total: int = int(report.get("total", 0))
	var details: Array = report.get("details", []) as Array
	var lines: Array[String] = []
	lines.append("Тест таблицы: %d/%d" % [passed, total])
	for detail_var: Variant in details:
		lines.append(String(detail_var))
	_result_label.text = "\n".join(lines)

func _on_close_pressed() -> void:
	visible = false

func _parse_board_text(text_value: String) -> Dictionary:
	if _slot_ui == null:
		return {"ok": false, "error": "SlotUI не найден."}
	var raw_lines: PackedStringArray = text_value.split("\n", false)
	var lines: Array[String] = []
	for raw_line: String in raw_lines:
		var line: String = raw_line.strip_edges()
		if not line.is_empty():
			lines.append(line)
	if lines.size() != 3:
		return {"ok": false, "error": "Нужно ровно 3 строки."}
	var board: Array = []
	for row_idx: int in range(3):
		var tokens: Array[String] = []
		for part_var: Variant in lines[row_idx].replace(",", " ").split(" ", false):
			var token: String = String(part_var).strip_edges()
			if not token.is_empty():
				tokens.append(token)
		if tokens.size() != 5:
			return {"ok": false, "error": "В строке %d должно быть 5 символов." % (row_idx + 1)}
		var row: Array = []
		for token: String in tokens:
			var index: int = int(_slot_ui.call("debug_symbol_index_for_token", token))
			if index < 0:
				return {"ok": false, "error": "Не понял символ: %s" % token}
			row.append(index)
		board.append(row)
	return {"ok": true, "board": board}

func _format_result(result: Dictionary) -> String:
	var lines: Array[String] = []
	var total: int = int(result.get("win_amount", 0))
	lines.append("Итог: +%d Ф" % total)
	var hits: Array = result.get("hits", []) as Array
	if hits.is_empty():
		lines.append("Комбинаций нет")
		return "\n".join(lines)
	for hit_var: Variant in hits:
		var hit: Dictionary = hit_var as Dictionary
		lines.append("%s x%d - +%d Ф" % [
			String(hit.get("combo_name", "")),
			int(hit.get("combo_multiplier", 1)),
			int(hit.get("win_amount", 0)),
		])
	return "\n".join(lines)

func _run_paytable_self_test() -> Dictionary:
	var cases: Array[Dictionary] = _build_paytable_test_cases()
	var passed: int = 0
	var details: Array[String] = []
	for case_var: Variant in cases:
		var case_data: Dictionary = case_var as Dictionary
		var parsed: Dictionary = _parse_board_text(String(case_data.get("board_text", "")))
		if not parsed.get("ok", false):
			details.append("FAIL %s: ошибка ввода (%s)" % [String(case_data.get("name", "")), String(parsed.get("error", ""))])
			continue
		var board: Array = parsed.get("board", []) as Array
		var result: Dictionary = _slot_ui.call("debug_apply_and_evaluate_board", board) as Dictionary
		var target_id: String = String(case_data.get("combo_id", ""))
		var target_mult: int = int(case_data.get("multiplier", 1))
		var got_hit: Dictionary = _first_hit_by_id(result.get("hits", []) as Array, target_id)
		if got_hit.is_empty():
			details.append("FAIL %s: не найдено комбо %s" % [String(case_data.get("name", "")), target_id])
			continue
		var got_mult: int = int(got_hit.get("combo_multiplier", -1))
		if got_mult != target_mult:
			details.append("FAIL %s: множитель %d, ожидалось %d" % [String(case_data.get("name", "")), got_mult, target_mult])
			continue
		passed += 1
		details.append("OK   %s: %s x%d" % [String(case_data.get("name", "")), target_id, got_mult])
	return {"passed": passed, "total": cases.size(), "details": details}

func _first_hit_by_id(hits: Array, combo_id: String) -> Dictionary:
	for hit_var: Variant in hits:
		var hit: Dictionary = hit_var as Dictionary
		if String(hit.get("combo_id", "")) == combo_id:
			return hit
	return {}

func _build_paytable_test_cases() -> Array[Dictionary]:
	return [
		{
			"name": "Гор. M",
			"combo_id": "horizontal",
			"multiplier": 1,
			"board_text": "1 1 1 2 3\n4 5 6 7 2\n3 4 5 6 7",
		},
		{
			"name": "Верт.",
			"combo_id": "vertical",
			"multiplier": 1,
			"board_text": "1 2 3 4 5\n1 3 4 5 6\n1 4 5 6 7",
		},
		{
			"name": "Диаг.",
			"combo_id": "diag",
			"multiplier": 1,
			"board_text": "1 2 3 4 5\n6 1 4 5 7\n3 4 1 6 2",
		},
		{
			"name": "Гор. L",
			"combo_id": "horizontal_l",
			"multiplier": 2,
			"board_text": "2 2 2 2 4\n1 3 5 6 7\n4 5 6 7 1",
		},
		{
			"name": "Гор. XL",
			"combo_id": "horizontal_xl",
			"multiplier": 3,
			"board_text": "3 3 3 3 3\n1 2 4 5 6\n2 4 5 6 7",
		},
		{
			"name": "Вверх",
			"combo_id": "up",
			"multiplier": 4,
			"board_text": "2 3 1 4 5\n6 1 7 1 3\n1 5 6 7 1",
		},
		{
			"name": "Вниз",
			"combo_id": "down",
			"multiplier": 4,
			"board_text": "1 3 4 5 1\n6 1 7 1 2\n3 4 1 5 6",
		},
		{
			"name": "Небо",
			"combo_id": "sky",
			"multiplier": 7,
			"board_text": "2 3 1 4 5\n6 1 7 1 3\n1 1 1 1 1",
		},
		{
			"name": "Земля",
			"combo_id": "earth",
			"multiplier": 7,
			"board_text": "1 1 1 1 1\n6 1 7 1 3\n2 4 1 5 6",
		},
		{
			"name": "Глаз",
			"combo_id": "eye",
			"multiplier": 8,
			"board_text": "2 1 1 1 3\n1 1 4 1 1\n5 1 1 1 6",
		},
		{
			"name": "Джекпот",
			"combo_id": "jackpot",
			"multiplier": 10,
			"board_text": "1 1 1 1 1\n1 1 1 1 1\n1 1 1 1 1",
		},
	]
