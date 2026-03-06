extends Node

@export_group("Debt")
@export var debt_target: int = 75
@export var initial_deposited: int = 30
@export var round_limit: int = 3
@export var interest_percent: float = 7.0
@export var deposit_step: int = 5
@export var debt_button_area_name: StringName = &"DepositButtonArea"
@export var debt_button_animation_name: String = "button_press"
@export var debt_button_animation_player_path: NodePath
@export var debt_strict_button_only: bool = false

@export_group("Spin Choices")
@export var option_a_spins: int = 7
@export var option_a_cost: int = 7
@export var option_a_ticket_bonus: int = 1
@export var option_b_spins: int = 3
@export var option_b_cost: int = 3
@export var option_b_ticket_bonus: int = 2

var game_root: Node3D
var slot_ui: Control
var intro_overlay: Node
var camera_3d: Camera3D

var debt_machine: Node3D
var ticket_machine: Node3D
var debt_area: Area3D
var ticket_area: Area3D
var debt_button_area: Area3D

var popup: Control
var debt_viewport: SubViewport
var debt_ui: Control

var rounds_left: int = 0
var deposited: int = 0
var game_over: bool = false
var round_active: bool = false
var early_bonus_given: bool = false
var _finish_round_requested: bool = false

func _ready() -> void:
	if Engine.is_editor_hint():
		return

	game_root = get_parent() as Node3D
	if game_root == null:
		return

	slot_ui = game_root.get_node_or_null("SubViewport/SlotUI") as Control
	intro_overlay = game_root.get_node_or_null("IntroOverlay")
	camera_3d = game_root.get_node_or_null("Camera3D") as Camera3D

	debt_machine = _find_machine(["DebtMachine", "blockbench_export3"])
	ticket_machine = _find_machine(["TicketMachine", "blockbench_export"])

	rounds_left = maxi(round_limit, 1)
	deposited = maxi(initial_deposited, 0)

	_ensure_interact_areas()
	_ensure_debt_viewport_ui()
	_ensure_popup()
	_connect_signals()
	_update_debt_ui()
	_set_spins_left(0)

	if not _is_intro_active():
		call_deferred("_show_jackpot_jail_screen")


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_try_finish_round_if_ready()

func _try_finish_round_if_ready() -> void:
	if _finish_round_requested or game_over or not round_active:
		return
	if _get_spins_left() > 0:
		return
	if slot_ui != null and slot_ui.has_method("is_spinning") and bool(slot_ui.call("is_spinning")):
		return
	_finish_round_requested = true
	call_deferred("_finish_round_if_ready_deferred")

func _finish_round_if_ready_deferred() -> void:
	_finish_round_requested = false
	if game_over or not round_active:
		return
	if _get_spins_left() > 0:
		return
	if slot_ui != null and slot_ui.has_method("is_spinning") and bool(slot_ui.call("is_spinning")):
		return
	_finish_round()

func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or _is_intro_active():
		return

	if event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		_forward_camera_drag(drag.relative.x)
		return

	if event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
			_forward_camera_drag(mm.relative.x)
			return

	if _popup_open():
		_handle_popup_input(event)
		return

	if game_over:
		return

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_try_interact(mb.position)
			return

	if event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event as InputEventScreenTouch
		if st.pressed:
			_try_interact(st.position)
			return

func _forward_camera_drag(delta_x: float) -> void:
	if game_root == null:
		return
	if game_root.has_method("_rotate_camera_by_drag"):
		game_root.call("_rotate_camera_by_drag", delta_x)

func _handle_popup_input(event: InputEvent) -> void:
	if popup == null:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		var key_event: InputEventKey = event as InputEventKey
		match key_event.keycode:
			KEY_1:
				_press_popup_button("Option7Button")
				get_viewport().set_input_as_handled()
			KEY_2:
				_press_popup_button("Option3Button")
				get_viewport().set_input_as_handled()
			KEY_ESCAPE, KEY_BACK:
				_press_popup_button("CancelButton")
				get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_select_popup_option_by_screen_pos(mb.position)
			get_viewport().set_input_as_handled()
		return

	if event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event as InputEventScreenTouch
		if not st.pressed:
			_select_popup_option_by_screen_pos(st.position)
			get_viewport().set_input_as_handled()
		return

func _select_popup_option_by_screen_pos(screen_pos: Vector2) -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var nx: float = screen_pos.x / viewport_size.x
	var ny: float = screen_pos.y / viewport_size.y

	if popup != null and popup.has_method("press_by_normalized_position"):
		popup.call("press_by_normalized_position", nx, ny)
		return

	# Fallback mapping
	if nx < 0.18 or nx > 0.82:
		return
	if ny < 0.61:
		_press_popup_button("Option7Button")
	elif ny < 0.70:
		_press_popup_button("Option3Button")
	else:
		_press_popup_button("CancelButton")

func _press_popup_button(button_name: String) -> void:
	if popup == null:
		return
	var btn: BaseButton = popup.get_node_or_null("Panel/%s" % button_name) as BaseButton
	if btn == null or btn.disabled:
		return
	btn.emit_signal("pressed")

func _connect_signals() -> void:
	if slot_ui != null and slot_ui.has_signal("spin_completed"):
		var cb: Callable = Callable(self, "_on_spin_completed")
		if not slot_ui.is_connected("spin_completed", cb):
			slot_ui.connect("spin_completed", cb)

	if intro_overlay != null and intro_overlay.has_signal("active_changed"):
		var icb: Callable = Callable(self, "_on_intro_active_changed")
		if not intro_overlay.is_connected("active_changed", icb):
			intro_overlay.connect("active_changed", icb)

	if popup != null:
		if popup.has_signal("option_selected"):
			var ocb: Callable = Callable(self, "_on_popup_option_selected")
			if not popup.is_connected("option_selected", ocb):
				popup.connect("option_selected", ocb)
		if popup.has_signal("canceled"):
			var ccb: Callable = Callable(self, "_on_popup_canceled")
			if not popup.is_connected("canceled", ccb):
				popup.connect("canceled", ccb)

func _on_intro_active_changed(active: bool) -> void:
	if active:
		_set_slot_locked(true)
		_close_popup()
		return

	if game_over:
		return

	if not round_active and _get_spins_left() <= 0:
		call_deferred("_show_jackpot_jail_screen")
	else:
		_set_slot_locked(false)
		_set_choice_overlay(false)

func _on_spin_completed(_win_amount: int) -> void:
	_try_finish_round_if_ready()

func _on_popup_option_selected(spins: int, cost: int, ticket_bonus: int) -> void:
	if game_over:
		return
	if not _spend_money(cost):
		return

	_add_tickets(ticket_bonus)
	_set_spins_left(spins)
	round_active = true
	_close_popup()
	_set_slot_locked(false)
	_update_debt_ui()

func _on_popup_canceled() -> void:
	if game_over:
		return
	_show_jackpot_jail_screen()

func request_spin_choice() -> void:
	if game_over or round_active or _is_intro_active():
		return
	_open_spin_choice()

func is_popup_open() -> bool:
	return _popup_open()

func _show_jackpot_jail_screen() -> void:
	if popup == null or game_over or _is_intro_active():
		return
	if round_active:
		return

	_set_slot_locked(false)
	_set_choice_overlay(true)
	if popup.has_method("show_jackpot_jail"):
		popup.call("show_jackpot_jail")
	else:
		_close_popup()

func _open_spin_choice() -> void:
	if popup == null or game_over or round_active or _is_intro_active():
		return

	if game_root != null and game_root.has_method("_move_camera_to_hint"):
		game_root.call("_move_camera_to_hint", "slot_machine")

	_set_choice_overlay(true)
	popup.call(
		"open_popup",
		option_a_spins,
		option_a_cost,
		option_a_ticket_bonus,
		option_b_spins,
		option_b_cost,
		option_b_ticket_bonus
	)
	_set_slot_locked(true)

func _close_popup() -> void:
	if popup != null and popup.has_method("close_popup"):
		popup.call("close_popup")
	_set_choice_overlay(false)

func _popup_open() -> bool:
	if popup == null:
		return false
	if popup.has_method("is_open"):
		return bool(popup.call("is_open"))
	return popup.visible

func _finish_round() -> void:
	round_active = false
	var interest_gain: int = _interest_amount()
	if interest_gain > 0:
		_add_money(interest_gain)
	_add_tickets(1)

	rounds_left = maxi(rounds_left - 1, 0)

	if deposited >= debt_target and not early_bonus_given and rounds_left > 0:
		_add_tickets(rounds_left)
		early_bonus_given = true

	_update_debt_ui()

	if rounds_left <= 0 and deposited < debt_target:
		game_over = true
		_set_slot_locked(true)
		_set_choice_overlay(true)
		if popup != null and popup.has_method("show_game_over"):
			popup.call("show_game_over", debt_target, deposited)
		return

	_show_jackpot_jail_screen()

func _try_interact(screen_pos: Vector2) -> void:
	if camera_3d == null:
		return

	var from: Vector3 = camera_3d.project_ray_origin(screen_pos)
	var to: Vector3 = from + camera_3d.project_ray_normal(screen_pos) * 100.0
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	var result: Dictionary = game_root.get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return

	var collider_var: Variant = result.get("collider")
	if collider_var == null:
		return
	var collider: Node = collider_var as Node
	if collider == null:
		return

	if _node_matches_area(collider, debt_area) or _has_ancestor_named(collider, ["DebtMachine", "blockbench_export3"]):
		var can_deposit: bool = _is_debt_button_hit(collider) or not debt_strict_button_only
		if can_deposit:
			_deposit_to_debt_machine()
			get_viewport().set_input_as_handled()
		elif game_root != null and game_root.has_method("_move_camera_to_hint"):
			game_root.call("_move_camera_to_hint", "debt_machine")
		return

	if _has_ancestor_named(collider, ["SlotMachine", "blockbench_export2"]):
		_request_slot_machine_action()
		get_viewport().set_input_as_handled()
		return

	if _node_matches_area(collider, ticket_area) or _has_ancestor_named(collider, ["TicketMachine", "blockbench_export"]):
		if not game_over and not round_active and not _is_intro_active():
			_open_spin_choice()
			get_viewport().set_input_as_handled()

func _request_slot_machine_action() -> void:
	if game_over or _is_intro_active():
		return

	if _popup_open():
		return

	if game_root != null and game_root.has_method("_request_spin"):
		game_root.call("_request_spin")
		return

	if slot_ui != null and slot_ui.has_method("request_spin"):
		slot_ui.call("request_spin")

func _deposit_to_debt_machine() -> void:
	if game_over or deposited >= debt_target:
		return

	var available: int = _get_money()
	if available <= 0:
		return

	var amount: int = mini(deposit_step, available)
	amount = mini(amount, debt_target - deposited)
	if amount <= 0:
		return

	if not _spend_money(amount):
		return

	_play_debt_button_press()
	deposited += amount
	if deposited >= debt_target and not early_bonus_given and rounds_left > 0:
		_add_tickets(rounds_left)
		early_bonus_given = true
	_update_debt_ui()

func _is_debt_button_hit(collider: Node) -> bool:
	if collider == null:
		return false

	if debt_button_area == null:
		return true

	if _node_matches_area(collider, debt_button_area):
		return true

	var button_keywords: Array[String] = [
		"button",
		"btn",
		"knop",
		"кноп",
		"deposit",
		"pay",
		"coin",
		"insert",
		"внос",
	]

	var current: Node = collider
	while current != null:
		if current == debt_machine:
			break
		var low: String = current.name.to_lower()
		for key: String in button_keywords:
			if low.contains(key):
				return true
		current = current.get_parent()

	return false

func _find_debt_button_area() -> Area3D:
	if debt_machine == null:
		return null

	var direct: Area3D = debt_machine.get_node_or_null(str(debt_button_area_name)) as Area3D
	if direct != null:
		return direct

	var candidates: Array[String] = [
		"ButtonArea",
		"ButtonInteractArea",
		"DepositArea",
		"PayButtonArea",
	]
	for path: String in candidates:
		var area: Area3D = debt_machine.get_node_or_null(path) as Area3D
		if area != null:
			return area

	return _find_area_by_name_part(debt_machine, ["button", "deposit", "pay", "coin", "insert"])

func _find_area_by_name_part(root: Node, parts: Array[String]) -> Area3D:
	for child: Node in root.get_children():
		var area: Area3D = child as Area3D
		if area != null:
			var low: String = area.name.to_lower()
			for part: String in parts:
				if low.contains(part):
					return area
		var nested: Area3D = _find_area_by_name_part(child, parts)
		if nested != null:
			return nested
	return null

func _play_debt_button_press() -> void:
	var anim: AnimationPlayer = null

	if debt_button_animation_player_path != NodePath(""):
		anim = get_node_or_null(debt_button_animation_player_path) as AnimationPlayer

	if anim == null and debt_machine != null:
		anim = _find_animation_player(debt_machine)

	if anim == null:
		anim = _find_animation_player(self)

	if anim == null:
		return

	var chosen: StringName = &""
	if not debt_button_animation_name.is_empty() and anim.has_animation(StringName(debt_button_animation_name)):
		chosen = StringName(debt_button_animation_name)
	else:
		var prefer_parts: Array[String] = ["button", "press", "deposit", "pay", "coin", "tap"]
		for name_var: Variant in anim.get_animation_list():
			var name_s: String = str(name_var)
			var low: String = name_s.to_lower()
			for part: String in prefer_parts:
				if low.contains(part):
					chosen = StringName(name_s)
					break
			if chosen != &"":
				break

		if chosen == &"":
			var all: PackedStringArray = anim.get_animation_list()
			if not all.is_empty():
				chosen = StringName(all[0])

	if chosen != &"":
		anim.play(chosen)

func _find_animation_player(root: Node) -> AnimationPlayer:
	for child: Node in root.get_children():
		var anim: AnimationPlayer = child as AnimationPlayer
		if anim != null:
			return anim
		var nested: AnimationPlayer = _find_animation_player(child)
		if nested != null:
			return nested
	return null

func _ensure_popup() -> void:
	if slot_ui == null:
		return

	popup = slot_ui.get_node_or_null("SpinChoicePopup") as Control
	if popup == null:
		popup = Control.new()
		popup.name = "SpinChoicePopup"
		slot_ui.add_child(popup)

	var popup_script: Script = load("res://Materials/spin_choice_popup.gd")
	if popup.get_script() != popup_script:
		popup.set_script(popup_script)

	if popup.has_method("_ensure_ui"):
		popup.call("_ensure_ui")
	popup.visible = false

func _ensure_debt_viewport_ui() -> void:
	debt_viewport = game_root.get_node_or_null("DebtViewport") as SubViewport
	if debt_viewport == null:
		debt_viewport = SubViewport.new()
		debt_viewport.name = "DebtViewport"
		game_root.add_child(debt_viewport)

	debt_viewport.size = Vector2i(640, 400)
	debt_viewport.transparent_bg = false
	debt_viewport.disable_3d = true
	debt_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	debt_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	debt_ui = debt_viewport.get_node_or_null("DebtUI") as Control
	if debt_ui == null:
		debt_ui = Control.new()
		debt_ui.name = "DebtUI"
		debt_viewport.add_child(debt_ui)

	var debt_ui_script: Script = load("res://Materials/debt_ui.gd")
	if debt_ui.get_script() != debt_ui_script:
		debt_ui.set_script(debt_ui_script)

	_apply_debt_viewport_to_screen()

func _apply_debt_viewport_to_screen() -> void:
	if debt_machine == null or debt_viewport == null:
		return

	var screen_mesh: MeshInstance3D = debt_machine.get_node_or_null("DebtScreen") as MeshInstance3D
	if screen_mesh == null:
		screen_mesh = _find_screen_mesh(debt_machine)

	var created_screen: bool = false
	if screen_mesh == null:
		screen_mesh = MeshInstance3D.new()
		screen_mesh.name = "DebtScreen"
		debt_machine.add_child(screen_mesh)
		created_screen = true

	if created_screen:
		var quad: QuadMesh = QuadMesh.new()
		quad.size = Vector2(0.70, 0.85)
		screen_mesh.mesh = quad
		screen_mesh.position = Vector3(-0.122, 1.596, -0.150)
		screen_mesh.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		screen_mesh.scale = Vector3.ONE
	elif screen_mesh.mesh == null:
		var fallback_quad: QuadMesh = QuadMesh.new()
		fallback_quad.size = Vector2(0.70, 0.85)
		screen_mesh.mesh = fallback_quad

	var viewport_tex: Texture2D = debt_viewport.get_texture()
	if viewport_tex == null:
		return

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = viewport_tex
	mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	mat.uv1_scale = Vector3(-1.0, -1.0, 1.0)
	mat.uv1_offset = Vector3(1.0, 1.0, 0.0)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.metallic = 0.0
	mat.roughness = 1.0
	screen_mesh.material_override = mat

func _ensure_interact_areas() -> void:
	debt_area = _ensure_machine_area(debt_machine)
	ticket_area = _ensure_machine_area(ticket_machine)
	debt_button_area = _find_debt_button_area()

func _ensure_machine_area(machine: Node3D) -> Area3D:
	if machine == null:
		return null

	var area: Area3D = machine.get_node_or_null("InteractArea") as Area3D
	if area == null:
		area = Area3D.new()
		area.name = "InteractArea"
		machine.add_child(area)

	area.input_ray_pickable = true
	area.monitoring = true
	area.monitorable = true

	var shape_node: CollisionShape3D = area.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node == null:
		shape_node = CollisionShape3D.new()
		shape_node.name = "CollisionShape3D"
		area.add_child(shape_node)

	if shape_node.shape == null:
		var box: BoxShape3D = BoxShape3D.new()
		box.size = Vector3(1.2, 1.2, 1.0)
		shape_node.shape = box
		shape_node.position = Vector3(0.0, 0.7, 0.0)

	return area

func _update_debt_ui() -> void:
	if debt_ui == null:
		return
	var interest_gain: int = _interest_amount()
	if debt_ui.has_method("set_data"):
		debt_ui.call("set_data", rounds_left, debt_target, deposited, interest_percent, interest_gain)

func _interest_amount() -> int:
	return maxi(int(floor((float(deposited) * interest_percent) / 100.0)), 0)

func _is_intro_active() -> bool:
	if intro_overlay == null or not intro_overlay.has_method("is_active"):
		return false
	return bool(intro_overlay.call("is_active"))

func _set_slot_locked(locked: bool) -> void:
	if slot_ui == null:
		return
	if slot_ui.has_method("set_input_locked"):
		slot_ui.call("set_input_locked", locked)
	else:
		slot_ui.set("input_locked", locked)

func _set_choice_overlay(active: bool) -> void:
	if slot_ui == null:
		return
	if slot_ui.has_method("set_choice_overlay_active"):
		slot_ui.call("set_choice_overlay_active", active)

func _get_hud() -> Dictionary:
	if slot_ui == null:
		return {"money": 0, "spins_left": 0, "tickets": 0}
	if slot_ui.has_method("get_hud_state"):
		return slot_ui.call("get_hud_state") as Dictionary
	return {"money": int(slot_ui.get("money")), "spins_left": int(slot_ui.get("spins_left")), "tickets": int(slot_ui.get("tickets"))}

func _get_money() -> int:
	if slot_ui != null and slot_ui.has_method("get_money"):
		return int(slot_ui.call("get_money"))
	return int(_get_hud().get("money", 0))

func _get_spins_left() -> int:
	if slot_ui != null and slot_ui.has_method("get_spins_left"):
		return int(slot_ui.call("get_spins_left"))
	return int(_get_hud().get("spins_left", 0))

func _spend_money(amount: int) -> bool:
	if slot_ui == null:
		return false
	if slot_ui.has_method("spend_money"):
		return bool(slot_ui.call("spend_money", amount))
	var money: int = _get_money()
	if money < amount:
		return false
	slot_ui.set("money", money - amount)
	if slot_ui.has_method("_emit_hud_changed"):
		slot_ui.call("_emit_hud_changed")
	return true

func _add_money(amount: int) -> void:
	if slot_ui == null:
		return
	if slot_ui.has_method("add_money"):
		slot_ui.call("add_money", amount)
		return
	slot_ui.set("money", maxi(_get_money() + amount, 0))
	if slot_ui.has_method("_emit_hud_changed"):
		slot_ui.call("_emit_hud_changed")

func _add_tickets(amount: int) -> void:
	if slot_ui == null:
		return
	if slot_ui.has_method("add_tickets"):
		slot_ui.call("add_tickets", amount)
		return
	var hud: Dictionary = _get_hud()
	slot_ui.set("tickets", maxi(int(hud.get("tickets", 0)) + amount, 0))
	if slot_ui.has_method("_emit_hud_changed"):
		slot_ui.call("_emit_hud_changed")

func _set_spins_left(amount: int) -> void:
	if slot_ui == null:
		return
	if slot_ui.has_method("set_spins_left"):
		slot_ui.call("set_spins_left", amount)
		return
	slot_ui.set("spins_left", maxi(amount, 0))
	if slot_ui.has_method("_emit_hud_changed"):
		slot_ui.call("_emit_hud_changed")

func _find_machine(names: Array[String]) -> Node3D:
	for n: String in names:
		var node: Node3D = game_root.get_node_or_null(n) as Node3D
		if node != null:
			return node
	return null

func _find_screen_mesh(root: Node) -> MeshInstance3D:
	for child: Node in root.get_children():
		var mesh: MeshInstance3D = child as MeshInstance3D
		if mesh != null:
			var low: String = mesh.name.to_lower()
			if low.contains("screen") or low.contains("display") or low.contains("monitor"):
				return mesh
		var nested: MeshInstance3D = _find_screen_mesh(child)
		if nested != null:
			return nested
	return null

func _node_matches_area(node: Node, area: Area3D) -> bool:
	if node == null or area == null:
		return false
	if node == area:
		return true
	return area.is_ancestor_of(node)

func _has_ancestor_named(node: Node, names: Array[String]) -> bool:
	var current: Node = node
	while current != null:
		for name: String in names:
			if current.name == name:
				return true
		current = current.get_parent()
	return false
