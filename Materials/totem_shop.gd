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
@export var randomize_shop_items: bool = false
@export_range(1, 12, 1) var max_visible_shop_items: int = 3
@export_group("Auto Placement")
@export var auto_snap_shop_items_to_spot_surface: bool = true
@export var auto_snap_owned_items_to_spot_surface: bool = true
@export var snap_surface_lift: float = 0.0
@export_group("Catalog")
@export var spawn_catalog_totems_on_ready: bool = false
@export var clear_spawned_catalog_totems: bool = false
@export var catalog_totem_scenes: Array[PackedScene] = []

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
var _current_shop_offers: Array[Node3D] = []

# UI display for OWNED totems
var _owned_ui_root: Control
var _owned_ui_row: HBoxContainer

const _CARD_W := 110.0
const _CARD_H := 110.0
const _CARD_GAP := 10.0
const _BAR_PAD := 12.0

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

	_spawn_catalog_totems_if_needed()
	_ensure_owned_ui()
	_connect_buy_panel()
	_connect_items()
	_refresh_shop_layout()
	_refresh_panel_tokens()

func _resolve_slot_ui() -> Control:
	if slot_ui_path != NodePath("") and not slot_ui_path.is_empty():
		var direct: Control = get_node_or_null(slot_ui_path) as Control
		if direct != null:
			return direct
	var fallback: Control = get_node_or_null(^"../SubViewport/SlotUI") as Control
	if fallback != null:
		return fallback
	return get_parent().get_node_or_null("SubViewport/SlotUI") as Control

# ─── 3D input ────────────────────────────────────────────────────────────────

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
		if current is Node3D and current.has_method("get_offer_data"):
			return current as Node3D
		current = current.get_parent()
	return null

# ─── Buy panel ───────────────────────────────────────────────────────────────

func _connect_buy_panel() -> void:
	if _buy_panel == null:
		return
	if _buy_panel.has_signal("buy_requested"):
		var cb: Callable = Callable(self, "_on_buy_requested")
		if not _buy_panel.is_connected("buy_requested", cb):
			_buy_panel.connect("buy_requested", cb)
	if _buy_panel.has_signal("close_requested"):
		var cb: Callable = Callable(self, "_on_close_requested")
		if not _buy_panel.is_connected("close_requested", cb):
			_buy_panel.connect("close_requested", cb)

func _connect_items() -> void:
	if _shop_items == null:
		return
	for child: Node3D in _collect_shop_totem_items():
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
	var world: Node = get_parent()
	if world != null and world.has_method("_update_ready_button_visibility"):
		world.call_deferred("_update_ready_button_visibility")

	_owned_totems[totem_id] = true
	if _slot_ui.has_method("add_totem_bonus"):
		var bonuses_var: Variant = offer.get("bonuses", [])
		if bonuses_var is Array and not (bonuses_var as Array).is_empty():
			var idx: int = 0
			for bonus_var: Variant in (bonuses_var as Array):
				if not (bonus_var is Dictionary):
					continue
				var bonus: Dictionary = bonus_var as Dictionary
				_slot_ui.call(
					"add_totem_bonus",
					"%s#%d" % [totem_id, idx],
					String(bonus.get("type", "")),
					int(bonus.get("value", 0))
				)
				idx += 1
		else:
			_slot_ui.call(
				"add_totem_bonus",
				totem_id,
				String(offer.get("bonus_type", "")),
				int(offer.get("bonus_value", 0))
			)

	if _selected_item.has_method("set_shop_enabled"):
		_selected_item.call("set_shop_enabled", false)

	_move_item_to_owned_display(_selected_item)
	_add_owned_totem_card(offer)
	_refresh_shop_layout()
	_selected_item = null
	if _buy_panel != null and _buy_panel.has_method("hide_panel"):
		_buy_panel.call("hide_panel")
	_refresh_panel_tokens()

func _on_close_requested() -> void:
	_selected_item = null

# ─── 3D Shop layout (места на столе) ─────────────────────────────────────────

func _refresh_shop_layout() -> void:
	if _shop_items == null:
		return
	_shop_spot_used.clear()
	_current_shop_offers.clear()
	if _shop_spots_root == null:
		var fallback_candidates: Array[Node3D] = []
		for item: Node3D in _collect_shop_totem_items():
			var offer: Dictionary = item.call("get_offer_data") as Dictionary
			var totem_id: String = String(offer.get("id", ""))
			var enable: bool = not totem_id.is_empty() and not _owned_totems.has(totem_id)
			_set_shop_item_active(item, enable)
			if enable:
				fallback_candidates.append(item)
		if randomize_shop_items:
			fallback_candidates.shuffle()
		var fallback_count: int = mini(maxi(max_visible_shop_items, 1), fallback_candidates.size())
		for i: int in range(fallback_count):
			_current_shop_offers.append(fallback_candidates[i])
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
	for item: Node3D in _collect_shop_totem_items():
		var offer: Dictionary = item.call("get_offer_data") as Dictionary
		var totem_id: String = String(offer.get("id", ""))
		if totem_id.is_empty() or _owned_totems.has(totem_id):
			if item.has_method("set_shop_enabled"):
				item.call("set_shop_enabled", false)
			continue
		candidates.append(item)

	for item: Node3D in candidates:
		_set_shop_item_active(item, false)

	if candidates.is_empty() or spots.is_empty():
		return

	if randomize_shop_items:
		candidates.shuffle()
	var show_count: int = mini(maxi(max_visible_shop_items, 1), mini(candidates.size(), spots.size()))
	for i: int in range(show_count):
		var item: Node3D = candidates[i]
		var spot: Marker3D = spots[i]
		_current_shop_offers.append(item)
		var keep_scale: Vector3 = item.scale
		var local_offset: Vector3 = Vector3.ZERO
		var rot_offset: Vector3 = Vector3.ZERO
		if item.has_method("get"):
			var placement: Dictionary = _resolve_shop_placement_for_spot(item, i)
			local_offset = placement.get("position", Vector3.ZERO) as Vector3
			rot_offset = placement.get("rotation", Vector3.ZERO) as Vector3
		var basis_no_scale: Basis = spot.global_transform.basis.orthonormalized()
		item.global_position = spot.global_position + (basis_no_scale * local_offset)
		if item.has_method("get_base_global_rotation_degrees"):
			item.global_rotation_degrees = item.call("get_base_global_rotation_degrees") as Vector3 + rot_offset
		else:
			item.global_rotation_degrees = item.global_rotation_degrees + rot_offset
		if auto_snap_shop_items_to_spot_surface:
			_snap_item_to_surface_y(item, spot.global_position.y)
		item.scale = keep_scale
		_set_shop_item_active(item, true)

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

func _set_shop_item_active(item: Node3D, active: bool) -> void:
	if item == null:
		return
	if item.has_method("set_shop_enabled"):
		item.call("set_shop_enabled", active)
	else:
		item.visible = active

# ─── Owned display (UI квадратики) ───────────────────────────────────────────

func _ensure_owned_ui() -> void:
	var root_ui: Node = get_parent().get_node_or_null("UI")
	if root_ui == null:
		return

	_owned_ui_root = root_ui.get_node_or_null("TotemOwnedUI") as Control
	if _owned_ui_root == null:
		_owned_ui_root = Control.new()
		_owned_ui_root.name = "TotemOwnedUI"
		root_ui.add_child(_owned_ui_root)
	_owned_ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_owned_ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_owned_ui_root.z_index = 130

	# Фоновая панель — снизу по центру
	var panel: Panel = _owned_ui_root.get_node_or_null("OwnedPanel") as Panel
	if panel == null:
		panel = Panel.new()
		panel.name = "OwnedPanel"
		_owned_ui_root.add_child(panel)
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_top = -(_CARD_H + _BAR_PAD * 2.0 + 24.0)
	panel.offset_bottom = 0.0
	panel.offset_left = 0.0
	panel.offset_right = 0.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.visible = false  # скрыта пока нет купленных

	# Лейбл "Тотемы"
	var title_lbl: Label = panel.get_node_or_null("TitleLabel") as Label
	if title_lbl == null:
		title_lbl = Label.new()
		title_lbl.name = "TitleLabel"
		panel.add_child(title_lbl)
	title_lbl.text = "Тотемы:"
	title_lbl.anchor_left = 0.0
	title_lbl.anchor_right = 0.0
	title_lbl.anchor_top = 0.0
	title_lbl.anchor_bottom = 0.0
	title_lbl.offset_left = _BAR_PAD
	title_lbl.offset_top = 4.0
	title_lbl.offset_right = 120.0
	title_lbl.offset_bottom = 24.0
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Ряд карточек
	var row: HBoxContainer = panel.get_node_or_null("CardsRow") as HBoxContainer
	if row == null:
		row = HBoxContainer.new()
		row.name = "CardsRow"
		panel.add_child(row)
	row.anchor_left = 0.0
	row.anchor_right = 1.0
	row.anchor_top = 0.0
	row.anchor_bottom = 1.0
	row.offset_left = _BAR_PAD
	row.offset_top = 24.0
	row.offset_right = -_BAR_PAD
	row.offset_bottom = -_BAR_PAD
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_theme_constant_override("separation", int(_CARD_GAP))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_owned_ui_row = row

func _add_owned_totem_card(offer: Dictionary) -> void:
	if _owned_ui_root == null or _owned_ui_row == null:
		_ensure_owned_ui()
	if _owned_ui_row == null:
		return

	var title_s: String = String(offer.get("title", "?"))
	var desc_s: String = String(offer.get("description", ""))

	# Квадратная карточка
	var card := Panel.new()
	card.custom_minimum_size = Vector2(_CARD_W, _CARD_H)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_owned_ui_row.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 6.0
	vbox.offset_top = 6.0
	vbox.offset_right = -6.0
	vbox.offset_bottom = -6.0
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(vbox)

	var name_lbl := Label.new()
	name_lbl.text = title_s
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_lbl)

	if not desc_s.is_empty():
		var desc_lbl := Label.new()
		desc_lbl.text = desc_s
		desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.add_theme_font_size_override("font_size", 10)
		desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(desc_lbl)

	# Показываем панель
	var panel: Panel = _owned_ui_root.get_node_or_null("OwnedPanel") as Panel
	if panel != null:
		panel.visible = true

# ─── Owned display (3D перемещение) ──────────────────────────────────────────

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
		if item.has_method("get_base_global_rotation_degrees"):
			item.global_rotation_degrees = item.call("get_base_global_rotation_degrees") as Vector3 + rot_offset
		else:
			item.global_rotation_degrees = item.global_rotation_degrees + rot_offset
		if auto_snap_owned_items_to_spot_surface:
			_snap_item_to_surface_y(item, target_spot.global_position.y)
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
	var free: Array[Marker3D] = []
	for s: Marker3D in spots:
		if not _owned_spot_used.has(s.get_instance_id()):
			free.append(s)
	if free.is_empty():
		return spots[_rng.randi_range(0, spots.size() - 1)]
	var chosen: Marker3D = free[_rng.randi_range(0, free.size() - 1)]
	_owned_spot_used[chosen.get_instance_id()] = true
	return chosen

# ─── Tokens ───────────────────────────────────────────────────────────────────

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

# ─── Catalog ──────────────────────────────────────────────────────────────────

func _spawn_catalog_totems_if_needed() -> void:
	if not spawn_catalog_totems_on_ready or _shop_items == null:
		return
	if clear_spawned_catalog_totems:
		for child: Node in _shop_items.get_children():
			if child.has_meta("catalog_spawned"):
				child.queue_free()
	var existing_ids: Dictionary = {}
	for item: Node3D in _collect_shop_totem_items():
		var offer: Dictionary = item.call("get_offer_data") as Dictionary
		var id_s: String = String(offer.get("id", "")).strip_edges()
		if not id_s.is_empty():
			existing_ids[id_s] = true
	for scene: PackedScene in catalog_totem_scenes:
		if scene == null:
			continue
		var instance: Node = scene.instantiate()
		var item: Node3D = _resolve_catalog_totem_node(instance)
		if item == null:
			if instance != null:
				instance.queue_free()
			continue
		var offer: Dictionary = item.call("get_offer_data") as Dictionary
		var id_s: String = String(offer.get("id", "")).strip_edges()
		if id_s.is_empty() or existing_ids.has(id_s):
			if instance != null:
				instance.queue_free()
			continue
		_shop_items.add_child(instance)
		instance.set_meta("catalog_spawned", true)
		existing_ids[id_s] = true

func _resolve_catalog_totem_node(instance: Node) -> Node3D:
	if instance == null:
		return null
	if instance is Node3D and instance.has_method("get_offer_data"):
		return instance as Node3D
	var stack: Array[Node] = [instance]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Node3D and node.has_method("get_offer_data"):
			return node as Node3D
		for child: Node in node.get_children():
			stack.append(child)
	return null

# ─── Utility ──────────────────────────────────────────────────────────────────

func _collect_shop_totem_items() -> Array[Node3D]:
	var out: Array[Node3D] = []
	if _shop_items == null:
		return out
	var stack: Array[Node] = [_shop_items]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node != _shop_items and node is Node3D and node.has_method("get_offer_data"):
			out.append(node as Node3D)
		for child: Node in node.get_children():
			stack.append(child)
	return out

func _snap_item_to_surface_y(item: Node3D, target_surface_y: float) -> void:
	if item == null:
		return
	var bounds: AABB = _compute_world_mesh_aabb(item)
	if bounds.size == Vector3.ZERO:
		return
	var delta_y: float = target_surface_y - bounds.position.y + snap_surface_lift
	item.global_position.y += delta_y

func _compute_world_mesh_aabb(root: Node3D) -> AABB:
	var has_bounds: bool = false
	var merged := AABB()
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		var mesh_node: MeshInstance3D = node as MeshInstance3D
		if mesh_node != null and mesh_node.mesh != null:
			var mesh_aabb: AABB = mesh_node.mesh.get_aabb()
			if mesh_aabb.size != Vector3.ZERO:
				var world_aabb: AABB = _transform_aabb(mesh_aabb, mesh_node.global_transform)
				if not has_bounds:
					merged = world_aabb
					has_bounds = true
				else:
					merged = merged.merge(world_aabb)
		for child: Node in node.get_children():
			stack.append(child)
	return merged if has_bounds else AABB()

func _transform_aabb(aabb: AABB, xform: Transform3D) -> AABB:
	var corners: Array[Vector3] = [
		Vector3(aabb.position.x, aabb.position.y, aabb.position.z),
		Vector3(aabb.end.x, aabb.position.y, aabb.position.z),
		Vector3(aabb.position.x, aabb.end.y, aabb.position.z),
		Vector3(aabb.position.x, aabb.position.y, aabb.end.z),
		Vector3(aabb.end.x, aabb.end.y, aabb.position.z),
		Vector3(aabb.end.x, aabb.position.y, aabb.end.z),
		Vector3(aabb.position.x, aabb.end.y, aabb.end.z),
		Vector3(aabb.end.x, aabb.end.y, aabb.end.z),
	]
	var first: Vector3 = xform * corners[0]
	var out := AABB(first, Vector3.ZERO)
	for i: int in range(1, corners.size()):
		out = out.expand(xform * corners[i])
	return out
