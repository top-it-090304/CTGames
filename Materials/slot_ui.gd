@tool
extends Control

signal status_changed(text: String)
signal hud_changed(money: int, spins_left: int, tickets: int)
signal win_popup_requested(amount: int)
signal spin_completed(win_amount: int)

@export var symbols: Array[Texture2D] = []
@export var weights: Array[float] = []
@export var symbol_multiplier: float = 1.0

@export_group("Start")
@export var starting_money: int = 13
@export var starting_spins: int = 2
@export var starting_tickets: int = 2
@export var spins_per_round: int = 1

@export var reels_row_path: NodePath
@export var button_path: NodePath
@export var label_path: NodePath

const SYMBOL_VALUES: Dictionary = {
	"lemon": 2,
	"cherry": 2,
	"clover": 3,
	"bell": 3,
	"diamond": 5,
	"chest": 5,
	"seven": 7,
}

const SYMBOL_CHANCES: Dictionary = {
	"lemon": 19.4,
	"cherry": 19.4,
	"clover": 14.9,
	"bell": 14.9,
	"diamond": 11.9,
	"chest": 11.9,
	"seven": 7.5,
}

const SYMBOL_TITLES: Dictionary = {
	"lemon": "Лимон",
	"cherry": "Вишня",
	"clover": "Клевер",
	"bell": "Колокол",
	"diamond": "Алмаз",
	"chest": "Сундук",
	"seven": "Семерка",
}

var combo_defs: Array[Dictionary] = [
	{
		"name": "Гор. M",
		"multiplier": 1.0,
		"points": [Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3)],
	},
	{
		"name": "Верт. M",
		"multiplier": 1.0,
		"points": [Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)],
	},
	{
		"name": "Диаг. M",
		"multiplier": 1.0,
		"points": [Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 3)],
	},
	{
		"name": "Гор. L",
		"multiplier": 2.0,
		"points": [Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3)],
	},
	{
		"name": "Гор. XL",
		"multiplier": 3.0,
		"points": [Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3), Vector2i(1, 4)],
	},
	{
		"name": "Вверх",
		"multiplier": 4.0,
		"points": [Vector2i(2, 0), Vector2i(1, 1), Vector2i(0, 2), Vector2i(1, 3), Vector2i(2, 4)],
	},
	{
		"name": "Вниз",
		"multiplier": 4.0,
		"points": [Vector2i(0, 0), Vector2i(1, 1), Vector2i(2, 2), Vector2i(1, 3), Vector2i(0, 4)],
	},
	{
		"name": "Небо",
		"multiplier": 7.0,
		"points": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3), Vector2i(0, 4)],
	},
	{
		"name": "Земля",
		"multiplier": 7.0,
		"points": [Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2), Vector2i(2, 3), Vector2i(2, 4)],
	},
	{
		"name": "Глаз",
		"multiplier": 8.0,
		"points": [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 2), Vector2i(0, 3), Vector2i(1, 4)],
	},
	{
		"name": "Джекпот",
		"multiplier": 10.0,
		"points": [
			Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3), Vector2i(0, 4),
			Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3), Vector2i(1, 4),
			Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2), Vector2i(2, 3), Vector2i(2, 4),
		],
	},
]

var reels_row: HBoxContainer
var btn: Button
var label: Label

var _reels: Array[Panel] = []
var _busy: bool = false
var input_locked: bool = false

var money: int = 0
var spins_left: int = 0
var tickets: int = 0

func _ready() -> void:
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
	_apply_symbol_chance_weights()
	_sync_reel_pools()
	_emit_hud_changed()
	_set_status("READY")

	if btn != null and not btn.pressed.is_connected(request_spin):
		btn.pressed.connect(request_spin)

func _collect_reels() -> void:
	_reels.clear()
	for child: Node in reels_row.get_children():
		var panel: Panel = child as Panel
		if panel != null and panel.has_method("start_spin"):
			_reels.append(panel)

func _gui_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or _busy or input_locked:
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
	if Engine.is_editor_hint() or _busy or input_locked:
		return
	if symbols.is_empty():
		_set_status("error: no symbols")
		return
	if _reels.is_empty():
		_set_status("no reels")
		return
	if spins_left < spins_per_round:
		_set_status("NO SPINS LEFT")
		_emit_hud_changed()
		return
	_spin()

func is_spinning() -> bool:
	return _busy

func set_input_locked(locked: bool) -> void:
	input_locked = locked

func _spin() -> void:
	_apply_symbol_chance_weights()
	_sync_reel_pools()
	_busy = true
	spins_left -= spins_per_round
	_emit_hud_changed()
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

	var board: Array = _collect_board_indices_from_reels()
	var result: Dictionary = _evaluate_board(board)
	var win_amount: int = int(result.get("win_amount", 0))
	if win_amount > 0:
		money += win_amount
		emit_signal("win_popup_requested", win_amount)

	_set_status(String(result.get("text", "DONE")))
	_emit_hud_changed()
	_busy = false
	emit_signal("spin_completed", win_amount)

func _collect_board_indices_from_reels() -> Array:
	var board: Array = [[], [], []]
	for row: int in range(3):
		board[row].resize(_reels.size())

	for col: int in range(_reels.size()):
		var reel: Panel = _reels[col]
		for row: int in range(3):
			var tex: Texture2D = _reel_texture_for_row(reel, row)
			board[row][col] = _index_for_texture(tex)
	return board

func _reel_texture_for_row(reel: Panel, row: int) -> Texture2D:
	if reel == null:
		return null

	if row == 1 and reel.has_method("get_middle_texture"):
		return reel.call("get_middle_texture") as Texture2D

	var margin: MarginContainer = reel.get_node_or_null("MarginContainer") as MarginContainer
	var box: VBoxContainer = reel.get_node_or_null("MarginContainer/VBoxContainer") as VBoxContainer
	if margin == null or box == null:
		if reel.has_method("get_middle_texture"):
			return reel.call("get_middle_texture") as Texture2D
		return null

	var factors: Array[float] = [1.0 / 6.0, 0.5, 5.0 / 6.0]
	var safe_row: int = clampi(row, 0, 2)
	var target_y: float = reel.size.y * factors[safe_row]

	var reel_icon_h: float = 170.0
	var icon_size_var: Variant = reel.get("icon_size")
	if icon_size_var is Vector2:
		reel_icon_h = (icon_size_var as Vector2).y

	var best_dist: float = INF
	var best_icon: TextureRect = null
	for child: Node in box.get_children():
		var icon: TextureRect = child as TextureRect
		if icon == null:
			continue

		var icon_h: float = reel_icon_h
		if icon_h <= 0.0:
			if icon.size.y > 0.0:
				icon_h = icon.size.y
			elif icon.custom_minimum_size.y > 0.0:
				icon_h = icon.custom_minimum_size.y
			else:
				icon_h = 170.0

		var top_y: float = margin.offset_top + box.position.y + icon.position.y
		var center_y: float = top_y + icon_h * 0.5
		var dist: float = absf(center_y - target_y)
		if dist < best_dist:
			best_dist = dist
			best_icon = icon

	if best_icon == null:
		if reel.has_method("get_middle_texture"):
			return reel.call("get_middle_texture") as Texture2D
		return null
	return best_icon.texture

func _evaluate_board(board: Array) -> Dictionary:
	var total_win: int = 0
	var hit_lines: Array[String] = []
	var best_symbol_idx: int = -1

	for combo: Dictionary in combo_defs:
		var points: Array = combo.get("points", [])
		if not _combo_points_fit(points, board):
			continue

		var first_point: Vector2i = points[0]
		var base_index: int = _board_at(board, first_point)
		if base_index < 0:
			continue

		var same_symbol: bool = true
		for p_var: Variant in points:
			var p: Vector2i = p_var
			if _board_at(board, p) != base_index:
				same_symbol = false
				break

		if not same_symbol:
			continue

		var combo_mult: float = float(combo.get("multiplier", 1.0))
		var symbol_value: int = _symbol_coin_value(base_index)
		var line_win: int = maxi(1, int(round(float(symbol_value) * combo_mult * symbol_multiplier)))
		total_win += line_win
		hit_lines.append("%s x%.1f" % [String(combo.get("name", "?")), combo_mult])
		best_symbol_idx = base_index

	if total_win <= 0:
		return {
			"text": "LOSE",
			"win_amount": 0,
		}

	var shown: Array[String] = []
	for i: int in range(mini(3, hit_lines.size())):
		shown.append(hit_lines[i])
	var summary: String = "; ".join(shown)
	if hit_lines.size() > 3:
		summary += " ..."

	return {
		"text": "WIN | %s | +%d | %s" % [_symbol_title(best_symbol_idx), total_win, summary],
		"win_amount": total_win,
	}

func _combo_points_fit(points: Array, board: Array) -> bool:
	if board.size() < 3:
		return false
	var cols: int = (board[0] as Array).size()
	for p_var: Variant in points:
		var p: Vector2i = p_var
		if p.y < 0 or p.y >= cols:
			return false
		if p.x < 0 or p.x >= 3:
			return false
	return true

func _board_at(board: Array, point: Vector2i) -> int:
	if point.x < 0 or point.x >= board.size():
		return -1
	var row: Array = board[point.x]
	if point.y < 0 or point.y >= row.size():
		return -1
	return int(row[point.y])

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

func _symbol_coin_value(index: int) -> int:
	var key: String = _symbol_key(index)
	return int(SYMBOL_VALUES.get(key, 1))

func _chance_for_index(index: int) -> float:
	var key: String = _symbol_key(index)
	return float(SYMBOL_CHANCES.get(key, 1.0))

func _symbol_title(index: int) -> String:
	var key: String = _symbol_key(index)
	return String(SYMBOL_TITLES.get(key, key))

func _symbol_key(index: int) -> String:
	if index < 0 or index >= symbols.size() or symbols[index] == null:
		return ""
	var raw_name: String = symbols[index].resource_path.get_file().get_basename().to_lower()
	if raw_name.contains("lemon"):
		return "lemon"
	if raw_name.contains("cherry"):
		return "cherry"
	if raw_name.contains("clover"):
		return "clover"
	if raw_name.contains("bell"):
		return "bell"
	if raw_name.contains("diamond"):
		return "diamond"
	if raw_name.contains("chest"):
		return "chest"
	if raw_name.contains("seven"):
		return "seven"
	return raw_name

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

func _apply_symbol_chance_weights() -> void:
	weights.resize(symbols.size())
	for i: int in range(symbols.size()):
		weights[i] = _chance_for_index(i)

func _sync_reel_pools() -> void:
	for reel: Panel in _reels:
		if reel.has_method("set_symbol_pool"):
			reel.call("set_symbol_pool", symbols, weights)

func _emit_hud_changed() -> void:
	emit_signal("hud_changed", money, spins_left, tickets)

func get_hud_state() -> Dictionary:
	return {
		"money": money,
		"spins_left": spins_left,
		"tickets": tickets,
	}

func get_money() -> int:
	return money

func get_spins_left() -> int:
	return spins_left

func get_tickets() -> int:
	return tickets

func set_spins_left(value: int) -> void:
	spins_left = maxi(value, 0)
	_emit_hud_changed()

func add_money(amount: int) -> void:
	money = maxi(money + amount, 0)
	_emit_hud_changed()

func spend_money(amount: int) -> bool:
	if amount <= 0:
		return true
	if money < amount:
		return false
	money -= amount
	_emit_hud_changed()
	return true

func add_tickets(amount: int) -> void:
	tickets = maxi(tickets + amount, 0)
	_emit_hud_changed()

func spend_tickets(amount: int) -> bool:
	if amount <= 0:
		return true
	if tickets < amount:
		return false
	tickets -= amount
	_emit_hud_changed()
	return true

func format_money(value: int) -> String:
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
