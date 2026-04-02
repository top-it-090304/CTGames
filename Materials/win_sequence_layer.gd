extends Control

signal sequence_started
signal sequence_finished(total_win: int)
signal hit_highlight_requested(points: Array, palette_index: int)
signal highlight_cleared

const PIXEL_FONT: FontFile = preload("res://textures/pixeloidsans/PixeloidSans.ttf")

@export var dim_alpha: float = 0.28
@export var combo_hold_time: float = 0.46
@export var combo_gap_time: float = 0.10
@export var total_hold_time: float = 0.80

var _dim: ColorRect
var _combo_popup: Panel
var _combo_name_label: Label
var _combo_value_label: Label
var _total_popup: Panel
var _total_title_label: Label
var _total_value_label: Label

var _active: bool = false
var _sequence_token: int = 0

func _ready() -> void:
	_ensure_ui_tree()
	_bind_nodes()
	_apply_visuals()
	_hide_all()

func is_playing() -> bool:
	return _active

func play_result(result: Dictionary) -> void:
	var hits: Array = result.get("hits", []) as Array
	var total_win: int = int(result.get("win_amount", 0))
	if hits.is_empty() or total_win <= 0:
		return

	_clear_slot_highlight_direct()
	emit_signal("highlight_cleared")
	_sequence_token += 1
	var token: int = _sequence_token
	_active = true
	visible = true
	emit_signal("sequence_started")
	_run_sequence.call_deferred(token, result.duplicate(true))

func _run_sequence(token: int, result: Dictionary) -> void:
	await _play_sequence(token, result)

func _play_sequence(token: int, result: Dictionary) -> void:
	if token != _sequence_token:
		return

	var hits: Array = result.get("hits", []) as Array
	var total_win: int = int(result.get("win_amount", 0))
	if hits.is_empty() or total_win <= 0:
		_finish_sequence(token, total_win)
		return

	_hide_all()
	await _show_dim(token)
	if token != _sequence_token:
		return

	var hits_total: int = 0
	var palette_index: int = 0
	for hit_var: Variant in hits:
		var hit: Dictionary = hit_var as Dictionary
		hits_total += int(hit.get("win_amount", 0))
		var points: Array = hit.get("points", []) as Array
		if points.is_empty():
			_clear_slot_highlight_direct()
			emit_signal("highlight_cleared")
		else:
			_show_slot_highlight_direct(points.duplicate(), palette_index)
			emit_signal("hit_highlight_requested", points.duplicate(), palette_index)
		await _show_combo_hit(token, hit)
		_clear_slot_highlight_direct()
		emit_signal("highlight_cleared")
		if token != _sequence_token:
			return
		palette_index += 1

	var bonus_amount: int = maxi(total_win - hits_total, 0)
	if bonus_amount > 0:
		await _show_combo_hit(token, {
			"combo_name": "БОНУС",
			"symbol_index": -1,
			"symbol_value": 0,
			"win_amount": bonus_amount,
		})
		if token != _sequence_token:
			return

	_clear_slot_highlight_direct()
	emit_signal("highlight_cleared")
	await _show_total(token, total_win)
	if token != _sequence_token:
		return

	await _hide_dim(token)
	_finish_sequence(token, total_win)

func _finish_sequence(token: int, total_win: int) -> void:
	if token != _sequence_token:
		return
	_clear_slot_highlight_direct()
	emit_signal("highlight_cleared")
	_hide_all()
	_active = false
	emit_signal("sequence_finished", total_win)

func _slot_ui_target() -> Node:
	return get_tree().get_first_node_in_group("slot_ui_highlight_target")

func _show_slot_highlight_direct(points: Array, palette_index: int) -> void:
	var slot_ui: Node = _slot_ui_target()
	if slot_ui != null and slot_ui.has_method("show_combo_highlight"):
		slot_ui.call("show_combo_highlight", points, palette_index)

func _clear_slot_highlight_direct() -> void:
	var slot_ui: Node = _slot_ui_target()
	if slot_ui != null and slot_ui.has_method("clear_combo_highlight"):
		slot_ui.call("clear_combo_highlight")

func _show_dim(token: int) -> void:
	if _dim == null:
		return
	_dim.visible = true
	_dim.modulate.a = 0.0
	var tw: Tween = create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(_dim, "modulate:a", dim_alpha, 0.12)
	await tw.finished
	if token != _sequence_token:
		return

func _hide_dim(token: int) -> void:
	if _dim == null or not _dim.visible:
		return
	var tw: Tween = create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(_dim, "modulate:a", 0.0, 0.14)
	await tw.finished
	if token != _sequence_token:
		return
	_dim.visible = false

func _show_combo_hit(token: int, hit: Dictionary) -> void:
	if _combo_popup == null or _combo_name_label == null or _combo_value_label == null:
		return

	var combo_name: String = String(hit.get("combo_name", "КОМБО")).to_upper()
	var symbol_title: String = _symbol_title(int(hit.get("symbol_index", -1))).to_upper()
	var win_amount: int = int(hit.get("win_amount", 0))

	if symbol_title.is_empty():
		_combo_name_label.text = combo_name
	else:
		_combo_name_label.text = "%s  %s" % [combo_name, symbol_title]
	_combo_value_label.text = "+%d Ф" % win_amount

	_combo_popup.visible = true
	_combo_popup.modulate.a = 0.0
	_combo_popup.scale = Vector2(0.88, 0.88)

	var intro: Tween = create_tween()
	intro.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	intro.parallel().tween_property(_combo_popup, "scale", Vector2.ONE, 0.16)
	intro.parallel().tween_property(_combo_popup, "modulate:a", 1.0, 0.12)
	await intro.finished
	if token != _sequence_token:
		return

	await get_tree().create_timer(combo_hold_time).timeout
	if token != _sequence_token:
		return

	var outro: Tween = create_tween()
	outro.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	outro.parallel().tween_property(_combo_popup, "scale", Vector2(1.03, 1.03), 0.10)
	outro.parallel().tween_property(_combo_popup, "modulate:a", 0.0, 0.10)
	await outro.finished
	if token != _sequence_token:
		return

	_combo_popup.visible = false
	await get_tree().create_timer(combo_gap_time).timeout

func _show_total(token: int, total_win: int) -> void:
	if _total_popup == null or _total_title_label == null or _total_value_label == null:
		return

	_total_title_label.text = "TOTAL"
	_total_value_label.text = "+%d Ф" % total_win

	_total_popup.visible = true
	_total_popup.modulate.a = 0.0
	_total_popup.scale = Vector2(0.82, 0.82)

	var intro: Tween = create_tween()
	intro.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	intro.parallel().tween_property(_total_popup, "scale", Vector2.ONE, 0.20)
	intro.parallel().tween_property(_total_popup, "modulate:a", 1.0, 0.16)
	await intro.finished
	if token != _sequence_token:
		return

	await get_tree().create_timer(total_hold_time).timeout
	if token != _sequence_token:
		return

	var outro: Tween = create_tween()
	outro.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	outro.parallel().tween_property(_total_popup, "scale", Vector2(1.04, 1.04), 0.12)
	outro.parallel().tween_property(_total_popup, "modulate:a", 0.0, 0.12)
	await outro.finished
	if token != _sequence_token:
		return

	_total_popup.visible = false

func _ensure_ui_tree() -> void:
	if get_node_or_null("Dim") == null:
		var dim := ColorRect.new()
		dim.name = "Dim"
		add_child(dim)

	var combo_popup: Panel = get_node_or_null("ComboPopup") as Panel
	if combo_popup == null:
		combo_popup = Panel.new()
		combo_popup.name = "ComboPopup"
		add_child(combo_popup)
	if combo_popup.get_node_or_null("ComboNameLabel") == null:
		var combo_name := Label.new()
		combo_name.name = "ComboNameLabel"
		combo_popup.add_child(combo_name)
	if combo_popup.get_node_or_null("ComboValueLabel") == null:
		var combo_value := Label.new()
		combo_value.name = "ComboValueLabel"
		combo_popup.add_child(combo_value)

	var total_popup: Panel = get_node_or_null("TotalPopup") as Panel
	if total_popup == null:
		total_popup = Panel.new()
		total_popup.name = "TotalPopup"
		add_child(total_popup)
	if total_popup.get_node_or_null("TotalTitleLabel") == null:
		var total_title := Label.new()
		total_title.name = "TotalTitleLabel"
		total_popup.add_child(total_title)
	if total_popup.get_node_or_null("TotalValueLabel") == null:
		var total_value := Label.new()
		total_value.name = "TotalValueLabel"
		total_popup.add_child(total_value)

func _bind_nodes() -> void:
	_dim = get_node_or_null("Dim") as ColorRect
	_combo_popup = get_node_or_null("ComboPopup") as Panel
	_combo_name_label = get_node_or_null("ComboPopup/ComboNameLabel") as Label
	_combo_value_label = get_node_or_null("ComboPopup/ComboValueLabel") as Label
	_total_popup = get_node_or_null("TotalPopup") as Panel
	_total_title_label = get_node_or_null("TotalPopup/TotalTitleLabel") as Label
	_total_value_label = get_node_or_null("TotalPopup/TotalValueLabel") as Label

func _apply_visuals() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = true

	if _dim != null:
		_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		_dim.color = Color(0.0, 0.0, 0.0, 1.0)
		_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_apply_panel_style(_combo_popup, Vector2(248.0, 86.0), Vector2(0.0, -230.0), Color(0.02, 0.02, 0.02, 0.93), Color(1.0, 0.48, 0.08, 1.0), 2)
	_apply_panel_style(_total_popup, Vector2(260.0, 94.0), Vector2(0.0, -230.0), Color(0.0, 0.0, 0.0, 0.96), Color(1.0, 0.78, 0.12, 1.0), 3)

	_apply_label_style(_combo_name_label, 23, Color(1.0, 0.55, 0.12, 1.0), Color.BLACK, 3)
	_apply_label_style(_combo_value_label, 28, Color(1.0, 0.96, 0.94, 1.0), Color.BLACK, 3)
	_apply_label_style(_total_title_label, 24, Color(1.0, 0.55, 0.12, 1.0), Color.BLACK, 3)
	_apply_label_style(_total_value_label, 31, Color(1.0, 0.86, 0.08, 1.0), Color.BLACK, 4)

	if _combo_name_label != null:
		_combo_name_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
		_combo_name_label.offset_left = 10.0
		_combo_name_label.offset_top = 6.0
		_combo_name_label.offset_right = -10.0
		_combo_name_label.offset_bottom = 34.0

	if _combo_value_label != null:
		_combo_value_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
		_combo_value_label.offset_left = 10.0
		_combo_value_label.offset_top = 38.0
		_combo_value_label.offset_right = -10.0
		_combo_value_label.offset_bottom = 74.0

	if _total_title_label != null:
		_total_title_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
		_total_title_label.offset_left = 10.0
		_total_title_label.offset_top = 6.0
		_total_title_label.offset_right = -10.0
		_total_title_label.offset_bottom = 36.0

	if _total_value_label != null:
		_total_value_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
		_total_value_label.offset_left = 10.0
		_total_value_label.offset_top = 38.0
		_total_value_label.offset_right = -10.0
		_total_value_label.offset_bottom = 82.0

func _apply_panel_style(panel: Panel, panel_size: Vector2, centered_offset: Vector2, bg: Color, border: Color, border_px: int) -> void:
	if panel == null:
		return
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = centered_offset.x - panel_size.x * 0.5
	panel.offset_top = centered_offset.y - panel_size.y * 0.5
	panel.offset_right = centered_offset.x + panel_size.x * 0.5
	panel.offset_bottom = centered_offset.y + panel_size.y * 0.5
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = border_px
	style.border_width_top = border_px
	style.border_width_right = border_px
	style.border_width_bottom = border_px
	panel.add_theme_stylebox_override("panel", style)

func _apply_label_style(label: Label, font_size: int, font_color: Color, outline_color: Color, outline_size: int) -> void:
	if label == null:
		return
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	label.add_theme_font_override("font", PIXEL_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	label.add_theme_color_override("font_outline_color", outline_color)
	label.add_theme_constant_override("outline_size", outline_size)

func _symbol_title(symbol_index: int) -> String:
	match symbol_index:
		0:
			return "ЛИМОН"
		1:
			return "ВИШНЯ"
		2:
			return "КЛЕВЕР"
		3:
			return "КОЛОКОЛ"
		4:
			return "АЛМАЗ"
		5:
			return "СУНДУК"
		6:
			return "СЕМЕРКИ"
		_:
			return ""

func _hide_all() -> void:
	if _dim != null:
		_dim.visible = false
		_dim.modulate.a = 0.0
	if _combo_popup != null:
		_combo_popup.visible = false
		_combo_popup.modulate.a = 1.0
		_combo_popup.scale = Vector2.ONE
	if _total_popup != null:
		_total_popup.visible = false
		_total_popup.modulate.a = 1.0
		_total_popup.scale = Vector2.ONE
