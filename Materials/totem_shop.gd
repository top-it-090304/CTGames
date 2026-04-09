extends Node3D

@export var buy_panel_path: NodePath = ^"../UI/TotemBuyPanel"
@export var shop_items_path: NodePath = ^"ShopItems"
@export var shop_spots_path: NodePath = ^"ShopSpots"
@export var owned_items_path: NodePath = ^"../TotemDisplay/OwnedItems"
@export var owned_spots_path: NodePath = ^"../TotemDisplay/OwnedSpots"
@export var slot_ui_path: NodePath = ^"../SubViewport/SlotUI"
@export var round_system_path: NodePath = ^"../RoundSystem"
@export var intro_overlay_path: NodePath = ^"../IntroOverlay"
@export var camera_path: NodePath = ^"../Camera3D"

var _buy_panel: Panel
var _shop_items: Node3D
var _shop_spots_root: Node3D
var _owned_items: Node3D
var _owned_spots_root: Node3D
var _slot_ui: Control
var _round_system: Node
var _intro_overlay: Node
var _camera_3d: Camera3D
var _selected_item: Node3D
var _owned_totems: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _owned_spot_used: Dictionary = {}
var _shop_spot_used: Dictionary = {}

func _ready() -> void:
	_rng.randomize()
	_buy_panel = get_node_or_null(buy_panel_path) as Panel
	_shop_items = get_node_or_null(shop_items_path) as Node3D
	_shop_spots_root = get_node_or_null(shop_spots_path) as Node3D
	_owned_items = get_node_or_null(owned_items_path) as Node3D
	_owned_spots_root = get_node_or_null(owned_spots_path) as Node3D
	_slot_ui = _resolve_slot_ui()
	_round_system = get_node_or_null(round_system_path)
	_intro_overlay = get_node_or_null(intro_overlay_path)
	_camera_3d = get_node_or_null(camera_path) as Camera3D

	_connect_buy_panel()
	_connect_items()
	_refresh_shop_layout()
	_refresh_panel_tokens()

func _resolve_slot_ui() -> Control:
	if slot_ui_path != NodePath("") and not slot_ui_path.is_empty():
		var direct: Control = get_node_or_null(slot_ui_path) as Control
		if direct != null:
			return direct
	# Fallback for scenes where the exported NodePath was cleared.
	var fallback: Control = get_node_or_null(^"../SubViewport/SlotUI") as Control
	if fallback != null:
		return fallback
	return get_parent().get_node_or_null("SubViewport/SlotUI") as Control

func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if get_viewport().is_input_handled():
		return

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_try_pick_item(mb.position)
		return

	if event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event as InputEventScreenTouch
		if st.pressed:
			_try_pick_item(st.position)

func _try_pick_item(screen_pos: Vector2) -> void:
	if not _can_interact():
		return
	if _camera_3d == null or _shop_items == null:
		return

	var from: Vector3 = _camera_3d.project_ray_origin(screen_pos)
	var to: Vector3 = from + _camera_3d.project_ray_normal(screen_pos) * 100.0
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return

	var collider: Node = result.get("collider") as Node
	if collider == null:
		return

	var item: Node3D = _resolve_item_from_collider(collider)
	if item == null:
		return

	_on_item_pressed(item)
	get_viewport().set_input_as_handled()

func _resolve_item_from_collider(collider: Node) -> Node3D:
	var current: Node = collider
	while current != null:
		if current == _shop_items:
			return null
		if current.get_parent() == _shop_items and current.has_method("get_offer_data"):
			return current as Node3D
		current = current.get_parent()
	return null

func _connect_buy_panel() -> void:
	if _buy_panel == null:
		return
	if _buy_panel.has_signal("buy_requested"):
		var buy_cb: Callable = Callable(self, "_on_buy_requested")
		if not _buy_panel.is_connected("buy_requested", buy_cb):
			_buy_panel.connect("buy_requested", buy_cb)
	if _buy_panel.has_signal("close_requested"):
		var close_cb: Callable = Callable(self, "_on_close_requested")
		if not _buy_panel.is_connected("close_requested", close_cb):
			_buy_panel.connect("close_requested", close_cb)

func _connect_items() -> void:
	if _shop_items == null:
		return
	for child: Node in _shop_items.get_children():
		var cb: Callable = Callable(self, "_on_item_pressed")
		if child.has_signal("pressed") and not child.is_connected("pressed", cb):
			child.connect("pressed", cb)

func _on_item_pressed(item: Node3D) -> void:
	if not _can_interact():
		return
	if item == null or not is_instance_valid(item):
		return
	_selected_item = item
	if _buy_panel != null and _buy_panel.has_method("show_offer"):
		_buy_panel.call("show_offer", item.call("get_offer_data"), _current_tokens())

func _on_buy_requested() -> void:
	if _selected_item == null or not is_instance_valid(_selected_item):
		return
	if _slot_ui == null or not _slot_ui.has_method("spend_tickets"):
		return

	var offer: Dictionary = _selected_item.call("get_offer_data") as Dictionary
	var totem_id: String = String(offer.get("id", ""))
	var price: int = int(offer.get("price", 0))
	if totem_id.is_empty() or _owned_totems.has(totem_id):
		return
	if not bool(_slot_ui.call("spend_tickets", price)):
		_refresh_panel_tokens()
		return

	_owned_totems[totem_id] = true
	if _slot_ui.has_method("add_totem_bonus"):
		_slot_ui.call(
			"add_totem_bonus",
			totem_id,
			String(offer.get("bonus_type", "")),
			int(offer.get("bonus_value", 0))
		)

	if _selected_item.has_method("set_shop_enabled"):
		_selected_item.call("set_shop_enabled", false)

	_move_item_to_owned_display(_selected_item)
	_refresh_shop_layout()
	_selected_item = null
	if _buy_panel != null and _buy_panel.has_method("hide_panel"):
		_buy_panel.call("hide_panel")

func _on_close_requested() -> void:
	_selected_item = null

func _move_item_to_owned_display(item: Node3D) -> void:
	if item == null or _owned_items == null:
		return
	var item_scale: Vector3 = item.scale
	item.reparent(_owned_items, true)
	var target_spot: Marker3D = _pick_owned_spot()
	if target_spot != null:
		var local_offset: Vector3 = Vector3.ZERO
		var rot_offset: Vector3 = Vector3.ZERO
		if item.has_method("get"):
			local_offset = item.get("owned_position_offset") as Vector3
			rot_offset = item.get("owned_rotation_offset_degrees") as Vector3
		var basis_no_scale: Basis = target_spot.global_transform.basis.orthonormalized()
		item.global_position = target_spot.global_position + (basis_no_scale * local_offset)
		# Keep the item's original orientation (as authored in the scene),
		# and only apply optional per-item offset.
		if item.has_method("get_base_global_rotation_degrees"):
			item.global_rotation_degrees = item.call("get_base_global_rotation_degrees") as Vector3 + rot_offset
		else:
			item.global_rotation_degrees = item.global_rotation_degrees + rot_offset
	item.scale = item_scale

func _pick_owned_spot() -> Marker3D:
	if _owned_spots_root == null:
		return null
	var spots: Array[Marker3D] = []
	for child: Node in _owned_spots_root.get_children():
		var marker: Marker3D = child as Marker3D
		if marker != null:
			spots.append(marker)
	if spots.is_empty():
		return null
	# Prefer free spots to avoid stacking items on the same marker.
	var free: Array[Marker3D] = []
	for s: Marker3D in spots:
		if not _owned_spot_used.has(s.get_instance_id()):
			free.append(s)
	if free.is_empty():
		return spots[_rng.randi_range(0, spots.size() - 1)]
	var chosen: Marker3D = free[_rng.randi_range(0, free.size() - 1)]
	_owned_spot_used[chosen.get_instance_id()] = true
	return chosen

func _current_tokens() -> int:
	if _slot_ui != null and _slot_ui.has_method("get_tickets"):
		return int(_slot_ui.call("get_tickets"))
	return 0

func _refresh_panel_tokens() -> void:
	if _buy_panel != null and _buy_panel.has_method("refresh_tokens"):
		_buy_panel.call("refresh_tokens", _current_tokens())

func _can_interact() -> bool:
	if _buy_panel != null and _buy_panel.has_method("is_open") and bool(_buy_panel.call("is_open")):
		return false
	if _intro_overlay != null and _intro_overlay.has_method("is_active") and bool(_intro_overlay.call("is_active")):
		return false
	if _round_system != null and _round_system.has_method("is_popup_open") and bool(_round_system.call("is_popup_open")):
		return false
	return true

func _refresh_shop_layout() -> void:
	# Randomly place up to 3 not-owned items into ShopSpot1-3.
	if _shop_items == null:
		return
	_shop_spot_used.clear()
	if _shop_spots_root == null:
		# No spots: just enable everything that's not owned.
		for child: Node in _shop_items.get_children():
			var item: Node3D = child as Node3D
			if item == null or not item.has_method("get_offer_data"):
				continue
			var offer: Dictionary = item.call("get_offer_data") as Dictionary
			var totem_id: String = String(offer.get("id", ""))
			var enable: bool = not totem_id.is_empty() and not _owned_totems.has(totem_id)
			if item.has_method("set_shop_enabled"):
				item.call("set_shop_enabled", enable)
		return

	var spots: Array[Marker3D] = []
	for child: Node in _shop_spots_root.get_children():
		var m: Marker3D = child as Marker3D
		if m != null and String(m.name).to_lower().begins_with("shopspot"):
			spots.append(m)
	spots.sort_custom(func(a: Marker3D, b: Marker3D) -> bool:
		return String(a.name) < String(b.name)
	)

	var candidates: Array[Node3D] = []
	for child: Node in _shop_items.get_children():
		var item: Node3D = child as Node3D
		if item == null or not item.has_method("get_offer_data"):
			continue
		var offer: Dictionary = item.call("get_offer_data") as Dictionary
		var totem_id: String = String(offer.get("id", ""))
		if totem_id.is_empty() or _owned_totems.has(totem_id):
			if item.has_method("set_shop_enabled"):
				item.call("set_shop_enabled", false)
			continue
		candidates.append(item)

	# Disable all by default, then enable only chosen.
	for item: Node3D in candidates:
		if item.has_method("set_shop_enabled"):
			item.call("set_shop_enabled", false)

	if candidates.is_empty() or spots.is_empty():
		return

	candidates.shuffle()
	var show_count: int = mini(3, mini(candidates.size(), spots.size()))
	for i: int in range(show_count):
		var item: Node3D = candidates[i]
		var spot: Marker3D = spots[i]
		# IMPORTANT: ShopSpot markers are scaled in the scene (often x20),
		# so copying full transforms will skew the item. Copy only position + rotation.
		var keep_scale: Vector3 = item.scale
		var local_offset: Vector3 = Vector3.ZERO
		var rot_offset: Vector3 = Vector3.ZERO
		if item.has_method("get"):
			var placement: Dictionary = _resolve_shop_placement_for_spot(item, i)
			local_offset = placement.get("position", Vector3.ZERO) as Vector3
			rot_offset = placement.get("rotation", Vector3.ZERO) as Vector3
		var basis_no_scale: Basis = spot.global_transform.basis.orthonormalized()
		item.global_position = spot.global_position + (basis_no_scale * local_offset)
		# Preserve authored orientation for nicer display.
		if item.has_method("get_base_global_rotation_degrees"):
			item.global_rotation_degrees = item.call("get_base_global_rotation_degrees") as Vector3 + rot_offset
		else:
			item.global_rotation_degrees = item.global_rotation_degrees + rot_offset
		item.scale = keep_scale
		if item.has_method("set_shop_enabled"):
			item.call("set_shop_enabled", true)

func _resolve_shop_placement_for_spot(item: Node3D, spot_index: int) -> Dictionary:
	var fallback_pos: Vector3 = item.get("shop_position_offset") as Vector3
	var fallback_rot: Vector3 = item.get("shop_rotation_offset_degrees") as Vector3
	if not bool(item.get("use_shop_spot_overrides")):
		return {"position": fallback_pos, "rotation": fallback_rot}
	match spot_index:
		0:
			return {
				"position": item.get("shop_position_offset_spot1") as Vector3,
				"rotation": item.get("shop_rotation_offset_degrees_spot1") as Vector3,
			}
		1:
			return {
				"position": item.get("shop_position_offset_spot2") as Vector3,
				"rotation": item.get("shop_rotation_offset_degrees_spot2") as Vector3,
			}
		2:
			return {
				"position": item.get("shop_position_offset_spot3") as Vector3,
				"rotation": item.get("shop_rotation_offset_degrees_spot3") as Vector3,
			}
	return {"position": fallback_pos, "rotation": fallback_rot}
