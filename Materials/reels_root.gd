extends Node3D

const SYMBOL_KEYS: Array[String] = ["lemon", "cherry", "clover", "bell", "diamond", "chest", "seven"]

@export var base_spin_speed: float = 24.0
@export var reel_speed_step: float = 1.5
@export var stop_stagger: float = 0.08
@export var settle_speed: float = 13.5
@export var random_cycles_min: int = 7
@export var random_cycles_max: int = 10
@export var frame_rams_root_path: NodePath = ^"../Node3D"
@export var frame_node_prefix: String = "Rams"
@export var frame_use_spatial_mapping: bool = true
@export var frame_pulse_speed: float = 4.0
@export var frame_pulse_dim_color: Color = Color(0.55, 0.08, 0.48, 1.0)
@export var frame_pulse_bright_color: Color = Color(1.0, 0.14, 0.90, 1.0)
@export var frame_emission_energy_min: float = 0.6
@export var frame_emission_energy_max: float = 2.4

var _reels: Array[Node3D] = []
var _frame_nodes: Dictionary = {}
var _active_frame_ids: Dictionary = {}
var _frame_materials: Dictionary = {}
var _pulse_t: float = 0.0

func _ready() -> void:
	randomize()
	_bind_reels()
	_bind_frame_rams()
	_clear_frame_rams()
	set_process(false)

func _process(delta: float) -> void:
	if _active_frame_ids.is_empty():
		set_process(false)
		return
	_pulse_t += delta
	var phase: float = 0.5 + 0.5 * sin(_pulse_t * frame_pulse_speed)
	var pulse_color: Color = frame_pulse_dim_color.lerp(frame_pulse_bright_color, phase)
	var pulse_energy: float = lerpf(frame_emission_energy_min, frame_emission_energy_max, phase)
	for id_var: Variant in _active_frame_ids.keys():
		var id: int = int(id_var)
		var mat: BaseMaterial3D = _frame_materials.get(id) as BaseMaterial3D
		if mat == null:
			continue
		mat.albedo_color = pulse_color
		mat.emission_enabled = true
		mat.emission = pulse_color
		mat.emission_energy_multiplier = pulse_energy

func sync_layout() -> void:
	_bind_reels(true)
	_bind_frame_rams(true)
	for reel: Node3D in _reels:
		if reel != null and reel.has_method("sync_layout"):
			reel.call("sync_layout")

func start_spin_with_board(board: Array) -> void:
	_bind_reels()
	if _reels.is_empty():
		return
	clear_combo_highlight()
	for col: int in range(mini(_reels.size(), 5)):
		var reel: Node3D = _reels[col]
		if reel == null or not reel.has_method("begin_spin"):
			continue
		var target_keys := [
			_symbol_key_for_board(board, 0, col),
			_symbol_key_for_board(board, 1, col),
			_symbol_key_for_board(board, 2, col),
		]
		var total_cycles: int = randi_range(random_cycles_min, random_cycles_max) + col
		reel.call(
			"begin_spin",
			target_keys,
			base_spin_speed + float(col) * reel_speed_step,
			settle_speed,
			total_cycles,
			float(col) * stop_stagger
		)

func preview_board(board: Array) -> void:
	_bind_reels()
	for col: int in range(mini(_reels.size(), 5)):
		var reel: Node3D = _reels[col]
		if reel == null or not reel.has_method("preview_symbols"):
			continue
		var target_keys := [
			_symbol_key_for_board(board, 0, col),
			_symbol_key_for_board(board, 1, col),
			_symbol_key_for_board(board, 2, col),
		]
		reel.call("preview_symbols", target_keys)

func show_combo_highlight(points: Array, _palette_index: int = 0) -> void:
	_bind_frame_rams()
	var active_frame_ids: Dictionary = {}
	for point_var: Variant in points:
		var point: Vector2i = _to_point(point_var)
		if point.x < 0 or point.x > 2:
			continue
		if point.y < 0 or point.y >= _reels.size():
			continue
		var reel: Node3D = _reels[point.y]
		if reel != null and reel.has_method("highlight_row"):
			reel.call("highlight_row", point.x)
		var frame_id: int = _frame_id_for_point(point)
		if frame_id > 0:
			active_frame_ids[frame_id] = true
	_apply_frame_rams(active_frame_ids)

func clear_combo_highlight() -> void:
	_bind_reels()
	for reel: Node3D in _reels:
		if reel != null and reel.has_method("clear_highlight"):
			reel.call("clear_highlight")
	_clear_frame_rams()

func is_spinning() -> bool:
	_bind_reels()
	for reel: Node3D in _reels:
		if reel != null and reel.has_method("is_spinning") and reel.call("is_spinning"):
			return true
	return false

func _bind_reels(force: bool = false) -> void:
	if force:
		_reels.clear()
	if not _reels.is_empty():
		return
	for child: Node in get_children():
		var reel: Node3D = child as Node3D
		if reel != null:
			_reels.append(reel)

func _symbol_key_for_board(board: Array, row: int, col: int) -> String:
	if row < 0 or row >= board.size():
		return ""
	var line: Array = board[row] as Array
	if col < 0 or col >= line.size():
		return ""
	var index: int = int(line[col])
	if index < 0 or index >= SYMBOL_KEYS.size():
		return ""
	return SYMBOL_KEYS[index]

func _to_point(point_var: Variant) -> Vector2i:
	if point_var is Vector2i:
		return point_var
	if point_var is Vector2:
		var point: Vector2 = point_var as Vector2
		return Vector2i(int(round(point.x)), int(round(point.y)))
	if point_var is Array:
		var arr: Array = point_var as Array
		if arr.size() >= 2:
			return Vector2i(int(arr[0]), int(arr[1]))
	if point_var is Dictionary:
		var dict: Dictionary = point_var as Dictionary
		if dict.has("x") and dict.has("y"):
			return Vector2i(int(dict.get("x", -1)), int(dict.get("y", -1)))
	return Vector2i(-1, -1)

func _bind_frame_rams(force: bool = false) -> void:
	if force:
		_frame_nodes.clear()
		_frame_materials.clear()
	if not _frame_nodes.is_empty():
		return
	var root: Node3D = get_node_or_null(frame_rams_root_path) as Node3D
	if root == null:
		var fallback: Node3D = get_node_or_null("../FrameRams") as Node3D
		if fallback != null:
			root = fallback
	if root == null:
		return
	var candidates: Array[Node3D] = []
	for child: Node in root.get_children():
		var node: Node3D = child as Node3D
		if node == null:
			continue
		if not node.name.begins_with(frame_node_prefix):
			continue
		candidates.append(node)
	if frame_use_spatial_mapping and candidates.size() >= 15:
		var sorted_by_y: Array[Node3D] = candidates.duplicate()
		sorted_by_y.sort_custom(func(a: Node3D, b: Node3D) -> bool:
			return a.position.y > b.position.y
		)
		var top15: Array[Node3D] = sorted_by_y.slice(0, 15)
		for row: int in range(3):
			var row_nodes: Array[Node3D] = []
			for col_idx: int in range(5):
				var index: int = row * 5 + col_idx
				if index < top15.size():
					row_nodes.append(top15[index])
			row_nodes.sort_custom(func(a: Node3D, b: Node3D) -> bool:
				return a.position.x < b.position.x
			)
			for col: int in range(mini(row_nodes.size(), 5)):
				var id: int = row * 5 + col + 1
				var node: Node3D = row_nodes[col]
				_frame_nodes[id] = node
				_frame_materials[id] = _ensure_frame_material(node)
		return
	for i: int in range(1, 16):
		var node: Node3D = root.get_node_or_null("%s%d" % [frame_node_prefix, i]) as Node3D
		if node != null:
			_frame_nodes[i] = node
			_frame_materials[i] = _ensure_frame_material(node)

func _frame_id_for_point(point: Vector2i) -> int:
	if point.y < 0 or point.y > 4:
		return -1
	if point.x < 0 or point.x > 2:
		return -1
	return point.x * 5 + point.y + 1

func _apply_frame_rams(active_ids: Dictionary) -> void:
	if _frame_nodes.is_empty():
		return
	_active_frame_ids = active_ids.duplicate()
	_pulse_t = 0.0
	set_process(not active_ids.is_empty())
	for id_var: Variant in _frame_nodes.keys():
		var id: int = int(id_var)
		var node: Node3D = _frame_nodes[id] as Node3D
		if node == null:
			continue
		node.visible = active_ids.has(id)
		var mat: BaseMaterial3D = _frame_materials.get(id) as BaseMaterial3D
		if mat == null:
			continue
		if node.visible:
			mat.albedo_color = frame_pulse_bright_color
			mat.emission_enabled = true
			mat.emission = frame_pulse_bright_color
			mat.emission_energy_multiplier = frame_emission_energy_max
		else:
			mat.albedo_color = frame_pulse_dim_color
			mat.emission_enabled = true
			mat.emission = frame_pulse_dim_color
			mat.emission_energy_multiplier = frame_emission_energy_min

func _clear_frame_rams() -> void:
	if _frame_nodes.is_empty():
		return
	_active_frame_ids.clear()
	for node_var: Variant in _frame_nodes.values():
		var node: Node3D = node_var as Node3D
		if node != null:
			node.visible = false

func _ensure_frame_material(root: Node3D) -> BaseMaterial3D:
	if root == null:
		return null
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		var mesh_node: MeshInstance3D = current as MeshInstance3D
		if mesh_node != null:
			var material: BaseMaterial3D = mesh_node.material_override as BaseMaterial3D
			if material == null and mesh_node.get_surface_override_material_count() > 0:
				material = mesh_node.get_surface_override_material(0) as BaseMaterial3D
			if material != null:
				var cloned: BaseMaterial3D = material.duplicate() as BaseMaterial3D
				if cloned != null:
					cloned.resource_local_to_scene = true
					mesh_node.material_override = cloned
					return cloned
		for child: Node in current.get_children():
			stack.append(child)
	return null
