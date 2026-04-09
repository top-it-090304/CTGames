@tool
extends Node3D

@onready var slot_ui: Control = $SubViewport/SlotUI
@onready var animation_player: AnimationPlayer = $AnimationPlayer
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
var ready_button: Button
var totem_buy_panel: Panel
var win_sequence_layer: Control
var slot_test_console: Panel

var win_popup_tween: Tween
var cam_tween: Tween

const PIXEL_FONT: FontFile = preload("res://textures/pixeloidsans/PixeloidSans.ttf")
var _money_base_pos := Vector2.ZERO
var _spins_base_pos := Vector2.ZERO
var _tok_base_pos := Vector2.ZERO
var _win_popup_base_pos := Vector2.ZERO
@export var slot_spin_area_name: StringName = &"LeverArea"
var slot_spin_area: Area3D

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
	_ensure_slot_screen_surface()
	_ensure_slot_test_console()
	_ensure_camera_targets()
	_connect_intro_overlay()
	_sync_intro_lock()
	_ensure_intro_started()
	slot_spin_area = _find_slot_spin_area()
	_bind_ready_button()
	_bind_win_sequence_layer()
	_update_ready_button_visibility()
	if win_popup != null:
		win_popup.visible = false

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.keycode == KEY_TAB or key_event.physical_keycode == KEY_TAB:
			_toggle_slot_test_console()
			get_viewport().set_input_as_handled()
			return

	if event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		_rotate_camera_by_drag(drag.relative.x)
		return

	if event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
			_rotate_camera_by_drag(mm.relative.x)
			return

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.keycode == KEY_SPACE or key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER:
			if ready_button != null and ready_button.visible:
				_on_ready_button_pressed()
			else:
				_request_spin()
			return

	if _is_intro_active():
		return
	if _is_spin_choice_open():
		return

	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if touch.pressed:
			_request_spin_from_screen(touch.position)
			return

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_request_spin_from_screen(mb.position)
			return


func _rotate_camera_by_drag(delta_x: float) -> void:
	if camera_3d == null:
		return
	camera_3d.rotate_y(-delta_x * 0.004)

func _request_spin_from_screen(screen_pos: Vector2) -> void:
	if slot_ui != null and slot_ui.has_method("get_spins_left") and int(slot_ui.call("get_spins_left")) <= 0:
		return
	if is_win_sequence_active():
		return
	if not _is_slot_machine_hit(screen_pos):
		return
	_request_spin()

func _is_slot_machine_hit(screen_pos: Vector2) -> bool:
	if camera_3d == null:
		return false
	if slot_spin_area == null:
		slot_spin_area = _find_slot_spin_area()
	if slot_spin_area == null:
		return false

	var from: Vector3 = camera_3d.project_ray_origin(screen_pos)
	var to: Vector3 = from + camera_3d.project_ray_normal(screen_pos) * 100.0
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return false

	var collider: Node = result.get("collider") as Node
	if collider == null:
		return false

	return _is_node_under(slot_spin_area, collider)

func _is_node_under(root: Node, node: Node) -> bool:
	if root == null or node == null:
		return false
	var current: Node = node
	while current != null:
		if current == root:
			return true
		current = current.get_parent()
	return false

func _ensure_slot_test_console() -> void:
	var ui_root: Control = get_node_or_null("UI") as Control
	if ui_root == null:
		return
	slot_test_console = ui_root.get_node_or_null("SlotTestConsole") as Panel
	if slot_test_console == null:
		slot_test_console = Panel.new()
		slot_test_console.name = "SlotTestConsole"
		ui_root.add_child(slot_test_console)
	var script: Script = load("res://Materials/slot_test_console.gd")
	if slot_test_console.get_script() != script:
		slot_test_console.set_script(script)
	if slot_test_console.has_method("_ensure_ui"):
		slot_test_console.call("_ensure_ui")
	slot_test_console.visible = false
	if slot_test_console.has_method("set_slot_ui_target"):
		slot_test_console.call_deferred("set_slot_ui_target", slot_ui)

func _toggle_slot_test_console() -> void:
	if slot_test_console == null:
		_ensure_slot_test_console()
	if slot_test_console == null:
		return
	slot_test_console.visible = not slot_test_console.visible
	if slot_test_console.visible:
		var parent_node: Node = slot_test_console.get_parent()
		if parent_node != null:
			parent_node.move_child(slot_test_console, parent_node.get_child_count() - 1)
		if slot_test_console.has_method("set_slot_ui_target"):
			slot_test_console.call("set_slot_ui_target", slot_ui)

func _bind_ready_button() -> void:
	ready_button = get_node_or_null("UI/ReadyButton") as Button
	totem_buy_panel = get_node_or_null("UI/TotemBuyPanel") as Panel
	if ready_button == null:
		return
	var cb: Callable = Callable(self, "_on_ready_button_pressed")
	if not ready_button.pressed.is_connected(cb):
		ready_button.pressed.connect(cb)

func _bind_win_sequence_layer() -> void:
	win_sequence_layer = get_node_or_null("SubViewport/SlotUI/WinSequenceLayer") as Control
	if win_sequence_layer == null:
		win_sequence_layer = get_node_or_null("UI/WinSequenceLayer") as Control
	if win_sequence_layer == null:
		return
	if win_sequence_layer.has_signal("hit_highlight_requested"):
		var hit_cb: Callable = Callable(self, "_on_win_highlight_requested")
		if not win_sequence_layer.is_connected("hit_highlight_requested", hit_cb):
			win_sequence_layer.connect("hit_highlight_requested", hit_cb)
	if win_sequence_layer.has_signal("highlight_cleared"):
		var clear_cb: Callable = Callable(self, "_on_win_highlight_cleared")
		if not win_sequence_layer.is_connected("highlight_cleared", clear_cb):
			win_sequence_layer.connect("highlight_cleared", clear_cb)

func is_win_sequence_active() -> bool:
	return win_sequence_layer != null and win_sequence_layer.has_method("is_playing") and bool(win_sequence_layer.call("is_playing"))

func _on_win_highlight_requested(points: Array, palette_index: int) -> void:
	if slot_ui != null and slot_ui.has_method("show_combo_highlight"):
		slot_ui.call("show_combo_highlight", points, palette_index)

func _on_win_highlight_cleared() -> void:
	if slot_ui != null and slot_ui.has_method("clear_combo_highlight"):
		slot_ui.call("clear_combo_highlight")

func _on_ready_button_pressed() -> void:
	if ready_button == null:
		return
	if _is_intro_active() or _is_spin_choice_open() or _is_totem_buy_panel_open():
		return
	if round_system != null and round_system.has_method("request_spin_choice"):
		round_system.call("request_spin_choice")
	_update_ready_button_visibility()

func _is_totem_buy_panel_open() -> bool:
	if totem_buy_panel == null:
		totem_buy_panel = get_node_or_null("UI/TotemBuyPanel") as Panel
	if totem_buy_panel == null:
		return false
	return totem_buy_panel.visible

func _update_ready_button_visibility() -> void:
	if ready_button == null:
		return
	var show: bool = false
	if not _is_intro_active() and not _is_spin_choice_open() and not _is_totem_buy_panel_open() and not is_win_sequence_active():
		var spinning: bool = slot_ui != null and slot_ui.has_method("is_spinning") and bool(slot_ui.call("is_spinning"))
		var spins_left: int = int(slot_ui.call("get_spins_left")) if slot_ui != null and slot_ui.has_method("get_spins_left") else 0
		var round_active: bool = round_system != null and round_system.has_method("is_round_active") and bool(round_system.call("is_round_active"))
		var game_over: bool = round_system != null and round_system.has_method("is_game_over") and bool(round_system.call("is_game_over"))
		show = not spinning and not round_active and not game_over and spins_left <= 0
	ready_button.visible = show
	ready_button.disabled = not show

func _request_spin() -> void:
	if _is_intro_active():
		return
	if _is_spin_choice_open():
		return
	if is_win_sequence_active():
		return
	if slot_ui == null:
		return

	if slot_ui.has_method("is_spinning") and slot_ui.call("is_spinning"):
		return

	if slot_ui.has_method("get_spins_left") and int(slot_ui.call("get_spins_left")) <= 0:
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

func _is_spin_choice_open() -> bool:
	if round_system == null or not round_system.has_method("is_popup_open"):
		return false
	return bool(round_system.call("is_popup_open"))

func _on_intro_active_changed(active: bool) -> void:
	if slot_ui == null:
		return
	if slot_ui.has_method("set_input_locked"):
		slot_ui.call("set_input_locked", active)
	else:
		slot_ui.set("input_locked", active)
	_update_ready_button_visibility()

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
	_ensure_marker(root, "CamDebt", camera_3d, _find_machine("DebtMachine", "blockbench_export3"), Vector3(0.0, 1.2, 2.2))
	_ensure_marker(root, "CamTickets", camera_3d, _find_machine("TicketMachine", "blockbench_export"), Vector3(0.0, 1.2, 2.2))
	_ensure_marker(root, "CamSlot", camera_3d, null, Vector3.ZERO)

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
		var focus: Node3D = _machine_focus(machine)
		if focus != null:
			marker.global_position = focus.global_position
		else:
			marker.global_position = machine.global_position + machine_offset
		marker.look_at(machine.global_position + Vector3(0.0, 0.7, 0.0), Vector3.UP)
		return

	if cam != null:
		marker.global_transform = cam.global_transform

func _machine_focus(machine: Node3D) -> Node3D:
	if machine == null:
		return null
	var focus: Node3D = machine.get_node_or_null("FocusPoint") as Node3D
	if focus == null:
		return null
	if focus.position.length() < 0.15:
		return null
	return focus

func _move_camera_to_hint(hint: String) -> void:
	_move_camera_to_hint_duration(hint, 0.6)

func _move_camera_to_hint_duration(hint: String, duration: float) -> void:
	if camera_3d == null:
		return

	var target: Marker3D = _hint_target(hint)
	if target == null:
		return

	if cam_tween != null:
		cam_tween.kill()

	cam_tween = create_tween()
	cam_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var move_time: float = clampf(duration, 0.08, 2.0)

	cam_tween.parallel().tween_property(
		camera_3d,
		"global_position",
		target.global_position,
		move_time
	)
	cam_tween.parallel().tween_property(
		camera_3d,
		"global_rotation",
		target.global_rotation,
		move_time
	)

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
	var machine: Node3D = get_node_or_null("SlotMachineRoot") as Node3D
	if machine != null:
		return machine
	machine = get_node_or_null("SlotMachine") as Node3D
	if machine != null:
		return machine
	return get_node_or_null("blockbench_export2") as Node3D

func _ensure_slot_screen_surface() -> void:
	var slot_viewport: SubViewport = get_node_or_null("SubViewport") as SubViewport
	if slot_viewport == null:
		return

	var new_screen: MeshInstance3D = get_node_or_null("SlotMachineRoot/ScreenSurface") as MeshInstance3D
	if new_screen != null:
		var new_material: StandardMaterial3D = new_screen.material_override as StandardMaterial3D
		if new_material == null:
			new_material = StandardMaterial3D.new()
			new_material.resource_local_to_scene = true
			new_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			new_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			new_material.cull_mode = BaseMaterial3D.CULL_DISABLED
			new_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			new_material.emission_enabled = true
			new_material.emission = Color.WHITE
			new_material.emission_energy_multiplier = 1.0
			new_screen.material_override = new_material

		var new_viewport_texture: ViewportTexture = slot_viewport.get_texture()
		new_material.albedo_texture = new_viewport_texture
		new_material.emission_texture = new_viewport_texture
		return

	var screen_mesh: MeshInstance3D = get_node_or_null("Mesh_Slotmachine/Mesh_SlotmachineScreen") as MeshInstance3D
	if screen_mesh == null:
		return

	var aabb: AABB = screen_mesh.get_aabb()
	if aabb.size == Vector3.ZERO:
		return

	var overlay: MeshInstance3D = screen_mesh.get_node_or_null("ViewportPlane") as MeshInstance3D
	if overlay == null:
		overlay = MeshInstance3D.new()
		overlay.name = "ViewportPlane"
		screen_mesh.add_child(overlay)

	var material: StandardMaterial3D = overlay.material_override as StandardMaterial3D
	if material == null:
		material = StandardMaterial3D.new()
		material.resource_local_to_scene = true
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.emission_enabled = true
		material.emission = Color.WHITE
		material.emission_energy_multiplier = 1.0
		overlay.material_override = material

	var viewport_texture: ViewportTexture = slot_viewport.get_texture()
	material.albedo_texture = viewport_texture
	material.emission_texture = viewport_texture

	var quad := QuadMesh.new()
	var center: Vector3 = aabb.position + (aabb.size * 0.5)
	var shrink: float = 0.96
	var offset: float = 0.05
	var thin_axis: int = _smallest_axis_index(aabb.size)

	match thin_axis:
		0:
			quad.size = Vector2(maxf(aabb.size.z * shrink, 0.01), maxf(aabb.size.y * shrink, 0.01))
			overlay.rotation_degrees = Vector3(0.0, 90.0, 0.0)
			overlay.position = center + Vector3(aabb.size.x * 0.5 + offset, 0.0, 0.0)
		1:
			quad.size = Vector2(maxf(aabb.size.x * shrink, 0.01), maxf(aabb.size.z * shrink, 0.01))
			overlay.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
			overlay.position = center + Vector3(0.0, aabb.size.y * 0.5 + offset, 0.0)
		_:
			quad.size = Vector2(maxf(aabb.size.x * shrink, 0.01), maxf(aabb.size.y * shrink, 0.01))
			overlay.rotation_degrees = Vector3.ZERO
			overlay.position = center + Vector3(0.0, 0.0, aabb.size.z * 0.5 + offset)

	overlay.mesh = quad

func _smallest_axis_index(size: Vector3) -> int:
	if size.x <= size.y and size.x <= size.z:
		return 0
	if size.y <= size.x and size.y <= size.z:
		return 1
	return 2

func _find_slot_spin_area() -> Area3D:
	var machine: Node3D = _find_slot_machine()
	if machine == null:
		return null

	var direct: Area3D = machine.get_node_or_null(str(slot_spin_area_name)) as Area3D
	if direct != null:
		return direct

	var aliases: Array[String] = ["LeverArea", "SpinButtonarea", "SpinArea", "SpinButtonArea", "ButtonArea", "InteractArea"]
	for alias: String in aliases:
		var area: Area3D = machine.get_node_or_null(alias) as Area3D
		if area != null:
			return area

	return null

func _resolve_animation_player() -> AnimationPlayer:
	var machine: Node3D = _find_slot_machine()
	if machine == null:
		return null
	var player: AnimationPlayer = machine.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if player != null:
		return player
	return machine.get_node_or_null("ModelRoot/AnimationPlayer") as AnimationPlayer

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
	if slot_ui.has_signal("win_sequence_requested"):
		var on_sequence: Callable = Callable(self, "_on_win_sequence_requested")
		if not slot_ui.is_connected("win_sequence_requested", on_sequence):
			slot_ui.connect("win_sequence_requested", on_sequence)

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
	_update_ready_button_visibility()
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

func _on_win_sequence_requested(result: Dictionary) -> void:
	_update_ready_button_visibility()
	if win_sequence_layer == null:
		_bind_win_sequence_layer()
	if win_sequence_layer == null or not win_sequence_layer.has_method("play_result"):
		var amount: int = int(result.get("win_amount", 0))
		if amount > 0:
			_on_win_popup_requested(amount)
		return
	win_sequence_layer.call("play_result", result.duplicate(true))

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
		lbl_money.add_theme_font_override("font", PIXEL_FONT)
		lbl_money.add_theme_font_size_override("font_size", 56)
		lbl_money.add_theme_color_override("font_color", Color(1.0, 0.86, 0.08, 1.0))
		lbl_money.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
		lbl_money.add_theme_constant_override("outline_size", 6)
		lbl_money.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	if lbl_spins != null:
		lbl_spins.position = Vector2(14.0, 84.0)
		lbl_spins.size = Vector2(356.0, 44.0)
		lbl_spins.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		lbl_spins.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl_spins.add_theme_font_override("font", PIXEL_FONT)
		lbl_spins.add_theme_font_size_override("font_size", 48)
		lbl_spins.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
		lbl_spins.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
		lbl_spins.add_theme_constant_override("outline_size", 3)
		lbl_spins.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

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
		lbl_tok.add_theme_font_override("font", PIXEL_FONT)
		lbl_tok.add_theme_font_size_override("font_size", 32)
		lbl_tok.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
		lbl_tok.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
		lbl_tok.add_theme_constant_override("outline_size", 3)
		lbl_tok.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

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
		win_popup.add_theme_font_override("font", PIXEL_FONT)
		win_popup.add_theme_font_size_override("font_size", 66)
		win_popup.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
		win_popup.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
		win_popup.add_theme_constant_override("outline_size", 4)
		win_popup.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	_money_base_pos = lbl_money.position if lbl_money != null else Vector2.ZERO
	_spins_base_pos = lbl_spins.position if lbl_spins != null else Vector2.ZERO
	_tok_base_pos = lbl_tok.position if lbl_tok != null else Vector2.ZERO
	_win_popup_base_pos = win_popup.position if win_popup != null else Vector2.ZERO

func _hud_box_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.86)
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	return style

func _update_hud_shake() -> void:
	var t: float = float(Time.get_ticks_msec()) * 0.001
	if lbl_money != null:
		lbl_money.position = _money_base_pos + Vector2(sin(t * 2.6) * 0.8, cos(t * 3.1) * 0.55)
	if lbl_spins != null:
		lbl_spins.position = _spins_base_pos + Vector2(sin(t * 2.2 + 0.7) * 0.55, cos(t * 2.8 + 0.5) * 0.35)
	if lbl_tok != null:
		lbl_tok.position = _tok_base_pos + Vector2(sin(t * 2.5 + 1.1) * 0.65, cos(t * 3.0 + 0.2) * 0.45)
	if win_popup != null and win_popup.visible:
		win_popup.position = _win_popup_base_pos + Vector2(sin(t * 3.0 + 0.9) * 1.0, cos(t * 3.4 + 0.4) * 0.7)
	elif win_popup != null:
		win_popup.position = _win_popup_base_pos

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
