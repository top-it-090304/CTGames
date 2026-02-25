@tool
extends Node3D

@onready var slot_ui: Control = $SubViewport/SlotUI

var hud_layer: CanvasLayer
var hud_left: Panel
var hud_right: Panel
var lbl_money: Label
var lbl_spins: Label
var lbl_tickets: Label
var win_popup: Label
var win_popup_tween: Tween

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_ensure_main_hud()
	_connect_slot_ui()
	_sync_hud_from_slot()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.keycode == KEY_SPACE or key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER:
			_request_spin()

func _request_spin() -> void:
	if slot_ui != null and slot_ui.has_method("request_spin"):
		slot_ui.request_spin()

func _connect_slot_ui() -> void:
	if slot_ui == null:
		return
	if slot_ui.has_signal("hud_changed"):
		var on_hud: Callable = Callable(self, "_on_hud_changed")
		if not slot_ui.is_connected("hud_changed", on_hud):
			slot_ui.connect("hud_changed", on_hud)
	if slot_ui.has_signal("win_popup_requested"):
		var on_popup: Callable = Callable(self, "_on_win_popup_requested")
		if not slot_ui.is_connected("win_popup_requested", on_popup):
			slot_ui.connect("win_popup_requested", on_popup)

func _sync_hud_from_slot() -> void:
	if slot_ui == null or not slot_ui.has_method("get_hud_state"):
		return
	var state: Dictionary = slot_ui.call("get_hud_state") as Dictionary
	_on_hud_changed(
		int(state.get("money", 0)),
		int(state.get("spins_left", 0)),
		int(state.get("tickets", 0))
	)

func _on_hud_changed(money: int, spins_left: int, tickets: int) -> void:
	if lbl_money != null:
		lbl_money.text = "%s F" % _format_money(money)
	if lbl_spins != null:
		lbl_spins.text = "SPINS LEFT: %d" % spins_left
	if lbl_tickets != null:
		lbl_tickets.text = "%d TIX" % tickets

func _on_win_popup_requested(amount: int) -> void:
	if win_popup == null:
		return
	if win_popup_tween != null:
		win_popup_tween.kill()
	win_popup.text = "+%d F" % amount
	win_popup.visible = true
	win_popup.modulate.a = 1.0
	var tw: Tween = create_tween()
	win_popup_tween = tw
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.86)
	tw.tween_property(win_popup, "modulate:a", 0.0, 0.28)
	tw.finished.connect(_hide_win_popup)

func _hide_win_popup() -> void:
	if win_popup == null:
		return
	if win_popup_tween != null:
		win_popup_tween = null
	win_popup.visible = false
	win_popup.modulate.a = 1.0

func _ensure_main_hud() -> void:
	hud_layer = get_node_or_null("MainHUD") as CanvasLayer
	if hud_layer == null:
		hud_layer = CanvasLayer.new()
		hud_layer.name = "MainHUD"
		add_child(hud_layer)
	hud_layer.layer = 10

	hud_left = hud_layer.get_node_or_null("HudLeft") as Panel
	if hud_left == null:
		hud_left = Panel.new()
		hud_left.name = "HudLeft"
		hud_layer.add_child(hud_left)
	hud_left.position = Vector2(18.0, 18.0)
	hud_left.size = Vector2(382.0, 136.0)
	hud_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_left.add_theme_stylebox_override("panel", _hud_box())

	lbl_money = _ensure_label(hud_left, "Money", Rect2(18.0, 14.0, 346.0, 52.0), 52)
	lbl_spins = _ensure_label(hud_left, "Spins", Rect2(18.0, 78.0, 346.0, 36.0), 42)

	hud_right = hud_layer.get_node_or_null("HudRight") as Panel
	if hud_right == null:
		hud_right = Panel.new()
		hud_right.name = "HudRight"
		hud_layer.add_child(hud_right)
	hud_right.anchor_left = 1.0
	hud_right.anchor_right = 1.0
	hud_right.offset_left = -208.0
	hud_right.offset_top = 18.0
	hud_right.offset_right = -18.0
	hud_right.offset_bottom = 88.0
	hud_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_right.add_theme_stylebox_override("panel", _hud_box())

	lbl_tickets = _ensure_label(hud_right, "Tickets", Rect2(16.0, 14.0, 162.0, 40.0), 44)
	lbl_tickets.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	win_popup = hud_layer.get_node_or_null("WinPopup") as Label
	if win_popup == null:
		win_popup = Label.new()
		win_popup.name = "WinPopup"
		hud_layer.add_child(win_popup)
	win_popup.anchor_left = 0.5
	win_popup.anchor_top = 0.5
	win_popup.anchor_right = 0.5
	win_popup.anchor_bottom = 0.5
	win_popup.offset_left = -220.0
	win_popup.offset_top = -58.0
	win_popup.offset_right = 220.0
	win_popup.offset_bottom = 58.0
	win_popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	win_popup.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	win_popup.add_theme_font_size_override("font_size", 88)
	win_popup.add_theme_color_override("font_color", Color(1.0, 0.2, 0.95, 1.0))
	win_popup.visible = false
	win_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE

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

func _hud_box() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.88)
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	return style

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
