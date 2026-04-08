extends Node3D

const SYMBOL_KEYS: Array[String] = ["lemon", "cherry", "clover", "bell", "diamond", "chest", "seven"]
const SLOT_PREFIX: String = "_slot_"

@export var spin_acceleration: float = 60.0
@export var settle_snap_speed: float = 18.0
@export var spin_visible_padding: float = 1.2
@export var idle_visible_padding: float = 0.25
@export var slot_spacing_override: float = 0.0
@export var vertical_center_offset: float = 0.0
@export var symbol_scale_multiplier: float = 1.0

var _template_clones: Dictionary = {}
var _template_transforms: Dictionary = {}
var _slot_holders: Array[Node3D] = []
var _source_slot_origins: Array[Vector3] = []
var _slot_local_transforms: Array[Transform3D] = []
var _slot_positions: Array[float] = []
var _visible_indices: Array[int] = []
var _column_center: Vector3 = Vector3.ZERO

var _runtime_nodes: Array[Node3D] = []
var _runtime_keys: Array[String] = []

var _queue: Array[String] = []
var _delay_remaining: float = 0.0
var _spin_speed: float = 0.0
var _settle_speed: float = 0.0
var _current_speed: float = 0.0
var _current_offset: float = 0.0
var _spacing: float = 1.5
var _steps_remaining: int = 0
var _is_spinning: bool = false
var _is_settling: bool = false

func _ready() -> void:
	randomize()
	_setup_reel()

func _process(delta: float) -> void:
	if _delay_remaining > 0.0:
		_delay_remaining = maxf(0.0, _delay_remaining - delta)
		return
	if _is_spinning:
		_update_spin(delta)
	elif _is_settling:
		_update_settle(delta)

func sync_layout() -> void:
	_setup_reel(true)

func begin_spin(target_keys: Array, spin_speed: float, settle_speed: float, total_cycles: int, delay: float = 0.0) -> void:
	_setup_reel()
	clear_highlight()
	_spin_speed = maxf(spin_speed, 0.1)
	_settle_speed = maxf(settle_speed, 0.1)
	_current_speed = _spin_speed
	_delay_remaining = maxf(delay, 0.0)
	_current_offset = 0.0
	_steps_remaining = maxi(total_cycles, _max_visible_index() + 3)
	_queue = _build_queue(target_keys, _steps_remaining)
	_is_spinning = true
	_is_settling = false
	position.y = 0.0
	_apply_visibility(true)

func preview_symbols(target_keys: Array) -> void:
	_setup_reel()
	_is_spinning = false
	_is_settling = false
	_delay_remaining = 0.0
	_current_offset = 0.0
	position.y = 0.0
	var layout: Array[String] = _build_preview_layout(target_keys)
	for i: int in range(mini(layout.size(), _runtime_nodes.size())):
		_replace_symbol_at_index(i, layout[i])
	_apply_layout()
	_apply_visibility(false)

func highlight_row(row: int) -> void:
	clear_highlight()
	if row < 0 or row >= _visible_indices.size():
		return
	var slot_index: int = _visible_indices[row]
	if slot_index < 0 or slot_index >= _runtime_nodes.size():
		return
	var node: Node3D = _runtime_nodes[slot_index]
	if node != null:
		node.scale *= 1.12

func is_spinning() -> bool:
	return _is_spinning or _is_settling or _delay_remaining > 0.0

func clear_highlight() -> void:
	for i: int in range(mini(_runtime_nodes.size(), _runtime_keys.size())):
		var node: Node3D = _runtime_nodes[i]
		if node == null:
			continue
		var key: String = _runtime_keys[i]
		node.transform = _scaled_template_transform_for_key(key)

func _setup_reel(force: bool = false) -> void:
	if force:
		_template_clones.clear()
		_template_transforms.clear()
		_slot_holders.clear()
		_source_slot_origins.clear()
		_slot_local_transforms.clear()
		_slot_positions.clear()
		_visible_indices.clear()
		_runtime_nodes.clear()
		_runtime_keys.clear()
		_column_center = Vector3.ZERO
	if not _runtime_nodes.is_empty():
		return

	_slot_holders = _collect_slot_holders()
	if _slot_holders.is_empty():
		_slot_holders = _create_slot_holders_from_direct_children()
	if _slot_holders.is_empty():
		return

	_slot_holders.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return a.position.y > b.position.y
	)

	_source_slot_origins.clear()
	_slot_local_transforms.clear()
	_slot_positions.clear()
	_runtime_nodes.clear()
	_runtime_keys.clear()

	for holder: Node3D in _slot_holders:
		var holder_origin: Vector3 = holder.position
		holder.transform = Transform3D.IDENTITY
		holder.position = holder_origin
		_source_slot_origins.append(holder.position)
		var symbol: Node3D = _slot_symbol(holder)
		if symbol == null:
			continue
		symbol.transform.origin = Vector3.ZERO
		_slot_local_transforms.append(symbol.transform)
		var key: String = _symbol_key_from_node_name(symbol.name)
		if key.is_empty():
			continue
		if not _template_clones.has(key):
			var clone: Node3D = symbol.duplicate() as Node3D
			if clone != null:
				clone.visible = true
				clone.transform.origin = Vector3.ZERO
				_template_clones[key] = clone
				_template_transforms[key] = clone.transform
		_runtime_nodes.append(symbol)
		_runtime_keys.append(key)

	_column_center = _detect_column_center(_source_slot_origins)
	_apply_slot_positions()
	_visible_indices = _detect_visible_indices()
	_apply_layout()
	_apply_visibility(false)

func _collect_slot_holders() -> Array[Node3D]:
	var holders: Array[Node3D] = []
	for child: Node in get_children():
		var node_3d: Node3D = child as Node3D
		if node_3d != null and node_3d.name.begins_with(SLOT_PREFIX):
			holders.append(node_3d)
	return holders

func _create_slot_holders_from_direct_children() -> Array[Node3D]:
	var source_nodes: Array[Node3D] = []
	for child: Node in get_children():
		var node_3d: Node3D = child as Node3D
		if node_3d == null:
			continue
		if node_3d.name.begins_with(SLOT_PREFIX):
			continue
		var key: String = _symbol_key_from_node_name(node_3d.name)
		if key.is_empty():
			continue
		source_nodes.append(node_3d)

	source_nodes.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return a.position.y > b.position.y
	)

	var holders: Array[Node3D] = []
	for i: int in range(source_nodes.size()):
		var symbol: Node3D = source_nodes[i]
		var original_transform: Transform3D = symbol.transform
		var holder := Node3D.new()
		holder.name = "%s%02d" % [SLOT_PREFIX, i]
		add_child(holder)
		holder.transform = Transform3D.IDENTITY
		holder.position = original_transform.origin
		symbol.reparent(holder)
		symbol.transform = Transform3D(original_transform.basis, Vector3.ZERO)
		holders.append(holder)
	return holders

func _apply_slot_positions() -> void:
	_slot_positions.clear()
	if _slot_holders.is_empty():
		return
	var source_y_values: Array[float] = []
	for origin_value: Vector3 in _source_slot_origins:
		source_y_values.append(origin_value.y)
	_spacing = _detect_spacing_from_values(source_y_values)
	var middle_index: float = (float(_slot_holders.size()) - 1.0) * 0.5
	for i: int in range(_slot_holders.size()):
		var holder: Node3D = _slot_holders[i]
		var origin_value: Vector3 = _source_slot_origins[i]
		origin_value.x = _column_center.x
		origin_value.z = _column_center.z
		if slot_spacing_override > 0.0:
			origin_value.y = (middle_index - float(i)) * slot_spacing_override + vertical_center_offset
		else:
			origin_value.y = _source_slot_origins[i].y + vertical_center_offset
		holder.position = origin_value
		_slot_positions.append(origin_value.y)

func _build_preview_layout(target_keys: Array) -> Array[String]:
	var keys: Array[String] = []
	for _i: int in range(_runtime_nodes.size()):
		keys.append(_random_key())
	for row: int in range(mini(_visible_indices.size(), target_keys.size())):
		var slot_index: int = _visible_indices[row]
		keys[slot_index] = String(target_keys[row])
	return keys

func _build_queue(target_keys: Array, total_steps: int) -> Array[String]:
	var queue: Array[String] = []
	for _i: int in range(total_steps):
		queue.append(_random_key())
	for row: int in range(mini(_visible_indices.size(), target_keys.size())):
		var slot_index: int = _visible_indices[row]
		var queue_index: int = total_steps - slot_index - 1
		if queue_index >= 0 and queue_index < queue.size():
			queue[queue_index] = String(target_keys[row])
	return queue

func _update_spin(delta: float) -> void:
	_current_speed = move_toward(_current_speed, _spin_speed, spin_acceleration * delta)
	if _steps_remaining <= _max_visible_index() + 1:
		_current_speed = move_toward(_current_speed, _settle_speed, spin_acceleration * delta)
	_current_offset -= _current_speed * delta
	while _current_offset <= -_spacing and _steps_remaining > 0:
		_current_offset += _spacing
		_advance_step()
	position.y = _current_offset
	_apply_visibility(true)
	if _steps_remaining <= 0:
		_is_spinning = false
		_is_settling = true

func _update_settle(delta: float) -> void:
	_current_offset = move_toward(_current_offset, 0.0, _settle_speed * settle_snap_speed * delta)
	position.y = _current_offset
	_apply_visibility(true)
	if is_zero_approx(_current_offset):
		_current_offset = 0.0
		position.y = 0.0
		_is_settling = false
		_apply_visibility(false)

func _advance_step() -> void:
	if _queue.is_empty() or _runtime_nodes.is_empty():
		_steps_remaining = 0
		return
	var next_key: String = _queue.pop_front()
	var bottom_index: int = _runtime_nodes.size() - 1
	_replace_symbol_at_index(bottom_index, next_key)
	var recycled_node: Node3D = _runtime_nodes.pop_at(bottom_index)
	var recycled_key: String = _runtime_keys.pop_at(bottom_index)
	_runtime_nodes.push_front(recycled_node)
	_runtime_keys.push_front(recycled_key)
	_steps_remaining -= 1
	_apply_layout()

func _replace_symbol_at_index(index: int, key: String) -> void:
	if index < 0 or index >= _runtime_nodes.size() or index >= _slot_holders.size():
		return
	var holder: Node3D = _slot_holders[index]
	var old_node: Node3D = _runtime_nodes[index]
	var replacement: Node3D = _instantiate_symbol(key)
	holder.add_child(replacement)
	replacement.transform = _scaled_template_transform_for_key(key)
	replacement.visible = old_node.visible
	old_node.queue_free()
	_runtime_nodes[index] = replacement
	_runtime_keys[index] = key

func _instantiate_symbol(key: String) -> Node3D:
	var template: Node3D = _template_clones.get(key) as Node3D
	if template == null and not _template_clones.is_empty():
		template = _template_clones.values()[0] as Node3D
	if template == null:
		return Node3D.new()
	var instance: Node3D = template.duplicate() as Node3D
	if instance == null:
		return Node3D.new()
	instance.visible = true
	return instance

func _apply_layout() -> void:
	for i: int in range(mini(_runtime_nodes.size(), _slot_holders.size())):
		var holder: Node3D = _slot_holders[i]
		var node: Node3D = _runtime_nodes[i]
		if holder == null or node == null:
			continue
		if node.get_parent() != holder:
			node.reparent(holder)
		var key: String = _runtime_keys[i]
		node.transform = _scaled_template_transform_for_key(key)

func _apply_visibility(show_all: bool) -> void:
	for i: int in range(mini(_runtime_nodes.size(), _slot_holders.size())):
		var node: Node3D = _runtime_nodes[i]
		var holder: Node3D = _slot_holders[i]
		if node == null or holder == null:
			continue
		var actual_y: float = holder.position.y + _current_offset
		var visibility_limit: float = _spacing * (2.0 + spin_visible_padding if show_all else 1.0 + idle_visible_padding)
		node.visible = absf(actual_y) <= visibility_limit

func _slot_symbol(holder: Node3D) -> Node3D:
	for child: Node in holder.get_children():
		var node_3d: Node3D = child as Node3D
		if node_3d != null:
			return node_3d
	return null

func _template_transform_for_key(key: String) -> Transform3D:
	if _template_transforms.has(key):
		return _template_transforms[key]
	if not _template_transforms.is_empty():
		return _template_transforms.values()[0]
	return Transform3D.IDENTITY

func _scaled_template_transform_for_key(key: String) -> Transform3D:
	var transform_value: Transform3D = _template_transform_for_key(key)
	if is_equal_approx(symbol_scale_multiplier, 1.0):
		return transform_value
	transform_value.basis = transform_value.basis.scaled(Vector3.ONE * symbol_scale_multiplier)
	return transform_value

func _slot_transform_for_index(index: int) -> Transform3D:
	if index >= 0 and index < _slot_local_transforms.size():
		var transform_value: Transform3D = _slot_local_transforms[index]
		if not is_equal_approx(symbol_scale_multiplier, 1.0):
			transform_value.basis = transform_value.basis.scaled(Vector3.ONE * symbol_scale_multiplier)
		return transform_value
	return Transform3D.IDENTITY

func _detect_spacing_from_values(values: Array[float]) -> float:
	if values.size() < 2:
		return 1.0
	var spacing: float = absf(values[0] - values[1])
	for i: int in range(values.size() - 1):
		spacing = minf(spacing, absf(values[i] - values[i + 1]))
	return maxf(spacing, 0.001)

func _detect_visible_indices() -> Array[int]:
	var pairs: Array[Dictionary] = []
	for i: int in range(_slot_positions.size()):
		pairs.append({"index": i, "distance": absf(_slot_positions[i])})
	pairs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["distance"]) < float(b["distance"])
	)
	pairs = pairs.slice(0, mini(3, pairs.size()))
	pairs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _slot_positions[int(a["index"])] > _slot_positions[int(b["index"])]
	)
	var result: Array[int] = []
	for pair: Dictionary in pairs:
		result.append(int(pair["index"]))
	return result

func _detect_column_center(origins: Array[Vector3]) -> Vector3:
	if origins.is_empty():
		return Vector3.ZERO
	var x_values: Array[float] = []
	var z_values: Array[float] = []
	for origin: Vector3 in origins:
		x_values.append(origin.x)
		z_values.append(origin.z)
	return Vector3(_median_value(x_values), 0.0, _median_value(z_values))

func _median_value(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var sorted_values: Array[float] = values.duplicate()
	sorted_values.sort()
	var middle: int = sorted_values.size() / 2
	if sorted_values.size() % 2 == 1:
		return sorted_values[middle]
	return (sorted_values[middle - 1] + sorted_values[middle]) * 0.5

func _max_visible_index() -> int:
	var result: int = 0
	for index: int in _visible_indices:
		result = maxi(result, index)
	return result

func _random_key() -> String:
	if _template_clones.is_empty():
		return SYMBOL_KEYS[randi_range(0, SYMBOL_KEYS.size() - 1)]
	var keys: Array = _template_clones.keys()
	return String(keys[randi_range(0, keys.size() - 1)])

func _symbol_key_from_node_name(node_name: String) -> String:
	var normalized: String = node_name.to_lower()
	if normalized.contains("lucky") or normalized.contains("seven"):
		return "seven"
	if normalized.contains("campana") or normalized.contains("bell"):
		return "bell"
	if normalized.contains("ciliegie") or normalized.contains("cherry"):
		return "cherry"
	if normalized.contains("treasure") or normalized.contains("chest"):
		return "chest"
	if normalized.contains("plane") or normalized.contains("clover"):
		return "clover"
	if normalized.contains("diamond") or normalized.contains("gem"):
		return "diamond"
	if normalized.contains("lemon"):
		return "lemon"
	return ""
