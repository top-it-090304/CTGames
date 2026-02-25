@tool
extends Control

signal status_changed(text: String)

@export var symbols: Array[Texture2D] = []
@export var weights: Array[float] = []

@export var min_match_for_win: int = 3
@export var payout_x3: int = 2
@export var payout_x4: int = 4
@export var payout_x5: int = 8
@export var reward_unit: int = 94

@export_group("HUD")
@export var starting_money: int = 1552
@export var starting_spins: int = 10
@export var starting_tickets: int = 27
@export var spins_per_round: int = 1

@export var reels_row_path: NodePath
@export var button_path: NodePath
@export var label_path: NodePath

var reels_row: HBoxContainer
var btn: Button
var label: Label

var _reels: Array[Panel] = []
var _busy: bool = false
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _last_status: String = ""

var money: int = 0
var spins_left: int = 0
var tickets: int = 0

var hud_left: Panel
var hud_right: Panel
var lbl_money: Label
var lbl_spins: Label
var lbl_tickets: Label
var win_popup: Label

func _ready() -> void:
	_rng.randomize()
	reels_row = get_node_or_null(reels_row_path) as HBoxContainer
	btn = get_node_or_null(button_path) as Button
	label = get_node_or_null(label_path) as Label

	if reels_row == null:
		push_error("reels_row is null: set reels_row_path in Inspector")
		return

	money = starting_money
	spins_left = starting_spins
	tickets = starting_tickets

	_collect_reels()
	_configure_slot_layout()
	_hide_legacy_ui()
	_normalize_weights()
	_sync_reel_pools()
	_ensure_hud()
	_refresh_hud()
	_set_status("READY")

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
	if symbols.is_empty():
		_set_status("error: no symbols")
		return
	if _reels.is_empty():
		_set_status("no reels")
		return
	if spins_left < spins_per_round:
		_set_status("NO SPINS LEFT")
		_refresh_hud()
		return
	_spin()

func is_spinning() -> bool:
	return _busy

func _spin() -> void:
	_normalize_weights()
	_sync_reel_pools()
	_busy = true
	spins_left -= spins_per_round
	_refresh_hud()
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
	var result: Dictionary = _result_data(mid_indices)
	var win_amount: int = int(result.get("win_amount", 0))
	if win_amount > 0:
		money += win_amount
		_show_win_popup(win_amount)

	_set_status(String(result.get("text", "DONE")))
	_refresh_hud()
	_busy = false

func _set_status(text: String) -> void:
	_last_status = text
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

func _result_data(mid_indices: Array[int]) -> Dictionary:
	if mid_indices.is_empty():
		return {"text": "DONE", "win_amount": 0}

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
		return {
			"text": "LOSE | %s x%d" % [symbol_name, best_count],
			"win_amount": 0,
		}

	var mult: int = _payout_for(best_count)
	var amount: int = mult * reward_unit
	if best_count >= 5:
		return {
			"text": "JACKPOT | %s x%d | +%d" % [symbol_name, best_count, amount],
			"win_amount": amount,
		}
	return {
		"text": "WIN | %s x%d | +%d" % [symbol_name, best_count, amount],
		"win_amount": amount,
	}

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

func _refresh_hud() -> void:
	if lbl_money != null:
		lbl_money.text = "%s F" % _format_money(money)
	if lbl_spins != null:
		lbl_spins.text = "SPINS LEFT: %d" % spins_left
	if lbl_tickets != null:
		lbl_tickets.text = "%d TIX" % tickets

func _ensure_hud() -> void:
	hud_left = get_node_or_null("HudLeft") as Panel
	if hud_left == null:
		hud_left = Panel.new()
		hud_left.name = "HudLeft"
		add_child(hud_left)
	hud_left.position = Vector2(18.0, 18.0)
	hud_left.size = Vector2(360.0, 140.0)
	hud_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_left.add_theme_stylebox_override("panel", _hud_box())

	lbl_money = _ensure_label(hud_left, "Money", Rect2(16.0, 14.0, 330.0, 52.0), 52)
	lbl_spins = _ensure_label(hud_left, "Spins", Rect2(16.0, 76.0, 330.0, 36.0), 44)

	hud_right = get_node_or_null("HudRight") as Panel
	if hud_right == null:
		hud_right = Panel.new()
		hud_right.name = "HudRight"
		add_child(hud_right)
	hud_right.anchor_left = 1.0
	hud_right.anchor_right = 1.0
	hud_right.position = Vector2(-210.0, 18.0)
	hud_right.size = Vector2(192.0, 72.0)
	hud_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_right.add_theme_stylebox_override("panel", _hud_box())

	lbl_tickets = _ensure_label(hud_right, "Tickets", Rect2(16.0, 14.0, 160.0, 42.0), 44)
	lbl_tickets.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	win_popup = get_node_or_null("WinPopup") as Label
	if win_popup == null:
		win_popup = Label.new()
		win_popup.name = "WinPopup"
		add_child(win_popup)
	win_popup.anchor_left = 0.5
	win_popup.anchor_top = 0.5
	win_popup.anchor_right = 0.5
	win_popup.anchor_bottom = 0.5
	win_popup.position = Vector2(-220.0, -58.0)
	win_popup.size = Vector2(440.0, 120.0)
	win_popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	win_popup.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	win_popup.add_theme_font_size_override("font_size", 88)
	win_popup.add_theme_color_override("font_color", Color(1.0, 0.2, 0.95, 1.0))
	win_popup.visible = false
	win_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE

	move_child(hud_left, get_child_count() - 1)
	move_child(hud_right, get_child_count() - 1)
	move_child(win_popup, get_child_count() - 1)

func _ensure_label(parent: Control, name: String, rect: Rect2, font_size: int) -> Label:
	var node: Label = parent.get_node_or_null(name) as Label
	if node == null:
		node = Label.new()
		node.name = name
		parent.add_child(node)
	node.position = rect.position
	node.size = rect.size
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

func _show_win_popup(amount: int) -> void:
	if win_popup == null:
		return
	win_popup.text = "+%d F" % amount
	win_popup.visible = true
	var tw: Tween = create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(win_popup, "modulate:a", 1.0, 0.01)
	tw.tween_interval(0.85)
	tw.tween_property(win_popup, "modulate:a", 0.0, 0.28)
	tw.finished.connect(_hide_win_popup)

func _hide_win_popup() -> void:
	if win_popup == null:
		return
	win_popup.visible = false
	win_popup.modulate.a = 1.0

func _format_money(value: int) -> String:
	var s: String = str(maxi(value, 0))
	var out: String = ""
	var count: int = 0
	for i: int in range(s.length() - 1, -1, -1):
		out = s.substr(i, 1) + out
		count += 1
		if count == 3 and i > 0:
			out = "." + out
			count = 0
	return out

func _hud_box() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.88)
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	return style

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
