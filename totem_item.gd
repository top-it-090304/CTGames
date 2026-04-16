extends Node3D

signal pressed(item: Node3D)

@export var totem_id: String = "cat"
@export var title: String = "Cat"
@export_multiline var description: String = "+1 F to any win"
@export var price_tokens: int = 3

@export_group("Bonuses")
@export var bonus_type: String = "flat_win_bonus"
@export var bonus_value: int = 1
@export_multiline var extra_bonuses: String = ""

@export_group("Interaction")
@export var interact_area_path: NodePath = ^"InteractArea"
@export var auto_create_interact_area: bool = true
@export var generated_area_padding: Vector3 = Vector3(0.06, 0.08, 0.06)

@export_group("Placement")
@export var shop_position_offset: Vector3 = Vector3.ZERO
@export var shop_rotation_offset_degrees: Vector3 = Vector3.ZERO
@export var owned_position_offset: Vector3 = Vector3.ZERO
@export var owned_rotation_offset_degrees: Vector3 = Vector3.ZERO

@export_group("Placement By Shop Spot")
@export var use_shop_spot_overrides: bool = false
@export var shop_position_offset_spot1: Vector3 = Vector3.ZERO
@export var shop_position_offset_spot2: Vector3 = Vector3.ZERO
@export var shop_position_offset_spot3: Vector3 = Vector3.ZERO
@export var shop_rotation_offset_degrees_spot1: Vector3 = Vector3.ZERO
@export var shop_rotation_offset_degrees_spot2: Vector3 = Vector3.ZERO
@export var shop_rotation_offset_degrees_spot3: Vector3 = Vector3.ZERO

var _interact_area: Area3D
var _shop_enabled: bool = true
var _base_global_rotation_degrees: Vector3
var _base_scale: Vector3

func _ready() -> void:
	_base_global_rotation_degrees = global_rotation_degrees
	_base_scale = scale
	_interact_area = get_node_or_null(interact_area_path) as Area3D
	if _interact_area == null:
		_interact_area = _find_first_area3d(self)
	if _interact_area == null and auto_create_interact_area:
		_interact_area = _create_generated_interact_area()
	if _interact_area == null:
		push_warning("Totem item '%s' has no InteractArea" % name)
		return
	_interact_area.input_ray_pickable = true
	var cb: Callable = Callable(self, "_on_interact_input_event")
	if not _interact_area.input_event.is_connected(cb):
		_interact_area.input_event.connect(cb)

func get_base_global_rotation_degrees() -> Vector3:
	return _base_global_rotation_degrees

func get_base_scale() -> Vector3:
	return _base_scale

func _find_first_area3d(root: Node) -> Area3D:
	for child: Node in root.get_children():
		var area: Area3D = child as Area3D
		if area != null:
			return area
		var nested: Area3D = _find_first_area3d(child)
		if nested != null:
			return nested
	return null

func get_offer_data() -> Dictionary:
	return {
		"id": totem_id,
		"title": title,
		"description": description,
		"price": maxi(price_tokens, 0),
		"bonus_type": bonus_type,
		"bonus_value": bonus_value,
		"bonuses": get_bonus_entries(),
	}

func get_bonus_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	_append_bonus_entry(out, bonus_type, bonus_value)
	for line_raw: String in extra_bonuses.split("\n"):
		var line: String = line_raw.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var parts: PackedStringArray = line.split("=", false, 1)
		var parsed_type: String = String(parts[0]).strip_edges()
		var parsed_value: int = 0
		if parts.size() >= 2:
			parsed_value = int(String(parts[1]).strip_edges())
		_append_bonus_entry(out, parsed_type, parsed_value)
	return out

func _append_bonus_entry(out: Array[Dictionary], type_s: String, value_i: int) -> void:
	var key: String = type_s.strip_edges()
	if key.is_empty():
		return
	out.append({
		"type": key,
		"value": value_i,
	})

func set_shop_enabled(active: bool) -> void:
	_shop_enabled = active
	visible = active
	if _interact_area != null:
		_interact_area.input_ray_pickable = active

func _on_interact_input_event(
		_camera: Camera3D,
		event: InputEvent,
		_position: Vector3,
		_normal: Vector3,
		_shape_idx: int
	) -> void:
	if not _shop_enabled:
		return

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			emit_signal("pressed", self)
			get_viewport().set_input_as_handled()
		return

	if event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event as InputEventScreenTouch
		if st.pressed:
			emit_signal("pressed", self)
			get_viewport().set_input_as_handled()

func _create_generated_interact_area() -> Area3D:
	var local_aabb: AABB = _compute_local_mesh_aabb()
	if local_aabb.size == Vector3.ZERO:
		return null
	var area := Area3D.new()
	area.name = "InteractAreaAuto"
	add_child(area)
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3DAuto"
	area.add_child(col)
	var box := BoxShape3D.new()
	box.size = local_aabb.size + generated_area_padding * 2.0
	col.shape = box
	col.position = local_aabb.position + (local_aabb.size * 0.5)
	return area

func _compute_local_mesh_aabb() -> AABB:
	var has_bounds: bool = false
	var merged := AABB()
	var stack: Array[Node] = [self]
	var root_inverse: Transform3D = global_transform.affine_inverse()
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		var mesh_node: MeshInstance3D = node as MeshInstance3D
		if mesh_node != null and mesh_node.mesh != null:
			var mesh_aabb: AABB = mesh_node.mesh.get_aabb()
			if mesh_aabb.size != Vector3.ZERO:
				var local_xform: Transform3D = root_inverse * mesh_node.global_transform
				var transformed: AABB = _transform_aabb(mesh_aabb, local_xform)
				if not has_bounds:
					merged = transformed
					has_bounds = true
				else:
					merged = merged.merge(transformed)
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
