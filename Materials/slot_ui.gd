@tool
extends Control

signal status_changed(text: String)

@export var symbols: Array[Texture2D] = []
@export var weights: Array[float] = []

@export var reels_row_path: NodePath
@export var button_path: NodePath
@export var label_path: NodePath

@export_group("Economy")
@export var starting_bankroll: int = 3000
@export var spin_fee: int = 20
@export var min_bet: int = 50
@export var max_bet: int = 600
@export var bet_step: int = 50

const SAVE_PATH: String = "user://slot_progress.json"
const HISTORY_LIMIT: int = 10
const UPGRADE_MAX_LEVEL: Dictionary = {
	"luck": 8,
	"booster": 8,
	"shield": 6,
	"unlock": 3,
}
const UPGRADE_BASE_COST: Dictionary = {
	"luck": 500,
	"booster": 650,
	"shield": 550,
	"unlock": 1200,
}

var reels_row: HBoxContainer
var btn: Button
var label: Label

var _reels: Array[Panel] = []
var _sectors: Array[Dictionary] = []
var _busy: bool = false
var _last_status: String = "Готово"
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

var bankroll: int = 0
var current_bet: int = 0
var best_win: int = 0
var max_balance: int = 0
var daily_streak: int = 0
var last_daily_day: int = -1
var mission_tier: int = 1

var upgrades: Dictionary = {
	"luck": 0,
	"booster": 0,
	"shield": 0,
	"unlock": 0,
}
var stats: Dictionary = {
	"total_spins": 0,
	"wins": 0,
	"jackpots": 0,
}
var mission_claimed: Dictionary = {}
var history: Array[String] = []

var panel_meta: Panel
var lbl_balance: Label
var lbl_records: Label
var lbl_bet: Label
var lbl_status: Label
var lbl_history_title: Label
var txt_history: RichTextLabel
var lbl_payout_title: Label
var txt_payout: RichTextLabel
var lbl_mission: Label
var lbl_shop_title: Label

var btn_spin: Button
var btn_plus: Button
var btn_minus: Button
var btn_daily: Button
var btn_mission_claim: Button
var shop_buttons: Dictionary = {}

func _ready() -> void:
	_rng.randomize()
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
	_init_sectors()
	_load_progress()
	_sync_reel_pools()
	_ensure_runtime_ui()
	_refresh_all()

	if btn != null and not btn.pressed.is_connected(request_spin):
		btn.pressed.connect(request_spin)

func _collect_reels() -> void:
	_reels.clear()
	for child: Node in reels_row.get_children():
		var panel: Panel = child as Panel
		if panel != null and panel.has_method("start_spin") and panel.has_method("stop_with_result"):
			_reels.append(panel)

func request_spin() -> void:
	if Engine.is_editor_hint() or _busy:
		return
	if symbols.is_empty() or _reels.is_empty():
		_set_status("Нет символов или барабанов")
		return
	if not _can_afford_spin():
		_set_status("Недостаточно средств для ставки")
		_refresh_ui_state()
		return
	_spin()

func is_spinning() -> bool:
	return _busy

func _spin() -> void:
	_normalize_weights()
	_sync_reel_pools()
	_busy = true
	_refresh_ui_state()

	var before_balance: int = bankroll
	var total_cost: int = spin_fee + current_bet
	bankroll = maxi(bankroll - total_cost, 0)

	var sector: Dictionary = _roll_sector()
	var sector_name: String = String(sector.get("name", "?"))
	_set_status("Крутим: %s" % sector_name)

	for reel: Panel in _reels:
		reel.start_spin()

	await get_tree().create_timer(0.8).timeout

	var mid_texture: Texture2D = _texture_for_sector(sector)
	for reel: Panel in _reels:
		var top_texture: Texture2D = _random_symbol_texture()
		var bot_texture: Texture2D = _random_symbol_texture()
		reel.call("stop_with_result", top_texture, mid_texture, bot_texture)
		if reel.has_signal("stopped"):
			await reel.stopped
		else:
			await get_tree().create_timer(0.25).timeout
		await get_tree().create_timer(0.06).timeout

	var payout_mult: float = _effective_multiplier(sector)
	var payout: int = int(round(float(current_bet) * payout_mult))
	if payout > 0:
		bankroll += payout

	var penalty_mult: float = _effective_penalty(sector)
	var penalty: int = int(round(float(current_bet) * penalty_mult))
	if penalty > 0:
		bankroll = maxi(bankroll - penalty, 0)

	var net: int = bankroll - before_balance
	_update_stats_after_spin(net, sector)
	_push_history(_spin_history_text(sector, payout, penalty, total_cost, net))
	_set_status(_spin_status_text(sector, payout, penalty, net))

	if bankroll > max_balance:
		max_balance = bankroll

	_save_progress()
	_busy = false
	_refresh_all()

func _set_status(text: String) -> void:
	_last_status = text
	emit_signal("status_changed", text)
	if lbl_status != null:
		lbl_status.text = text

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
	var runtime_weights: Array[float] = _runtime_symbol_weights()
	for reel: Panel in _reels:
		if reel.has_method("set_symbol_pool"):
			reel.call("set_symbol_pool", symbols, runtime_weights)

func _runtime_symbol_weights() -> Array[float]:
	var out: Array[float] = []
	out.resize(symbols.size())
	for i: int in range(out.size()):
		out[i] = 0.01

	if _sectors.is_empty():
		for i: int in range(mini(weights.size(), out.size())):
			out[i] = maxf(weights[i], 0.01)
		return out

	for sector: Dictionary in _active_sectors():
		var idx: int = int(sector.get("symbol_index", -1))
		if idx >= 0 and idx < out.size():
			out[idx] += _sector_weight(sector)

	return out

func _configure_slot_layout() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	_ensure_backdrop()

	var reel_count: int = maxi(_reels.size(), 5)
	var reel_size: Vector2 = Vector2(300.0, 540.0)
	var gap: float = 16.0
	var reels_size: Vector2 = Vector2(float(reel_count) * reel_size.x + float(reel_count - 1) * gap, reel_size.y)
	var reels_pos: Vector2 = Vector2(18.0, 84.0)

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

func _meta_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.07, 0.07, 0.94)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(1.0, 0.55, 0.1, 0.7)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	return style

func _ensure_runtime_ui() -> void:
	panel_meta = get_node_or_null("MetaPanel") as Panel
	if panel_meta == null:
		panel_meta = Panel.new()
		panel_meta.name = "MetaPanel"
		add_child(panel_meta)

	panel_meta.position = Vector2(1610.0, 20.0)
	panel_meta.size = Vector2(370.0, 680.0)
	panel_meta.mouse_filter = Control.MOUSE_FILTER_STOP
	panel_meta.add_theme_stylebox_override("panel", _meta_style())

	lbl_balance = _ensure_label(panel_meta, "Balance", Rect2(16.0, 14.0, 338.0, 28.0), 24)
	lbl_records = _ensure_label(panel_meta, "Records", Rect2(16.0, 42.0, 338.0, 20.0), 14)

	btn_minus = _ensure_button(panel_meta, "BetMinus", Rect2(16.0, 72.0, 52.0, 34.0), "-")
	lbl_bet = _ensure_label(panel_meta, "Bet", Rect2(76.0, 72.0, 196.0, 34.0), 19)
	btn_plus = _ensure_button(panel_meta, "BetPlus", Rect2(280.0, 72.0, 74.0, 34.0), "+")

	btn_spin = _ensure_button(panel_meta, "Spin", Rect2(16.0, 112.0, 338.0, 40.0), "SPIN")
	btn_daily = _ensure_button(panel_meta, "Daily", Rect2(16.0, 156.0, 338.0, 32.0), "Ежедневный бонус")
	lbl_status = _ensure_label(panel_meta, "Status", Rect2(16.0, 192.0, 338.0, 30.0), 15)
	lbl_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	lbl_history_title = _ensure_label(panel_meta, "HistoryTitle", Rect2(16.0, 226.0, 338.0, 18.0), 13)
	lbl_history_title.text = "История"
	txt_history = _ensure_rich_text(panel_meta, "History", Rect2(16.0, 244.0, 338.0, 96.0))

	lbl_payout_title = _ensure_label(panel_meta, "PayoutTitle", Rect2(16.0, 344.0, 338.0, 18.0), 13)
	lbl_payout_title.text = "Таблица выплат"
	txt_payout = _ensure_rich_text(panel_meta, "Payout", Rect2(16.0, 362.0, 338.0, 78.0))

	lbl_mission = _ensure_label(panel_meta, "Mission", Rect2(16.0, 446.0, 338.0, 36.0), 13)
	lbl_mission.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	btn_mission_claim = _ensure_button(panel_meta, "MissionClaim", Rect2(16.0, 484.0, 338.0, 34.0), "Забрать награду")

	lbl_shop_title = _ensure_label(panel_meta, "ShopTitle", Rect2(16.0, 524.0, 338.0, 18.0), 13)
	lbl_shop_title.text = "Магазин апгрейдов"
	shop_buttons["luck"] = _ensure_button(panel_meta, "ShopLuck", Rect2(16.0, 544.0, 338.0, 26.0), "")
	shop_buttons["booster"] = _ensure_button(panel_meta, "ShopBoost", Rect2(16.0, 574.0, 338.0, 26.0), "")
	shop_buttons["shield"] = _ensure_button(panel_meta, "ShopShield", Rect2(16.0, 604.0, 338.0, 26.0), "")
	shop_buttons["unlock"] = _ensure_button(panel_meta, "ShopUnlock", Rect2(16.0, 634.0, 338.0, 26.0), "")

	_connect_once(btn_minus, _on_bet_minus)
	_connect_once(btn_plus, _on_bet_plus)
	_connect_once(btn_spin, request_spin)
	_connect_once(btn_daily, _on_daily_pressed)
	_connect_once(btn_mission_claim, _on_claim_mission_pressed)
	_connect_once(shop_buttons["luck"] as Button, _on_buy_luck)
	_connect_once(shop_buttons["booster"] as Button, _on_buy_booster)
	_connect_once(shop_buttons["shield"] as Button, _on_buy_shield)
	_connect_once(shop_buttons["unlock"] as Button, _on_buy_unlock)

	move_child(panel_meta, get_child_count() - 1)

func _ensure_label(parent: Control, name: String, rect: Rect2, font_size: int) -> Label:
	var node: Label = parent.get_node_or_null(name) as Label
	if node == null:
		node = Label.new()
		node.name = name
		parent.add_child(node)
	node.position = rect.position
	node.size = rect.size
	node.add_theme_font_size_override("font_size", font_size)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

func _ensure_button(parent: Control, name: String, rect: Rect2, text: String) -> Button:
	var node: Button = parent.get_node_or_null(name) as Button
	if node == null:
		node = Button.new()
		node.name = name
		parent.add_child(node)
	node.position = rect.position
	node.size = rect.size
	node.text = text
	node.focus_mode = Control.FOCUS_NONE
	node.mouse_filter = Control.MOUSE_FILTER_STOP
	node.add_theme_font_size_override("font_size", 15)
	return node

func _ensure_rich_text(parent: Control, name: String, rect: Rect2) -> RichTextLabel:
	var node: RichTextLabel = parent.get_node_or_null(name) as RichTextLabel
	if node == null:
		node = RichTextLabel.new()
		node.name = name
		parent.add_child(node)
	node.position = rect.position
	node.size = rect.size
	node.scroll_active = false
	node.selection_enabled = false
	node.fit_content = false
	node.bbcode_enabled = false
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.add_theme_font_size_override("normal_font_size", 12)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

func _connect_once(button: Button, callback: Callable) -> void:
	if button == null:
		return
	if not button.pressed.is_connected(callback):
		button.pressed.connect(callback)

func _refresh_all() -> void:
	_refresh_ui_state()
	_refresh_history()
	_refresh_payout_table()
	_refresh_mission_ui()
	_refresh_shop_ui()
	_refresh_daily_ui()

func _refresh_ui_state() -> void:
	if lbl_balance != null:
		lbl_balance.text = "Баланс: %d" % bankroll
	if lbl_records != null:
		lbl_records.text = "Рекорд банка: %d | Лучший плюс: +%d" % [max_balance, best_win]
	if lbl_bet != null:
		lbl_bet.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_bet.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl_bet.text = "Ставка %d" % current_bet
	if lbl_status != null:
		lbl_status.text = _last_status
	if btn_spin != null:
		btn_spin.text = "SPIN  (%d + fee %d)" % [current_bet, spin_fee]
		btn_spin.disabled = _busy or not _can_afford_spin()
	if btn_plus != null:
		btn_plus.disabled = _busy or current_bet >= _dynamic_max_bet()
	if btn_minus != null:
		btn_minus.disabled = _busy or current_bet <= min_bet

func _refresh_history() -> void:
	if txt_history == null:
		return
	if history.is_empty():
		txt_history.text = "Пока пусто"
		return
	var out: String = ""
	for line: String in history:
		out += line + "\n"
	txt_history.text = out.strip_edges()

func _refresh_payout_table() -> void:
	if txt_payout == null:
		return
	var out: String = ""
	var unlock_level: int = int(upgrades.get("unlock", 0))
	for sector: Dictionary in _sectors:
		var required: int = int(sector.get("unlock_level", 0))
		var unlocked: bool = required <= unlock_level
		var line: String = String(sector.get("name", "?"))
		if not unlocked:
			line += " (закрыт L%d)" % required
		else:
			var mult: float = _effective_multiplier(sector)
			var pen: float = _effective_penalty(sector)
			if mult > 0.0:
				line += "  x%.2f" % mult
			else:
				line += "  x0"
			if pen > 0.0:
				line += "  штраф %.0f%%" % (pen * 100.0)
		out += line + "\n"
	txt_payout.text = out.strip_edges()

func _refresh_mission_ui() -> void:
	if lbl_mission == null or btn_mission_claim == null:
		return
	var mission: Dictionary = _current_mission_for_ui()
	if mission.is_empty():
		lbl_mission.text = "Тир %d закрыт. После награды откроется новый." % mission_tier
		btn_mission_claim.disabled = true
		btn_mission_claim.text = "Нет доступной награды"
		return

	var title: String = String(mission.get("title", "Миссия"))
	var progress: int = int(mission.get("progress", 0))
	var target: int = int(mission.get("target", 1))
	var reward: int = int(mission.get("reward", 0))
	var ready: bool = progress >= target
	lbl_mission.text = "%s\nПрогресс: %d/%d  |  Награда: %d" % [title, progress, target, reward]
	btn_mission_claim.disabled = _busy or not ready
	if ready:
		btn_mission_claim.text = "Забрать +%d" % reward
	else:
		btn_mission_claim.text = "Миссия не выполнена"

func _refresh_shop_ui() -> void:
	for id: Variant in shop_buttons.keys():
		var key: String = String(id)
		var button: Button = shop_buttons[key] as Button
		if button == null:
			continue
		var lvl: int = int(upgrades.get(key, 0))
		var max_lvl: int = int(UPGRADE_MAX_LEVEL.get(key, 1))
		if lvl >= max_lvl:
			button.text = "%s  L%d/%d (MAX)" % [_upgrade_title(key), lvl, max_lvl]
			button.disabled = true
		else:
			var cost: int = _upgrade_cost(key)
			button.text = "%s  L%d -> L%d  (%d)" % [_upgrade_title(key), lvl, lvl + 1, cost]
			button.disabled = _busy or bankroll < cost

func _refresh_daily_ui() -> void:
	if btn_daily == null:
		return
	if _can_claim_daily():
		var reward: int = _daily_reward_preview()
		btn_daily.text = "Ежедневный бонус +%d" % reward
		btn_daily.disabled = _busy
	else:
		btn_daily.text = "Бонус получен сегодня (серия %d)" % daily_streak
		btn_daily.disabled = true

func _can_afford_spin() -> bool:
	return bankroll >= spin_fee + current_bet

func _dynamic_max_bet() -> int:
	return max_bet + int(upgrades.get("unlock", 0)) * 100

func _change_bet(delta: int) -> void:
	if _busy:
		return
	var value: int = current_bet + (delta * bet_step)
	current_bet = clampi(value, min_bet, _dynamic_max_bet())
	_save_progress()
	_refresh_ui_state()

func _on_bet_plus() -> void:
	_change_bet(1)

func _on_bet_minus() -> void:
	_change_bet(-1)

func _on_daily_pressed() -> void:
	if _busy:
		return
	_claim_daily_bonus()

func _on_claim_mission_pressed() -> void:
	if _busy:
		return
	_claim_current_mission()

func _on_buy_luck() -> void:
	_buy_upgrade("luck")

func _on_buy_booster() -> void:
	_buy_upgrade("booster")

func _on_buy_shield() -> void:
	_buy_upgrade("shield")

func _on_buy_unlock() -> void:
	_buy_upgrade("unlock")

func _upgrade_title(id: String) -> String:
	match id:
		"luck":
			return "Удача"
		"booster":
			return "Множитель"
		"shield":
			return "Щит от бомб"
		"unlock":
			return "Новые секторы"
		_:
			return id

func _buy_upgrade(id: String) -> void:
	if _busy:
		return
	var level: int = int(upgrades.get(id, 0))
	var max_level: int = int(UPGRADE_MAX_LEVEL.get(id, 0))
	if level >= max_level:
		_set_status("%s уже максимального уровня" % _upgrade_title(id))
		return

	var cost: int = _upgrade_cost(id)
	if bankroll < cost:
		_set_status("Не хватает денег на %s" % _upgrade_title(id))
		return

	bankroll -= cost
	upgrades[id] = level + 1
	current_bet = clampi(current_bet, min_bet, _dynamic_max_bet())
	_set_status("Куплен апгрейд: %s L%d" % [_upgrade_title(id), level + 1])
	_push_history("UPGRADE %s -> L%d" % [id, level + 1])
	_save_progress()
	_refresh_all()

func _upgrade_cost(id: String) -> int:
	var level: int = int(upgrades.get(id, 0))
	var base: float = float(UPGRADE_BASE_COST.get(id, 500))
	return int(round(base * pow(1.58, level)))

func _init_sectors() -> void:
	_sectors = [
		{
			"id": "miss",
			"name": "Пусто",
			"multiplier": 0.0,
			"penalty": 0.0,
			"weight": 36.0,
			"unlock_level": 0,
			"symbol_index": 5,
			"jackpot": false,
		},
		{
			"id": "x2",
			"name": "Сектор x2",
			"multiplier": 2.0,
			"penalty": 0.0,
			"weight": 24.0,
			"unlock_level": 0,
			"symbol_index": 1,
			"jackpot": false,
		},
		{
			"id": "x5",
			"name": "Сектор x5",
			"multiplier": 5.0,
			"penalty": 0.0,
			"weight": 11.0,
			"unlock_level": 0,
			"symbol_index": 0,
			"jackpot": false,
		},
		{
			"id": "bomb",
			"name": "Бомба",
			"multiplier": 0.0,
			"penalty": 0.55,
			"weight": 13.0,
			"unlock_level": 0,
			"symbol_index": 2,
			"jackpot": false,
		},
		{
			"id": "x8",
			"name": "Клевер x8",
			"multiplier": 8.0,
			"penalty": 0.0,
			"weight": 7.0,
			"unlock_level": 1,
			"symbol_index": 3,
			"jackpot": false,
		},
		{
			"id": "x12",
			"name": "Алмаз x12",
			"multiplier": 12.0,
			"penalty": 0.0,
			"weight": 4.0,
			"unlock_level": 2,
			"symbol_index": 4,
			"jackpot": false,
		},
		{
			"id": "jackpot",
			"name": "Джекпот",
			"multiplier": 25.0,
			"penalty": 0.0,
			"weight": 1.1,
			"unlock_level": 3,
			"symbol_index": 6,
			"jackpot": true,
		},
	]

func _roll_sector() -> Dictionary:
	var active: Array[Dictionary] = _active_sectors()
	if active.is_empty():
		return _sectors[0]

	var total: float = 0.0
	for sector: Dictionary in active:
		total += _sector_weight(sector)

	if total <= 0.0:
		return active[_rng.randi_range(0, active.size() - 1)]

	var roll: float = _rng.randf_range(0.0, total)
	var acc: float = 0.0
	for sector: Dictionary in active:
		acc += _sector_weight(sector)
		if roll <= acc:
			return sector

	return active[active.size() - 1]

func _active_sectors() -> Array[Dictionary]:
	var active: Array[Dictionary] = []
	var unlock_level: int = int(upgrades.get("unlock", 0))
	for sector: Dictionary in _sectors:
		var need: int = int(sector.get("unlock_level", 0))
		if need <= unlock_level:
			active.append(sector)
	return active

func _sector_weight(sector: Dictionary) -> float:
	var weight: float = float(sector.get("weight", 1.0))
	var luck_level: int = int(upgrades.get("luck", 0))
	var mult: float = float(sector.get("multiplier", 0.0))
	var penalty: float = float(sector.get("penalty", 0.0))

	if mult > 0.0:
		weight *= 1.0 + float(luck_level) * 0.1
	elif penalty > 0.0:
		weight *= maxf(0.25, 1.0 - float(luck_level) * 0.11)
	else:
		weight *= maxf(0.45, 1.0 - float(luck_level) * 0.05)

	return maxf(weight, 0.01)

func _effective_multiplier(sector: Dictionary) -> float:
	var mult: float = float(sector.get("multiplier", 0.0))
	if mult <= 0.0:
		return 0.0
	var boost_level: int = int(upgrades.get("booster", 0))
	mult += float(boost_level) * 0.35
	return maxf(mult, 0.0)

func _effective_penalty(sector: Dictionary) -> float:
	var penalty: float = float(sector.get("penalty", 0.0))
	if penalty <= 0.0:
		return 0.0
	var shield_level: int = int(upgrades.get("shield", 0))
	penalty -= float(shield_level) * 0.08
	return maxf(penalty, 0.0)

func _texture_for_sector(sector: Dictionary) -> Texture2D:
	var idx: int = int(sector.get("symbol_index", -1))
	if idx >= 0 and idx < symbols.size() and symbols[idx] != null:
		return symbols[idx]
	return _random_symbol_texture()

func _random_symbol_texture() -> Texture2D:
	if symbols.is_empty():
		return null
	var idx: int = _rng.randi_range(0, symbols.size() - 1)
	return symbols[idx]

func _spin_status_text(sector: Dictionary, payout: int, penalty: int, net: int) -> String:
	var name: String = String(sector.get("name", "?"))
	if bool(sector.get("jackpot", false)):
		return "ДЖЕКПОТ %s | +%d | NET %+d" % [name, payout, net]
	if penalty > 0:
		return "%s | штраф %d | NET %+d" % [name, penalty, net]
	if payout > 0:
		return "%s | выигрыш %d | NET %+d" % [name, payout, net]
	return "%s | проигрыш | NET %+d" % [name, net]

func _spin_history_text(sector: Dictionary, payout: int, penalty: int, total_cost: int, net: int) -> String:
	var name: String = String(sector.get("name", "?"))
	return "%s | cost %d | win %d | penalty %d | net %+d" % [name, total_cost, payout, penalty, net]

func _update_stats_after_spin(net: int, sector: Dictionary) -> void:
	stats["total_spins"] = int(stats.get("total_spins", 0)) + 1
	if net > 0:
		stats["wins"] = int(stats.get("wins", 0)) + 1
		best_win = maxi(best_win, net)
	if bool(sector.get("jackpot", false)):
		stats["jackpots"] = int(stats.get("jackpots", 0)) + 1

func _push_history(entry: String) -> void:
	history.push_front(entry)
	while history.size() > HISTORY_LIMIT:
		history.pop_back()

func _daily_reward_preview() -> int:
	var next_streak: int = daily_streak + 1 if _current_day_index() - last_daily_day == 1 else 1
	return 200 + (next_streak - 1) * 75

func _claim_daily_bonus() -> void:
	if not _can_claim_daily():
		_set_status("Ежедневный бонус уже получен")
		return

	var today: int = _current_day_index()
	if last_daily_day == today - 1:
		daily_streak = mini(daily_streak + 1, 7)
	else:
		daily_streak = 1

	last_daily_day = today
	var reward: int = 200 + (daily_streak - 1) * 75
	bankroll += reward
	_set_status("Ежедневный бонус: +%d (серия %d)" % [reward, daily_streak])
	_push_history("DAILY +%d" % reward)
	if bankroll > max_balance:
		max_balance = bankroll
	_save_progress()
	_refresh_all()

func _can_claim_daily() -> bool:
	return _current_day_index() != last_daily_day

func _current_day_index() -> int:
	return int(floor(Time.get_unix_time_from_system() / 86400.0))

func _mission_defs() -> Array[Dictionary]:
	var tier_offset: int = mission_tier - 1
	return [
		{
			"id": "spins",
			"title": "Сделать спины",
			"target": 20 + tier_offset * 10,
			"reward": 250 + tier_offset * 120,
			"progress": int(stats.get("total_spins", 0)),
		},
		{
			"id": "wins",
			"title": "Выиграть спины",
			"target": 10 + tier_offset * 5,
			"reward": 320 + tier_offset * 130,
			"progress": int(stats.get("wins", 0)),
		},
		{
			"id": "jackpot",
			"title": "Поймать джекпот",
			"target": 1 + int(floor(float(tier_offset) / 2.0)),
			"reward": 900 + tier_offset * 180,
			"progress": int(stats.get("jackpots", 0)),
		},
	]

func _mission_key(id: String) -> String:
	return "%s_tier_%d" % [id, mission_tier]

func _is_mission_claimed(id: String) -> bool:
	return bool(mission_claimed.get(_mission_key(id), false))

func _current_mission_for_ui() -> Dictionary:
	var defs: Array[Dictionary] = _mission_defs()
	for mission: Dictionary in defs:
		var id: String = String(mission.get("id", ""))
		if not _is_mission_claimed(id):
			return mission
	return {}

func _claim_current_mission() -> void:
	var mission: Dictionary = _current_mission_for_ui()
	if mission.is_empty():
		_set_status("Нет миссий для получения")
		return

	var id: String = String(mission.get("id", ""))
	var progress: int = int(mission.get("progress", 0))
	var target: int = int(mission.get("target", 1))
	if progress < target:
		_set_status("Миссия ещё не выполнена")
		return

	var reward: int = int(mission.get("reward", 0))
	mission_claimed[_mission_key(id)] = true
	bankroll += reward
	if bankroll > max_balance:
		max_balance = bankroll
	_push_history("MISSION +%d" % reward)

	if _all_tier_missions_claimed():
		mission_tier += 1
		mission_claimed.clear()
		_set_status("Все миссии закрыты. Открыт тир %d" % mission_tier)
	else:
		_set_status("Награда за миссию: +%d" % reward)

	_save_progress()
	_refresh_all()

func _all_tier_missions_claimed() -> bool:
	for mission: Dictionary in _mission_defs():
		var id: String = String(mission.get("id", ""))
		if not _is_mission_claimed(id):
			return false
	return true

func _load_progress() -> void:
	bankroll = starting_bankroll
	current_bet = min_bet
	best_win = 0
	max_balance = starting_bankroll
	daily_streak = 0
	last_daily_day = -1
	mission_tier = 1
	upgrades = {
		"luck": 0,
		"booster": 0,
		"shield": 0,
		"unlock": 0,
	}
	stats = {
		"total_spins": 0,
		"wins": 0,
		"jackpots": 0,
	}
	mission_claimed = {}
	history.clear()

	if Engine.is_editor_hint():
		return
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return

	var data: Dictionary = parsed as Dictionary
	bankroll = int(data.get("bankroll", bankroll))
	current_bet = int(data.get("current_bet", current_bet))
	best_win = int(data.get("best_win", best_win))
	max_balance = int(data.get("max_balance", max_balance))
	daily_streak = int(data.get("daily_streak", daily_streak))
	last_daily_day = int(data.get("last_daily_day", last_daily_day))
	mission_tier = int(data.get("mission_tier", mission_tier))

	var loaded_upgrades: Dictionary = data.get("upgrades", upgrades)
	for key: String in upgrades.keys():
		upgrades[key] = int(loaded_upgrades.get(key, upgrades[key]))

	var loaded_stats: Dictionary = data.get("stats", stats)
	for key: String in stats.keys():
		stats[key] = int(loaded_stats.get(key, stats[key]))

	mission_claimed = data.get("mission_claimed", {})

	var loaded_history: Array = data.get("history", [])
	for item: Variant in loaded_history:
		history.append(String(item))
	while history.size() > HISTORY_LIMIT:
		history.pop_back()

	current_bet = clampi(current_bet, min_bet, _dynamic_max_bet())
	bankroll = maxi(bankroll, 0)
	max_balance = maxi(max_balance, bankroll)

func _save_progress() -> void:
	if Engine.is_editor_hint():
		return
	var data: Dictionary = {
		"bankroll": bankroll,
		"current_bet": current_bet,
		"best_win": best_win,
		"max_balance": max_balance,
		"daily_streak": daily_streak,
		"last_daily_day": last_daily_day,
		"mission_tier": mission_tier,
		"upgrades": upgrades,
		"stats": stats,
		"mission_claimed": mission_claimed,
		"history": history,
	}
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data))
