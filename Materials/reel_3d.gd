extends Node3D

const SYMBOL_KEYS: Array[String] = ["lemon", "cherry", "clover", "bell", "diamond", "chest", "seven"]

@export var spin_acceleration: float = 60.0
@export var settle_snap_speed: float = 18.0
@export var spin_visible_padding: float = 1.2
@export var idle_visible_padding: float = 0.25
@export var slot_spacing_override: float = 2.4
@export var vertical_center_offset: float = 0.0
@export var symbol_scale_multiplier: float = 1.18

var _template_clones: Dictionary = {}
var _template_transforms: Dictionary = {}
var _slot_positions: Array[float] = []
var _visible_indices: Array[int] = []

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
		var template_transform: Transform3D = _scaled_template_transform_for_key(key)
		var transform_copy: Transform3D = template_transform
		transform_copy.origin.y = _slot_positions[i]
		node.transform = transform_copy

func _setup_reel(force: bool = false) -> void:
	if force:
		_template_clones.clear()
		_template_transforms.clear()
		_slot_positions.clear()
		_visible_indices.clear()
		_runtime_nodes.clear()
		_runtime_keys.clear()
	if not _runtime_nodes.is_empty():
		return

	var reel_nodes: Array[Dictionary] = []
	for child: Node in get_children():
		var node_3d: Node3D = child as Node3D
		if node_3d == null:
			continue
		var key: String = _symbol_key_from_node_name(node_3d.name)
		if key.is_empty():
			continue
		reel_nodes.append({
			"node": node_3d,
			"key": key,
			"y": node_3d.position.y,
		})
		if not _template_clones.has(key):
			var clone: Node3D = node_3d.duplicate() as Node3D
			if clone != null:
				clone.visible = true
				_template_clones[key] = clone
				_template_transforms[key] = clone.transform

	if reel_nodes.is_empty():
		return

	reel_nodes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["y"]) > float(b["y"])
	)

	var source_positions: Array[float] = []
	for reel_node: Dictionary in reel_nodes:
		source_positions.append(float(reel_node["y"]))

	_slot_positions.clear()
	_runtime_nodes.clear()
	_runtime_keys.clear()
	_spacing = slot_spacing_override if slot_spacing_override > 0.0 else _detect_spacing_from_values(source_positions)
	var middle_index: float = (float(reel_nodes.size()) - 1.0) * 0.5
	var row_index: int = 0
	for reel_node: Dictionary in reel_nodes:
		_slot_positions.append((middle_index - float(row_index)) * _spacing + vertical_center_offset)
		_runtime_nodes.append(reel_node["node"] as Node3D)
		_runtime_keys.append(String(reel_node["key"]))
		row_index += 1
	_visible_indices = _detect_visible_indices()
	_apply_layout()
	_apply_visibility(false)

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
	var recycled_node: Node3D = _replace_symbol_at_index(bottom_index, next_key)
	var recycled_key: String = _runtime_keys.pop_at(bottom_index)
	_runtime_nodes.pop_at(bottom_index)
	_runtime_nodes.push_front(recycled_node)
	_runtime_keys.push_front(recycled_key)
	_steps_remaining -= 1
	_apply_layout()

func _replace_symbol_at_index(index: int, key: String) -> Node3D:
	if index < 0 or index >= _runtime_nodes.size():
		return Node3D.new()
	var old_node: Node3D = _runtime_nodes[index]
	var transform_copy: Transform3D = old_node.transform
	var replacement: Node3D = _instantiate_symbol(key)
	add_child(replacement)
	replacement.transform = transform_copy
	replacement.visible = old_node.visible
	old_node.queue_free()
	_runtime_nodes[index] = replacement
	_runtime_keys[index] = key
	return replacement

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
	for i: int in range(mini(_runtime_nodes.size(), _slot_positions.size())):
		var node: Node3D = _runtime_nodes[i]
		if node == null:
			continue
		var key: String = _runtime_keys[i]
		var transform_copy: Transform3D = _scaled_template_transform_for_key(key)
		transform_copy.origin.y = _slot_positions[i]
		node.transform = transform_copy

func _apply_visibility(show_all: bool) -> void:
	for i: int in range(_runtime_nodes.size()):
		var node: Node3D = _runtime_nodes[i]
		if node == null:
			continue
		var actual_y: float = 0.0
		if i < _slot_positions.size():
			actual_y = _slot_positions[i] + _current_offset
		var visibility_limit: float = _spacing * (2.0 + spin_visible_padding if show_all else 1.0 + idle_visible_padding)
		node.visible = absf(actual_y) <= visibility_limit

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
