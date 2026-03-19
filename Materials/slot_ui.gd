@tool
extends Control

signal status_changed(text: String)
signal hud_changed(money: int, spins_left: int, tickets: int)
signal win_popup_requested(amount: int)
signal win_sequence_requested(result: Dictionary)
signal spin_completed(win_amount: int)
signal round_ended(round_number: int, interest_amount: int)

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

@export_group("Payout")
@export var bet_per_spin: int = 1
@export var allow_combo_stacking: bool = true
@export var jackpot_overrides_other_hits: bool = true

@export_group("Round / Interest")
@export var interest_percent: float = 7.0
@export var tickets_per_round_end: int = 1

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
	"lemon": 20.0,
	"cherry": 20.0,
	"clover": 15.0,
	"bell": 15.0,
	"diamond": 11.5,
	"chest": 11.5,
	"seven": 7.0,
}

const SYMBOL_TITLES: Dictionary = {
	"lemon": "Лимон",
	"cherry": "Вишня",
	"clover": "Клевер",
	"bell": "Колокольчик",
	"diamond": "Алмаз",
	"chest": "Сундук",
	"seven": "Семерки",
}

var _combo_rules: Array[Dictionary] = []

var reels_row: HBoxContainer
var btn: Button
var label: Label

var _reels: Array[Panel] = []
var _busy: bool = false
var input_locked: bool = false
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

var money: int = 0
var spins_left: int = 0
var tickets: int = 0
var deposited_money: int = 0
var round_number: int = 1

var _last_target_grid: Array = []
var _last_win_amount: int = 0
var _last_win_combo_id: String = ""
var _totem_bonuses: Dictionary = {}
var _highlight_overlay: Control
var _highlighted_icons: Array[TextureRect] = []
var _highlight_palette_index: int = 0
var _highlight_pulse_t: float = 0.0
var _highlight_palettes: Array[Array] = [
	[Color(0.28, 1.0, 0.34, 1.0), Color(1.0, 0.95, 0.26, 1.0)],
	[Color(0.24, 0.94, 1.0, 1.0), Color(0.26, 1.0, 0.76, 1.0)],
	[Color(1.0, 0.34, 0.72, 1.0), Color(0.58, 0.92, 1.0, 1.0)],
	[Color(1.0, 0.72, 0.14, 1.0), Color(1.0, 0.35, 0.16, 1.0)],
]

const SLOT_HIGHLIGHT_OVERLAY_SCRIPT: Script = preload("res://Materials/slot_highlight_overlay.gd")
const HIT_FRAME_NAME: StringName = &"HitFrame"
const HIT_FRAME_PATH: NodePath = ^"HitFrame"
const HIGHLIGHT_PULSE_SPEED: float = 3.6

func _ready() -> void:
	reels_row = get_node_or_null(reels_row_path) as HBoxContainer
	btn = get_node_or_null(button_path) as Button
	label = get_node_or_null(label_path) as Label

	if reels_row == null:
		push_error("reels_row is null: set reels_row_path in Inspector")
		return

	_rng.randomize()
	if not is_in_group("slot_ui_highlight_target"):
		add_to_group("slot_ui_highlight_target")
	money = starting_money
	spins_left = starting_spins
	tickets = starting_tickets
	deposited_money = 0
	round_number = 1

	_collect_reels()
	_configure_slot_layout()
	_hide_legacy_ui()
	_apply_symbol_chance_weights()
	_sync_reel_pools()
	_combo_rules = _build_combo_rules()
	_emit_hud_changed()
	_set_status("READY")

	if btn != null and not btn.pressed.is_connected(request_spin):
		btn.pressed.connect(request_spin)

func _process(delta: float) -> void:
	if _highlighted_icons.is_empty():
		return
	_highlight_pulse_t += delta
	_refresh_icon_highlights()

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
		_set_status("ERROR: NO SYMBOLS")
		return
	if _reels.is_empty():
		_set_status("NO REELS")
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

func set_choice_overlay_active(active: bool) -> void:
	var show_reels: bool = not active
	if reels_row != null:
		reels_row.visible = show_reels

	var frame: CanvasItem = get_node_or_null("SlotFrame") as CanvasItem
	if frame != null:
		frame.visible = show_reels

	var separators: CanvasItem = get_node_or_null("Separators") as CanvasItem
	if separators != null:
		separators.visible = show_reels

func deposit_money(amount: int) -> bool:
	if amount <= 0:
		return false
	if money < amount:
		return false
	money -= amount
	deposited_money += amount
	_emit_hud_changed()
	_set_status("DEPOSITED %d | TOTAL %d" % [amount, deposited_money])
	return true

func apply_round_interest() -> int:
	if deposited_money <= 0:
		return 0
	var interest: int = int(floor(float(deposited_money) * interest_percent / 100.0))
	if interest > 0:
		money += interest
	return interest

func end_round() -> void:
	var interest: int = apply_round_interest()
	if tickets_per_round_end > 0:
		tickets += tickets_per_round_end
	round_number += 1
	_emit_hud_changed()
	_set_status("ROUND END | +%d%% = +%d" % [int(interest_percent), interest])
	emit_signal("round_ended", round_number, interest)

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
	_last_target_grid = board.duplicate(true)

	var result: Dictionary = _evaluate_board(board)
	var win_amount: int = int(result.get("win_amount", 0))
	_last_win_amount = win_amount
	_last_win_combo_id = String(result.get("combo_id", ""))

	if win_amount > 0:
		money += win_amount
		emit_signal("win_sequence_requested", result.duplicate(true))

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

func _generate_board_indices(rows: int, cols: int) -> Array:
	var generated: Array = []
	for row: int in range(rows):
		var line: Array = []
		for _col: int in range(cols):
			line.append(_roll_symbol_index())
		generated.append(line)
	return generated

func _roll_symbol_index() -> int:
	if symbols.is_empty():
		return -1

	if weights.size() != symbols.size():
		_apply_symbol_chance_weights()

	var total: float = 0.0
	for w_var: Variant in weights:
		total += maxf(float(w_var), 0.0)

	if total <= 0.0:
		return _rng.randi_range(0, symbols.size() - 1)

	var pick: float = _rng.randf() * total
	var acc: float = 0.0
	for i: int in range(weights.size()):
		acc += maxf(float(weights[i]), 0.0)
		if pick <= acc:
			return i

	return max(symbols.size() - 1, 0)

func _texture_for_index(index: int) -> Texture2D:
	if index < 0 or index >= symbols.size():
		return null
	return symbols[index]

func _reel_texture_for_row(reel: Panel, row: int) -> Texture2D:
	var best_icon: TextureRect = _reel_icon_for_row(reel, row)
	if best_icon != null:
		return _visible_texture_for_icon(best_icon)
	if row == 1 and reel != null and reel.has_method("get_middle_texture"):
		return reel.call("get_middle_texture") as Texture2D
	return null

func _reel_icon_for_row(reel: Panel, row: int) -> TextureRect:
	if reel == null:
		return null

	var box: VBoxContainer = reel.get_node_or_null("MarginContainer/VBoxContainer") as VBoxContainer
	var margin_node: MarginContainer = reel.get_node_or_null("MarginContainer") as MarginContainer
	if box == null or margin_node == null:
		return null

	var safe_row: int = clampi(row, 0, 2)
	var target_y: float = _target_center_y_for_row(box, margin_node, safe_row)
	var best_dist: float = INF
	var best_icon: TextureRect = null

	for child: Node in box.get_children():
		var icon: TextureRect = child as TextureRect
		var visible_tex: Texture2D = _visible_texture_for_icon(icon)
		if icon == null or visible_tex == null:
			continue

		var top_y: float = margin_node.offset_top + box.position.y + icon.position.y
		var center_y: float = top_y + (_icon_height(icon) * 0.5)
		var dist: float = absf(center_y - target_y)
		if dist < best_dist:
			best_dist = dist
			best_icon = icon

	return best_icon

func _visible_texture_for_icon(icon: TextureRect) -> Texture2D:
	if icon == null:
		return null
	var next_icon: TextureRect = icon.get_node_or_null("Next") as TextureRect
	if next_icon != null and next_icon.texture != null and next_icon.modulate.a > 0.45:
		return next_icon.texture
	return icon.texture

func _icon_height(icon: TextureRect) -> float:
	if icon == null:
		return 0.0
	if icon.size.y > 0.0:
		return icon.size.y
	if icon.custom_minimum_size.y > 0.0:
		return icon.custom_minimum_size.y
	return 170.0

func _target_center_y_for_row(box: VBoxContainer, margin_node: MarginContainer, row: int) -> float:
	var first_icon: TextureRect = null
	for child: Node in box.get_children():
		first_icon = child as TextureRect
		if first_icon != null:
			break
	var icon_height: float = _icon_height(first_icon)
	var separation: float = float(box.get_theme_constant("separation"))
	return margin_node.offset_top + (icon_height * 0.5) + float(row) * (icon_height + separation)

func _evaluate_board(board: Array) -> Dictionary:
	if not _board_is_3x5(board):
		return {"text": "ERR BOARD", "win_amount": 0, "combo_id": ""}

	if _combo_rules.is_empty():
		_combo_rules = _build_combo_rules()

	var bet: int = maxi(bet_per_spin, 1)
	var hits: Array[Dictionary] = []
	var jackpot_hit: Dictionary = {}

	for combo: Dictionary in _combo_rules:
		var variants: Array = combo.get("variants", [])
		var combo_mult: int = int(combo.get("multiplier", 1))
		var combo_name: String = String(combo.get("name", "Комбо"))
		var combo_id: String = String(combo.get("id", combo_name))

		for variant_var: Variant in variants:
			var points: Array = variant_var as Array
			if points.is_empty():
				continue
			if not _combo_points_fit(points, board):
				continue

			var symbol_index: int = _uniform_symbol_index(board, points)
			if symbol_index < 0:
				continue

			var symbol_value: int = _symbol_coin_value(symbol_index)
			var win_amount: int = bet * symbol_value * combo_mult

			var hit: Dictionary = {
				"combo_id": combo_id,
				"combo_name": combo_name,
				"combo_multiplier": combo_mult,
				"symbol_index": symbol_index,
				"symbol_value": symbol_value,
				"win_amount": win_amount,
				"points": points,
			}

			if combo_id == "jackpot":
				jackpot_hit = hit
				break

			hits.append(hit)
			if not allow_combo_stacking:
				break

		if combo_id == "jackpot" and not jackpot_hit.is_empty():
			break
		if not allow_combo_stacking and not hits.is_empty():
			break

	if not jackpot_hit.is_empty() and jackpot_overrides_other_hits:
		var jackpot_total: int = int(jackpot_hit.get("win_amount", 0))
		var jackpot_bonus: int = _total_flat_win_bonus()
		if jackpot_total > 0 and jackpot_bonus > 0:
			jackpot_total += jackpot_bonus
		return {
			"text": "WIN | Джекпот x10 | %s Ф=%d | BET %d | +%d" % [
				_symbol_title(int(jackpot_hit.get("symbol_index", -1))),
				int(jackpot_hit.get("symbol_value", 0)),
				bet,
				jackpot_total,
			],
			"win_amount": jackpot_total,
			"combo_id": "jackpot",
			"hits": [jackpot_hit],
		}

	if not jackpot_hit.is_empty() and allow_combo_stacking:
		hits.append(jackpot_hit)

	if hits.is_empty():
		return {"text": "LOSE", "win_amount": 0, "combo_id": ""}

	var total: int = 0
	var best_hit: Dictionary = hits[0]
	var parts: Array[String] = []
	for hit_var: Variant in hits:
		var hit: Dictionary = hit_var as Dictionary
		total += int(hit.get("win_amount", 0))
		parts.append("%s x%d (%s Ф=%d) +%d" % [
			String(hit.get("combo_name", "")),
			int(hit.get("combo_multiplier", 1)),
			_symbol_title(int(hit.get("symbol_index", -1))),
			int(hit.get("symbol_value", 0)),
			int(hit.get("win_amount", 0)),
		])
		if int(hit.get("combo_multiplier", 0)) > int(best_hit.get("combo_multiplier", 0)):
			best_hit = hit
		elif int(hit.get("combo_multiplier", 0)) == int(best_hit.get("combo_multiplier", 0)) and int(hit.get("symbol_value", 0)) > int(best_hit.get("symbol_value", 0)):
			best_hit = hit

	var totem_bonus: int = _total_flat_win_bonus()
	if total > 0 and totem_bonus > 0:
		total += totem_bonus
		parts.append("Тотем +%d" % totem_bonus)

	return {
		"text": "WIN | TOTAL +%d | %s" % [total, " + ".join(parts)],
		"win_amount": total,
		"combo_id": String(best_hit.get("combo_id", "")),
		"hits": hits,
	}

func _uniform_symbol_index(board: Array, points: Array) -> int:
	if points.is_empty():
		return -1

	var first_point: Vector2i = points[0]
	var base_index: int = _board_at(board, first_point)
	if base_index < 0:
		return -1

	for p_var: Variant in points:
		var p: Vector2i = p_var
		if _board_at(board, p) != base_index:
			return -1

	return base_index

func _board_is_3x5(board: Array) -> bool:
	if board.size() != 3:
		return false
	for row_var: Variant in board:
		var row: Array = row_var as Array
		if row.size() != 5:
			return false
	return true

func _build_combo_rules() -> Array[Dictionary]:
	var rules: Array[Dictionary] = []

	var jackpot_points: Array[Vector2i] = []
	for row: int in range(3):
		for col: int in range(5):
			jackpot_points.append(Vector2i(row, col))
	rules.append({"id": "jackpot", "name": "Джекпот", "multiplier": 10, "variants": [jackpot_points]})

	rules.append({
		"id": "eye",
		"name": "Глаз",
		"multiplier": 8,
		"variants": [[
			Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3),
			Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 3), Vector2i(1, 4),
			Vector2i(2, 1), Vector2i(2, 2), Vector2i(2, 3),
		]],
	})

	rules.append({
		"id": "sky",
		"name": "Небо",
		"multiplier": 7,
		"variants": [[
			Vector2i(0, 2),
			Vector2i(1, 1), Vector2i(1, 3),
			Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2), Vector2i(2, 3), Vector2i(2, 4),
		]],
	})

	rules.append({
		"id": "earth",
		"name": "Земля",
		"multiplier": 7,
		"variants": [[
			Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3), Vector2i(0, 4),
			Vector2i(1, 1), Vector2i(1, 3),
			Vector2i(2, 2),
		]],
	})

	rules.append({
		"id": "up",
		"name": "Вверх",
		"multiplier": 4,
		"variants": [[
			Vector2i(0, 2),
			Vector2i(1, 1), Vector2i(1, 3),
			Vector2i(2, 0), Vector2i(2, 4),
		]],
	})

	rules.append({
		"id": "down",
		"name": "Вниз",
		"multiplier": 4,
		"variants": [[
			Vector2i(0, 0), Vector2i(0, 4),
			Vector2i(1, 1), Vector2i(1, 3),
			Vector2i(2, 2),
		]],
	})

	var horizontal_xl_variants: Array = []
	for row_xl: int in range(3):
		horizontal_xl_variants.append([
			Vector2i(row_xl, 0), Vector2i(row_xl, 1), Vector2i(row_xl, 2), Vector2i(row_xl, 3), Vector2i(row_xl, 4),
		])
	rules.append({"id": "horizontal_xl", "name": "Гор. XL", "multiplier": 3, "variants": horizontal_xl_variants})

	var horizontal_l_variants: Array = []
	for row_l: int in range(3):
		for start_col_l: int in range(2):
			horizontal_l_variants.append([
				Vector2i(row_l, start_col_l), Vector2i(row_l, start_col_l + 1), Vector2i(row_l, start_col_l + 2), Vector2i(row_l, start_col_l + 3),
			])
	rules.append({"id": "horizontal_l", "name": "Гор. L", "multiplier": 2, "variants": horizontal_l_variants})

	var horizontal_m_variants: Array = []
	for row_m: int in range(3):
		for start_col_m: int in range(3):
			horizontal_m_variants.append([
				Vector2i(row_m, start_col_m), Vector2i(row_m, start_col_m + 1), Vector2i(row_m, start_col_m + 2),
			])
	rules.append({"id": "horizontal", "name": "Гор.", "multiplier": 1, "variants": horizontal_m_variants})

	var vertical_variants: Array = []
	for col_v: int in range(5):
		vertical_variants.append([
			Vector2i(0, col_v), Vector2i(1, col_v), Vector2i(2, col_v),
		])
	rules.append({"id": "vertical", "name": "Верт.", "multiplier": 1, "variants": vertical_variants})

	var diag_variants: Array = []
	for start_col: int in range(3):
		diag_variants.append([
			Vector2i(0, start_col), Vector2i(1, start_col + 1), Vector2i(2, start_col + 2),
		])
		diag_variants.append([
			Vector2i(2, start_col), Vector2i(1, start_col + 1), Vector2i(0, start_col + 2),
		])
	rules.append({
		"id": "diag",
		"name": "Диаг.",
		"multiplier": 1,
		"variants": diag_variants,
	})

	return rules

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
		"deposited_money": deposited_money,
		"round_number": round_number,
		"interest_percent": interest_percent,
	}

func get_money() -> int:
	return money

func get_spins_left() -> int:
	return spins_left

func get_tickets() -> int:
	return tickets

func get_deposited_money() -> int:
	return deposited_money

func get_round_number() -> int:
	return round_number

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

func add_totem_bonus(totem_id: String, bonus_type: String, bonus_value: int) -> void:
	if totem_id.is_empty():
		return
	_totem_bonuses[totem_id] = {
		"type": bonus_type,
		"value": bonus_value,
	}

func has_totem_bonus(totem_id: String) -> bool:
	return _totem_bonuses.has(totem_id)

func _total_flat_win_bonus() -> int:
	var total: int = 0
	for bonus_var: Variant in _totem_bonuses.values():
		var bonus: Dictionary = bonus_var as Dictionary
		if String(bonus.get("type", "")) == "flat_win_bonus":
			total += int(bonus.get("value", 0))
	return total

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
	_ensure_highlight_overlay(reels_pos, reels_size)

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

func _ensure_highlight_overlay(reels_pos: Vector2, reels_size: Vector2) -> void:
	if _highlight_overlay == null:
		_highlight_overlay = get_node_or_null("HighlightOverlay") as Control
	if _highlight_overlay == null:
		_highlight_overlay = SLOT_HIGHLIGHT_OVERLAY_SCRIPT.new() as Control
		_highlight_overlay.name = "HighlightOverlay"
		add_child(_highlight_overlay)
	_highlight_overlay.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_highlight_overlay.position = reels_pos
	_highlight_overlay.size = reels_size
	_highlight_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_highlight_overlay.clip_contents = false
	_highlight_overlay.z_index = 80
	move_child(_highlight_overlay, get_child_count() - 1)

func show_combo_highlight(points: Array, palette_index: int = 0) -> void:
	clear_combo_highlight()
	_highlight_palette_index = posmod(palette_index, _highlight_palettes.size())
	_highlight_pulse_t = 0.0
	if _highlight_overlay == null:
		_ensure_highlight_overlay(reels_row.position, reels_row.size)

	var rects: Array[Rect2] = []
	for point_var: Variant in points:
		var point: Vector2i = point_var
		if point.y < 0 or point.y >= _reels.size():
			continue
		var icon: TextureRect = _reel_icon_for_row(_reels[point.y], point.x)
		if icon == null:
			continue
		var frame: Control = _ensure_icon_highlight_frame(icon)
		if frame != null:
			frame.visible = true
			if not _highlighted_icons.has(icon):
				_highlighted_icons.append(icon)
		var rect: Rect2 = _highlight_rect_for_icon(icon)
		if rect.size.x > 8.0 and rect.size.y > 8.0:
			rects.append(rect)

	_refresh_icon_highlights()
	if _highlight_overlay != null and _highlight_overlay.has_method("set_highlights"):
		_highlight_overlay.call("set_highlights", rects, palette_index)

func clear_combo_highlight() -> void:
	for icon: TextureRect in _highlighted_icons:
		if icon == null:
			continue
		icon.self_modulate = Color(1.0, 1.0, 1.0, 1.0)
		var frame: Control = icon.get_node_or_null(HIT_FRAME_PATH) as Control
		if frame != null:
			frame.visible = false
	_highlighted_icons.clear()
	if _highlight_overlay != null and _highlight_overlay.has_method("clear_highlights"):
		_highlight_overlay.call("clear_highlights")

func _highlight_rect_for_icon(icon: TextureRect) -> Rect2:
	if icon == null or _highlight_overlay == null:
		return Rect2()
	var icon_rect: Rect2 = icon.get_global_rect()
	var overlay_rect: Rect2 = _highlight_overlay.get_global_rect()
	var local_pos: Vector2 = icon_rect.position - overlay_rect.position
	var inset: Vector2 = Vector2(9.0, 9.0)
	var size: Vector2 = icon_rect.size - inset * 2.0
	if size.x <= 0.0 or size.y <= 0.0:
		return Rect2(local_pos, icon_rect.size)
	return Rect2(local_pos + inset, size)

func _ensure_icon_highlight_frame(icon: TextureRect) -> Control:
	if icon == null:
		return null
	var frame: Control = icon.get_node_or_null(HIT_FRAME_PATH) as Control
	if frame == null:
		frame = Control.new()
		frame.name = String(HIT_FRAME_NAME)
		icon.add_child(frame)
		frame.set_anchors_preset(Control.PRESET_FULL_RECT)
		frame.offset_left = 6.0
		frame.offset_top = 6.0
		frame.offset_right = -6.0
		frame.offset_bottom = -6.0
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.z_index = 40
		frame.visible = false
		frame.clip_contents = false

		var fill_rect: ColorRect = ColorRect.new()
		fill_rect.name = "Fill"
		fill_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		fill_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(fill_rect)

		for edge_name: String in ["Top", "Bottom", "Left", "Right", "Shine"]:
			var edge_rect: ColorRect = ColorRect.new()
			edge_rect.name = edge_name
			edge_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			frame.add_child(edge_rect)
	return frame

func _refresh_icon_highlights() -> void:
	if _highlighted_icons.is_empty():
		return
	var palette: Array = _highlight_palettes[_highlight_palette_index]
	var c0: Color = palette[0]
	var c1: Color = palette[1]
	var t: float = 0.5 + 0.5 * sin(_highlight_pulse_t * HIGHLIGHT_PULSE_SPEED)
	var edge: Color = c0.lerp(c1, t)
	var fill: Color = Color(0.42, 0.02, 0.04, 0.52)
	var shine: Color = Color(1.0, 1.0, 0.72, 0.32 + 0.10 * t)

	for icon: TextureRect in _highlighted_icons:
		if icon == null:
			continue
		var frame: Control = _ensure_icon_highlight_frame(icon)
		if frame == null:
			continue

		var fill_rect: ColorRect = frame.get_node_or_null(^"Fill") as ColorRect
		var top_rect: ColorRect = frame.get_node_or_null(^"Top") as ColorRect
		var bottom_rect: ColorRect = frame.get_node_or_null(^"Bottom") as ColorRect
		var left_rect: ColorRect = frame.get_node_or_null(^"Left") as ColorRect
		var right_rect: ColorRect = frame.get_node_or_null(^"Right") as ColorRect
		var shine_rect: ColorRect = frame.get_node_or_null(^"Shine") as ColorRect

		var border_px: float = 8.0
		var shine_px: float = 2.0
		var w: float = maxf(frame.size.x, 0.0)
		var h: float = maxf(frame.size.y, 0.0)

		if fill_rect != null:
			fill_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
			fill_rect.color = fill
		if top_rect != null:
			top_rect.position = Vector2.ZERO
			top_rect.size = Vector2(w, border_px)
			top_rect.color = edge
		if bottom_rect != null:
			bottom_rect.position = Vector2(0.0, h - border_px)
			bottom_rect.size = Vector2(w, border_px)
			bottom_rect.color = edge
		if left_rect != null:
			left_rect.position = Vector2.ZERO
			left_rect.size = Vector2(border_px, h)
			left_rect.color = edge
		if right_rect != null:
			right_rect.position = Vector2(w - border_px, 0.0)
			right_rect.size = Vector2(border_px, h)
			right_rect.color = edge
		if shine_rect != null:
			shine_rect.position = Vector2(border_px + 3.0, border_px + 3.0)
			shine_rect.size = Vector2(maxf(w - (border_px + 3.0) * 2.0, 0.0), shine_px)
			shine_rect.color = shine

		frame.self_modulate = Color(1.0, 1.0, 1.0, 1.0)
		icon.self_modulate = Color(1.18, 1.14, 1.04, 1.0)

func _rect_for_board_point(point: Vector2i) -> Rect2:
	if point.y < 0 or point.y >= _reels.size():
		return Rect2()
	if point.x < 0 or point.x >= 3:
		return Rect2()
	var reel: Panel = _reels[point.y]
	if reel == null:
		return Rect2()
	var margin_node: MarginContainer = reel.get_node_or_null("MarginContainer") as MarginContainer
	var box: VBoxContainer = reel.get_node_or_null("MarginContainer/VBoxContainer") as VBoxContainer
	if margin_node == null or box == null:
		return Rect2()
	var first_icon: TextureRect = null
	for child: Node in box.get_children():
		first_icon = child as TextureRect
		if first_icon != null:
			break
	var icon_width: float = first_icon.size.x if first_icon != null and first_icon.size.x > 0.0 else first_icon.custom_minimum_size.x if first_icon != null and first_icon.custom_minimum_size.x > 0.0 else 250.0
	var icon_height: float = first_icon.size.y if first_icon != null and first_icon.size.y > 0.0 else first_icon.custom_minimum_size.y if first_icon != null and first_icon.custom_minimum_size.y > 0.0 else 170.0
	var separation: float = float(box.get_theme_constant("separation"))
	var x: float = reel.position.x + margin_node.offset_left - 6.0
	var y: float = margin_node.offset_top + float(point.x) * (icon_height + separation) - 6.0
	return Rect2(Vector2(x, y), Vector2(icon_width + 12.0, icon_height + 12.0))

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
