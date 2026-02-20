@tool
extends Control

signal status_changed(text: String)

@export var symbols: Array[Texture2D] = []
@export var weights: Array[float] = []
@export var min_match_for_win: int = 3
@export var payout_x3: int = 3
@export var payout_x4: int = 8
@export var payout_x5: int = 20

@export var reels_row_path: NodePath
@export var button_path: NodePath
@export var label_path: NodePath

var reels_row: HBoxContainer
var btn: Button
var label: Label

var _reels: Array[Panel] = []
var _busy: bool = false

func _ready() -> void:
	reels_row = get_node_or_null(reels_row_path) as HBoxContainer
	btn = get_node_or_null(button_path) as Button
	label = get_node_or_null(label_path) as Label

	if reels_row == null:
		push_error("reels_row is null: set reels_row_path in Inspector")
		return

	_collect_reels()
	_configure_slot_layout()
	_hide_legacy_ui()
	_normalize_weights()
	_sync_reel_pools()

	if btn != null and not btn.pressed.is_connected(request_spin):
		btn.pressed.connect(request_spin)

func _collect_reels() -> void:
	_reels.clear()
	for child: Node in reels_row.get_children():
		var panel: Panel = child as Panel
		if panel != null and panel.has_method("start_spin") and panel.has_method("stop_with_result"):
			_reels.append(panel)

func _gui_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or _busy:
		return

	if event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event as InputEventScreenTouch
		if touch_event.pressed:
			request_spin()
		return

	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			request_spin()

func request_spin() -> void:
	if Engine.is_editor_hint() or _busy:
		return
	_spin()

func is_spinning() -> bool:
	return _busy

func _spin() -> void:
	if symbols.is_empty():
		_set_status("error: no symbols")
		return
	if _reels.is_empty():
		_set_status("no reels")
		return

	_normalize_weights()
	_sync_reel_pools()
	_busy = true
	_set_status("SPINNING")

	for reel: Panel in _reels:
		reel.start_spin()

	await get_tree().create_timer(0.9).timeout

	for reel: Panel in _reels:
		if reel.has_method("stop_spin"):
			reel.call("stop_spin")
		elif reel.has_method("stop_with_result"):
			reel.call("stop_with_result", null, null, null)
		if reel.has_signal("stopped"):
			await reel.stopped
		else:
			await get_tree().create_timer(0.25).timeout
		await get_tree().create_timer(0.08).timeout

	var mid_indices: Array[int] = _collect_middle_indices()
	_set_status(_result_text(mid_indices))
	_busy = false

func _set_status(text: String) -> void:
	emit_signal("status_changed", text)

func _hide_legacy_ui() -> void:
	if btn != null:
		btn.visible = false
		btn.disabled = true
		btn.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if label != null:
		label.visible = false
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _normalize_weights() -> void:
	if weights.size() < symbols.size():
		var before: int = weights.size()
		weights.resize(symbols.size())
		for i: int in range(before, weights.size()):
			weights[i] = 1.0
	elif weights.size() > symbols.size():
		weights.resize(symbols.size())

func _sync_reel_pools() -> void:
	for reel: Panel in _reels:
		if reel.has_method("set_symbol_pool"):
			reel.call("set_symbol_pool", symbols, weights)

func _result_text(mid_indices: Array[int]) -> String:
	if mid_indices.is_empty():
		return "DONE"

	var counts: Dictionary = {}
	for idx: int in mid_indices:
		counts[idx] = int(counts.get(idx, 0)) + 1

	var best_symbol: int = -1
	var best_count: int = 0
	for key: Variant in counts.keys():
		var c: int = counts[key]
		if c > best_count:
			best_count = c
			best_symbol = int(key)

	var symbol_name: String = _symbol_name(best_symbol)
	if best_count < min_match_for_win:
		return "LOSE | %s x%d" % [symbol_name, best_count]

	var payout: int = _payout_for(best_count)
	if best_count >= 5:
		return "JACKPOT | %s x%d | x%d" % [symbol_name, best_count, payout]
	return "WIN | %s x%d | x%d" % [symbol_name, best_count, payout]

func _collect_middle_indices() -> Array[int]:
	var indices: Array[int] = []
	indices.resize(_reels.size())
	for i: int in range(_reels.size()):
		var reel: Panel = _reels[i]
		var tex: Texture2D = null
		if reel.has_method("get_middle_texture"):
			tex = reel.call("get_middle_texture") as Texture2D
		indices[i] = _index_for_texture(tex)
	return indices

func _index_for_texture(tex: Texture2D) -> int:
	if tex == null:
		return -1
	for i: int in range(symbols.size()):
		if symbols[i] == tex:
			return i
	var tex_path: String = tex.resource_path
	if not tex_path.is_empty():
		for i: int in range(symbols.size()):
			var symbol_tex: Texture2D = symbols[i]
			if symbol_tex != null and symbol_tex.resource_path == tex_path:
				return i
	return -1

func _symbol_name(index: int) -> String:
	if index < 0 or index >= symbols.size():
		return "?"
	var path: String = symbols[index].resource_path
	if path.is_empty():
		return "symbol_%d" % index
	return path.get_file().get_basename()

func _payout_for(match_count: int) -> int:
	if match_count >= 5:
		return payout_x5
	if match_count == 4:
		return payout_x4
	return payout_x3

func _configure_slot_layout() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	_ensure_backdrop()

	var reel_count: int = maxi(_reels.size(), 5)
	var reel_size: Vector2 = Vector2(300.0, 540.0)
	var gap: float = 16.0
	var reels_size: Vector2 = Vector2(float(reel_count) * reel_size.x + float(reel_count - 1) * gap, reel_size.y)
	var reels_pos: Vector2 = Vector2(200.0, 84.0)

	reels_row.position = reels_pos
	reels_row.custom_minimum_size = reels_size
	reels_row.size = reels_size
	reels_row.add_theme_constant_override("separation", int(gap))

	_ensure_frame(Rect2(reels_pos - Vector2(26.0, 26.0), reels_size + Vector2(52.0, 52.0)))
	_ensure_separators(reels_pos, reel_size, gap)

	for reel: Panel in _reels:
		reel.custom_minimum_size = reel_size
		reel.clip_contents = true
		reel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		reel.add_theme_stylebox_override("panel", _reel_style())

func _ensure_backdrop() -> void:
	var backdrop: ColorRect = get_node_or_null("Backdrop") as ColorRect
	if backdrop == null:
		backdrop = ColorRect.new()
		backdrop.name = "Backdrop"
		add_child(backdrop)
		move_child(backdrop, 0)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.0, 0.0, 0.0, 1.0)

func _ensure_frame(frame_rect: Rect2) -> void:
	var frame: Panel = get_node_or_null("SlotFrame") as Panel
	if frame == null:
		frame = Panel.new()
		frame.name = "SlotFrame"
		add_child(frame)
		move_child(frame, 1)

	frame.position = frame_rect.position
	frame.size = frame_rect.size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel", _frame_style())

func _ensure_separators(reels_pos: Vector2, reel_size: Vector2, gap: float) -> void:
	var root: Control = get_node_or_null("Separators") as Control
	if root == null:
		root = Control.new()
		root.name = "Separators"
		add_child(root)

	root.position = reels_pos
	root.size = Vector2(reels_row.size.x, reels_row.size.y)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	for child: Node in root.get_children():
		child.queue_free()

	for i: int in range(maxi(_reels.size() - 1, 0)):
		var sep: ColorRect = ColorRect.new()
		sep.color = Color(1.0, 0.53, 0.08, 0.85)
		sep.position = Vector2((float(i + 1) * reel_size.x) + (float(i) * gap) + (gap * 0.5) - 2.0, 12.0)
		sep.size = Vector2(4.0, reel_size.y - 24.0)
		root.add_child(sep)

	move_child(root, get_child_count() - 1)
	move_child(reels_row, get_child_count() - 1)

func _frame_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 1.0)
	style.border_color = Color(1.0, 0.52, 0.08, 1.0)
	style.border_width_left = 9
	style.border_width_top = 9
	style.border_width_right = 9
	style.border_width_bottom = 9
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	return style

func _reel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 1.0)
	style.border_color = Color(1.0, 0.45, 0.05, 0.35)
	style.border_width_left = 1
	style.border_width_right = 1
	return style
