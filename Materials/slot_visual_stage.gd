extends Control

const SYMBOL_KEYS: Array[String] = ["lemon", "cherry", "clover", "bell", "diamond", "chest", "seven"]

@export var stage_root_path: NodePath = ^"../ScreenStage3D"
@export var reels_root_path: NodePath = ^"../ScreenStage3D/ReelsRoot"
@export var base_spin_speed: float = 9.5
@export var reel_speed_step: float = 0.85
@export var stop_stagger: float = 0.12
@export var settle_speed: float = 8.0

var _stage_root: Node3D
var _reels_root: Node3D
var _reels: Array[Dictionary] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	_bind_stage()

func _process(delta: float) -> void:
	for reel_var: Variant in _reels:
		_update_reel(reel_var as Dictionary, delta)

func set_stage_visible(active: bool) -> void:
	visible = active
	if _stage_root != null:
		_stage_root.visible = active

func set_symbol_pool(_symbols: Array[Texture2D], _weights: Array[float]) -> void:
	pass

func sync_layout() -> void:
	_bind_stage()

func set_status_text(_text: String) -> void:
	pass

func start_spin_with_board(board: Array) -> void:
	_bind_stage()
	if _reels.is_empty():
		return
	clear_combo_highlight()
	for col: int in range(mini(_reels.size(), 5)):
		var reel: Dictionary = _reels[col] as Dictionary
		reel["mode"] = "spinning"
		reel["speed"] = base_spin_speed + float(col) * reel_speed_step
		reel["stop_delay"] = 0.8 + float(col) * stop_stagger
		reel["stop_elapsed"] = 0.0
		reel["target_keys"] = [
			_symbol_key_for_board(board, 0, col),
			_symbol_key_for_board(board, 1, col),
			_symbol_key_for_board(board, 2, col),
		]
		reel["target_applied"] = false
		var reel_node: Node3D = reel.get("node") as Node3D
		if reel_node != null:
			reel_node.position.y = 0.0

func preview_board(board: Array) -> void:
	_bind_stage()
	for col: int in range(mini(_reels.size(), 5)):
		var reel: Dictionary = _reels[col] as Dictionary
		reel["mode"] = "idle"
		reel["speed"] = 0.0
		reel["target_keys"] = [
			_symbol_key_for_board(board, 0, col),
			_symbol_key_for_board(board, 1, col),
			_symbol_key_for_board(board, 2, col),
		]
		reel["target_applied"] = true
		var reel_node: Node3D = reel.get("node") as Node3D
		if reel_node != null:
			reel_node.position.y = 0.0
		_apply_targets_to_reel(reel)

func show_combo_highlight(points: Array, _palette_index: int = 0) -> void:
	for point_var: Variant in points:
		var point: Vector2i = _to_point(point_var)
		if point.x < 0 or point.x > 2:
			continue
		if point.y < 0 or point.y >= _reels.size():
			continue
		var reel: Dictionary = _reels[point.y] as Dictionary
		var key: String = _visible_key_for_row(reel, point.x)
		if key.is_empty():
			continue
		var symbol_nodes: Dictionary = reel.get("symbol_nodes", {})
		var symbol: Node3D = symbol_nodes.get(key) as Node3D
		if symbol == null:
			continue
		symbol.scale = Vector3.ONE * 1.12

func clear_combo_highlight() -> void:
	for reel_var: Variant in _reels:
		var reel: Dictionary = reel_var as Dictionary
		var symbol_nodes: Dictionary = reel.get("symbol_nodes", {})
		for symbol_var: Variant in symbol_nodes.values():
			var symbol: Node3D = symbol_var as Node3D
			if symbol != null:
				symbol.scale = Vector3.ONE

func _bind_stage() -> void:
	_stage_root = get_node_or_null(stage_root_path) as Node3D
	_reels_root = get_node_or_null(reels_root_path) as Node3D
	if _reels_root == null:
		return
	if not _reels.is_empty():
		return
	for reel_node: Node in _reels_root.get_children():
		var reel_3d: Node3D = reel_node as Node3D
		if reel_3d == null:
			continue
		var reel := _capture_reel(reel_3d)
		if not reel.is_empty():
			_reels.append(reel)

func _capture_reel(reel_node: Node3D) -> Dictionary:
	var symbol_nodes: Dictionary = {}
	var ordered: Array[String] = []
	var y_positions: Dictionary = {}
	for child: Node in reel_node.get_children():
		var node_3d: Node3D = child as Node3D
		if node_3d == null:
			continue
		var key: String = _symbol_key_from_node_name(node_3d.name)
		if key.is_empty():
			continue
		symbol_nodes[key] = node_3d
		node_3d.visible = true
		y_positions[key] = node_3d.position.y
		ordered.append(key)
	if ordered.size() < 3:
		return {}

	ordered.sort_custom(func(a: String, b: String) -> bool:
		return float(y_positions[a]) > float(y_positions[b])
	)

	var slots: Array[float] = []
	for key: String in ordered:
		slots.append(float(y_positions[key]))

	var visible_rows: Array[float] = slots.duplicate()
	visible_rows.sort_custom(func(a: float, b: float) -> bool:
		return absf(a) < absf(b)
	)
	visible_rows = visible_rows.slice(0, mini(3, visible_rows.size()))
	visible_rows.sort()
	visible_rows.reverse()

	var spacing: float = 1.0
	if slots.size() >= 2:
		spacing = absf(slots[0] - slots[1])
		for i: int in range(1, slots.size() - 1):
			spacing = minf(spacing, absf(slots[i] - slots[i + 1]))

	return {
		"node": reel_node,
		"symbol_nodes": symbol_nodes,
		"ordered_keys": ordered,
		"slot_positions": slots,
		"visible_rows": visible_rows,
		"spacing": maxf(spacing, 0.001),
		"mode": "idle",
		"speed": 0.0,
		"stop_delay": 0.0,
		"stop_elapsed": 0.0,
		"target_keys": [],
		"target_applied": false,
	}

func _update_reel(reel: Dictionary, delta: float) -> void:
	var reel_node: Node3D = reel.get("node") as Node3D
	if reel_node == null:
		return
	var mode: String = String(reel.get("mode", "idle"))
	if mode == "idle":
		return

	var speed: float = float(reel.get("speed", 0.0))
	var spacing: float = float(reel.get("spacing", 1.0))
	reel_node.position.y -= speed * delta
	while reel_node.position.y <= -spacing:
		reel_node.position.y += spacing
		_cycle_reel_down(reel)

	reel["stop_elapsed"] = float(reel.get("stop_elapsed", 0.0)) + delta
	if mode == "spinning":
		if float(reel.get("stop_elapsed", 0.0)) >= float(reel.get("stop_delay", 0.0)):
			reel["mode"] = "settling"
		return

	if mode == "settling":
		reel["speed"] = lerpf(speed, 0.0, delta * settle_speed)
		if not bool(reel.get("target_applied", false)) and float(reel.get("speed", 0.0)) <= base_spin_speed * 0.45:
			_apply_targets_to_reel(reel)
		reel_node.position.y = lerpf(reel_node.position.y, 0.0, delta * (settle_speed + 2.0))
		if float(reel.get("speed", 0.0)) <= 0.08 and absf(reel_node.position.y) <= 0.02:
			reel_node.position.y = 0.0
			reel["speed"] = 0.0
			reel["mode"] = "idle"

func _cycle_reel_down(reel: Dictionary) -> void:
	var ordered: Array[String] = reel.get("ordered_keys", [])
	var symbol_nodes: Dictionary = reel.get("symbol_nodes", {})
	if ordered.is_empty():
		return
	var bottom_key: String = ordered.pop_back()
	var top_key: String = ordered.front()
	var bottom_node: Node3D = symbol_nodes.get(bottom_key) as Node3D
	var top_node: Node3D = symbol_nodes.get(top_key) as Node3D
	if bottom_node == null or top_node == null:
		return
	var spacing: float = float(reel.get("spacing", 1.0))
	bottom_node.position.y = top_node.position.y + spacing
	bottom_node.visible = true
	ordered.push_front(bottom_key)
	reel["ordered_keys"] = ordered

func _apply_targets_to_reel(reel: Dictionary) -> void:
	var slots: Array[float] = reel.get("slot_positions", [])
	var visible_rows: Array[float] = reel.get("visible_rows", [])
	var target_keys: Array = reel.get("target_keys", [])
	var symbol_nodes: Dictionary = reel.get("symbol_nodes", {})
	if slots.is_empty() or visible_rows.size() < 3 or target_keys.size() < 3:
		return

	var arranged: Array[String] = []
	var used: Dictionary = {}
	for slot_y: float in slots:
		var matched_index: int = -1
		for i: int in range(visible_rows.size()):
			if is_equal_approx(slot_y, float(visible_rows[i])):
				matched_index = i
				break
		if matched_index != -1:
			var target_key: String = String(target_keys[matched_index])
			arranged.append(target_key)
			used[target_key] = true
		else:
			arranged.append("")

	var remaining: Array[String] = []
	for key: String in SYMBOL_KEYS:
		if symbol_nodes.has(key) and not used.has(key):
			remaining.append(key)
	remaining.shuffle()

	for i: int in range(arranged.size()):
		if arranged[i].is_empty() and not remaining.is_empty():
			arranged[i] = remaining.pop_front()

	for i: int in range(arranged.size()):
		var key: String = arranged[i]
		var symbol: Node3D = symbol_nodes.get(key) as Node3D
		if symbol == null:
			continue
		symbol.position.y = float(slots[i])
		symbol.visible = true
		symbol.scale = Vector3.ONE

	reel["ordered_keys"] = arranged
	reel["target_applied"] = true

func _visible_key_for_row(reel: Dictionary, row: int) -> String:
	var slots: Array[float] = reel.get("slot_positions", [])
	var visible_rows: Array[float] = reel.get("visible_rows", [])
	var ordered: Array[String] = reel.get("ordered_keys", [])
	if row < 0 or row >= visible_rows.size():
		return ""
	for i: int in range(mini(slots.size(), ordered.size())):
		if is_equal_approx(float(slots[i]), float(visible_rows[row])):
			return String(ordered[i])
	return ""

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

func _to_point(point_var: Variant) -> Vector2i:
	if point_var is Vector2i:
		return point_var
	if point_var is Vector2:
		var p: Vector2 = point_var as Vector2
		return Vector2i(int(round(p.x)), int(round(p.y)))
	if point_var is Array:
		var arr: Array = point_var as Array
		if arr.size() >= 2:
			return Vector2i(int(arr[0]), int(arr[1]))
	if point_var is Dictionary:
		var d: Dictionary = point_var as Dictionary
		if d.has("x") and d.has("y"):
			return Vector2i(int(d.get("x", -1)), int(d.get("y", -1)))
	return Vector2i(-1, -1)
