@tool
extends Node3D

@onready var slot_ui: Control = $SubViewport/SlotUI
@onready var animation_player: AnimationPlayer = _resolve_animation_player()
@onready var intro_overlay: Node = get_node_or_null("IntroOverlay")
@onready var camera_3d: Camera3D = get_node_or_null("Camera3D") as Camera3D
@onready var round_system: Node = get_node_or_null("RoundSystem")

var hud_layer: CanvasLayer
var hud_left: Panel
var hud_right: Panel
var lbl_money: Label
var lbl_spins: Label
var lbl_tok: Label
var win_popup: Label

var win_popup_tween: Tween
var cam_tween: Tween

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_ensure_hud_tree()
	_bind_hud_nodes()
	_remove_paytable_panel()
	_configure_hud_visuals()
	_connect_slot_ui()
	_sync_hud_from_slot()
	_ensure_round_system()
	_ensure_camera_targets()
	_connect_intro_overlay()
	_sync_intro_lock()
	_ensure_intro_started()
	if win_popup != null:
		win_popup.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if _is_intro_active():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.keycode == KEY_SPACE or key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER:
			_request_spin()

func _request_spin() -> void:
	if _is_intro_active():
		return
	if slot_ui == null:
		return

	if slot_ui.has_method("is_spinning") and slot_ui.call("is_spinning"):
		return

	if slot_ui.has_method("get_spins_left") and int(slot_ui.call("get_spins_left")) <= 0:
		if round_system != null and round_system.has_method("request_spin_choice"):
			round_system.call("request_spin_choice")
		return

	if slot_ui.has_method("request_spin"):
		slot_ui.call("request_spin")

	if animation_player != null and slot_ui.has_method("is_spinning") and slot_ui.call("is_spinning"):
		animation_player.play("lever")

func _connect_intro_overlay() -> void:
	if intro_overlay == null:
		return
	if intro_overlay.has_signal("active_changed"):
		var cb: Callable = Callable(self, "_on_intro_active_changed")
		if not intro_overlay.is_connected("active_changed", cb):
			intro_overlay.connect("active_changed", cb)
	if intro_overlay.has_signal("camera_hint_requested"):
		var cam_cb: Callable = Callable(self, "_on_camera_hint_requested")
		if not intro_overlay.is_connected("camera_hint_requested", cam_cb):
			intro_overlay.connect("camera_hint_requested", cam_cb)

func _sync_intro_lock() -> void:
	_on_intro_active_changed(_is_intro_active())

func _ensure_intro_started() -> void:
	if intro_overlay == null:
		return
	if intro_overlay.has_method("is_active") and bool(intro_overlay.call("is_active")):
		return
	if intro_overlay.has_method("start"):
		intro_overlay.call_deferred("start")

func _is_intro_active() -> bool:
	if intro_overlay == null or not intro_overlay.has_method("is_active"):
		return false
	return bool(intro_overlay.call("is_active"))

func _on_intro_active_changed(active: bool) -> void:
	if slot_ui == null:
		return
	if slot_ui.has_method("set_input_locked"):
		slot_ui.call("set_input_locked", active)
	else:
		slot_ui.set("input_locked", active)

func _on_camera_hint_requested(hint: String) -> void:
	_move_camera_to_hint(hint)

func _ensure_round_system() -> void:
	if round_system == null:
		round_system = Node.new()
		round_system.name = "RoundSystem"
		round_system.set_script(load("res://Materials/round_system.gd"))
		add_child(round_system)
		return

	if round_system.get_script() == null:
		round_system.set_script(load("res://Materials/round_system.gd"))

func _ensure_camera_targets() -> void:
	var root: Node3D = get_node_or_null("CameraTargets") as Node3D
	if root == null:
		root = Node3D.new()
		root.name = "CameraTargets"
		add_child(root)

	_ensure_marker(root, "CamMain", camera_3d, null, Vector3.ZERO)
	_ensure_marker(root, "CamDebt", camera_3d, _find_machine("DebtMachine", "blockbench_export3"), Vector3(1.1, 1.2, 2.1))
	_ensure_marker(root, "CamTickets", camera_3d, _find_machine("TicketMachine", "blockbench_export"), Vector3(1.1, 1.2, 2.0))
	_ensure_marker(root, "CamSlot", camera_3d, _find_slot_machine(), Vector3(0.2, 1.0, 2.1))

func _ensure_marker(root: Node3D, marker_name: String, cam: Camera3D, machine: Node3D, machine_offset: Vector3) -> void:
	var marker: Marker3D = root.get_node_or_null(marker_name) as Marker3D
	if marker == null:
		marker = Marker3D.new()
		marker.name = marker_name
		root.add_child(marker)

	if marker_name == "CamMain" and cam != null:
		marker.global_transform = cam.global_transform
		return

	if machine != null:
		var pos: Vector3 = machine.global_position + machine.global_basis * machine_offset
		marker.global_position = pos
		marker.look_at(machine.global_position + Vector3(0.0, 0.7, 0.0), Vector3.UP)
		return

	if cam != null:
		marker.global_transform = cam.global_transform

func _move_camera_to_hint(hint: String) -> void:
	if camera_3d == null:
		return

	var target: Marker3D = _hint_target(hint)
	if target == null:
		return

	if cam_tween != null:
		cam_tween.kill()
	cam_tween = create_tween()
	cam_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	cam_tween.tween_property(camera_3d, "global_transform", target.global_transform, 0.62)

func _hint_target(hint: String) -> Marker3D:
	var root: Node = get_node_or_null("CameraTargets")
	if root == null:
		return null

	match hint:
		"debt_machine":
			return root.get_node_or_null("CamDebt") as Marker3D
		"ticket_machine":
			return root.get_node_or_null("CamTickets") as Marker3D
		"slot_machine":
			return root.get_node_or_null("CamSlot") as Marker3D
		_:
			return root.get_node_or_null("CamMain") as Marker3D

func _find_machine(primary: String, fallback: String) -> Node3D:
	var node: Node3D = get_node_or_null(primary) as Node3D
	if node != null:
		return node
	return get_node_or_null(fallback) as Node3D

func _find_slot_machine() -> Node3D:
	var machine: Node3D = get_node_or_null("SlotMachine") as Node3D
	if machine != null:
		return machine
	return get_node_or_null("blockbench_export2") as Node3D

func _resolve_animation_player() -> AnimationPlayer:
	var machine: Node3D = _find_slot_machine()
	if machine == null:
		return null
	return machine.get_node_or_null("AnimationPlayer") as AnimationPlayer

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
		lbl_money.text = "%s Ф" % _format_money(money)
	if lbl_spins != null:
		lbl_spins.text = "SPINS LEFT: %d" % spins_left
	if lbl_tok != null:
		lbl_tok.text = "%d TOK" % tickets

func _on_win_popup_requested(amount: int) -> void:
	if win_popup == null:
		return
	if win_popup_tween != null:
		win_popup_tween.kill()
	win_popup.text = "+%d Ф" % amount
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
	win_popup_tween = null
	win_popup.visible = false
	win_popup.modulate.a = 1.0

func _ensure_hud_tree() -> void:
	hud_layer = get_node_or_null("MainHUD") as CanvasLayer
	if hud_layer == null:
		hud_layer = CanvasLayer.new()
		hud_layer.name = "MainHUD"
		add_child(hud_layer)

	hud_left = hud_layer.get_node_or_null("HudLeft") as Panel
	if hud_left == null:
		hud_left = Panel.new()
		hud_left.name = "HudLeft"
		hud_layer.add_child(hud_left)

	lbl_money = hud_left.get_node_or_null("MoneyLabel") as Label
	if lbl_money == null:
		lbl_money = Label.new()
		lbl_money.name = "MoneyLabel"
		lbl_money.text = "0 Ф"
		hud_left.add_child(lbl_money)

	lbl_spins = hud_left.get_node_or_null("SpinsLabel") as Label
	if lbl_spins == null:
		lbl_spins = Label.new()
		lbl_spins.name = "SpinsLabel"
		lbl_spins.text = "SPINS LEFT: 0"
		hud_left.add_child(lbl_spins)

	hud_right = hud_layer.get_node_or_null("HudRight") as Panel
	if hud_right == null:
		hud_right = Panel.new()
		hud_right.name = "HudRight"
		hud_layer.add_child(hud_right)

	lbl_tok = hud_right.get_node_or_null("TokLabel") as Label
	if lbl_tok == null:
		var fallback: Label = hud_right.get_node_or_null("Label") as Label
		if fallback != null:
			fallback.name = "TokLabel"
			lbl_tok = fallback
		else:
			lbl_tok = Label.new()
			lbl_tok.name = "TokLabel"
			lbl_tok.text = "0 TOK"
			hud_right.add_child(lbl_tok)

	win_popup = hud_layer.get_node_or_null("WinPopup") as Label
	if win_popup == null:
		win_popup = Label.new()
		win_popup.name = "WinPopup"
		win_popup.text = "+0 Ф"
		hud_layer.add_child(win_popup)

func _bind_hud_nodes() -> void:
	hud_layer = get_node_or_null("MainHUD") as CanvasLayer
	hud_left = get_node_or_null("MainHUD/HudLeft") as Panel
	hud_right = get_node_or_null("MainHUD/HudRight") as Panel
	lbl_money = get_node_or_null("MainHUD/HudLeft/MoneyLabel") as Label
	lbl_spins = get_node_or_null("MainHUD/HudLeft/SpinsLabel") as Label
	lbl_tok = get_node_or_null("MainHUD/HudRight/TokLabel") as Label
	win_popup = get_node_or_null("MainHUD/WinPopup") as Label

func _remove_paytable_panel() -> void:
	if hud_layer == null:
		return
	var old_panel: Node = hud_layer.get_node_or_null("PaytablePanel")
	if old_panel != null:
		old_panel.queue_free()

func _configure_hud_visuals() -> void:
	if hud_left != null:
		hud_left.anchor_left = 0.0
		hud_left.anchor_top = 0.0
		hud_left.anchor_right = 0.0
		hud_left.anchor_bottom = 0.0
		hud_left.offset_left = 18.0
		hud_left.offset_top = 18.0
		hud_left.offset_right = 388.0
		hud_left.offset_bottom = 158.0
		hud_left.add_theme_stylebox_override("panel", _hud_box_style())

	if lbl_money != null:
		lbl_money.position = Vector2(14.0, 10.0)
		lbl_money.size = Vector2(356.0, 56.0)
		lbl_money.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		lbl_money.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl_money.add_theme_font_size_override("font_size", 56)
		lbl_money.add_theme_color_override("font_color", Color(1.0, 0.86, 0.08, 1.0))
		lbl_money.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
		lbl_money.add_theme_constant_override("outline_size", 6)

	if lbl_spins != null:
		lbl_spins.position = Vector2(14.0, 84.0)
		lbl_spins.size = Vector2(356.0, 44.0)
		lbl_spins.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		lbl_spins.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl_spins.add_theme_font_size_override("font_size", 48)
		lbl_spins.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
		lbl_spins.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
		lbl_spins.add_theme_constant_override("outline_size", 3)

	if hud_right != null:
		hud_right.anchor_left = 1.0
		hud_right.anchor_top = 0.0
		hud_right.anchor_right = 1.0
		hud_right.anchor_bottom = 0.0
		hud_right.offset_left = -188.0
		hud_right.offset_top = 18.0
		hud_right.offset_right = -18.0
		hud_right.offset_bottom = 76.0
		hud_right.add_theme_stylebox_override("panel", _hud_box_style())

	if lbl_tok != null:
		lbl_tok.position = Vector2(10.0, 8.0)
		lbl_tok.size = Vector2(150.0, 44.0)
		lbl_tok.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lbl_tok.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl_tok.add_theme_font_size_override("font_size", 32)
		lbl_tok.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
		lbl_tok.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
		lbl_tok.add_theme_constant_override("outline_size", 3)

	if win_popup != null:
		win_popup.anchor_left = 0.5
		win_popup.anchor_right = 0.5
		win_popup.anchor_top = 0.0
		win_popup.anchor_bottom = 0.0
		win_popup.offset_left = -180.0
		win_popup.offset_right = 180.0
		win_popup.offset_top = 96.0
		win_popup.offset_bottom = 154.0
		win_popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		win_popup.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		win_popup.add_theme_font_size_override("font_size", 66)
		win_popup.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
		win_popup.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
		win_popup.add_theme_constant_override("outline_size", 4)

func _hud_box_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.86)
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
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
