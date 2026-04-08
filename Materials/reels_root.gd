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

var _reels: Array[Node3D] = []
var _frame_nodes: Dictionary = {}

func _ready() -> void:
	randomize()
	_bind_reels()
	_bind_frame_rams()
	_clear_frame_rams()

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
		if reel != null and reel.has_method("is_spinning") and bool(reel.call("is_spinning")):
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
	if not _frame_nodes.is_empty():
		return
	var root: Node3D = get_node_or_null(frame_rams_root_path) as Node3D
	if root == null:
		var fallback: Node3D = get_node_or_null("../FrameRams") as Node3D
		if fallback != null:
			root = fallback
	if root == null:
		return
	for i: int in range(1, 16):
		var node: Node3D = root.get_node_or_null("%s%d" % [frame_node_prefix, i]) as Node3D
		if node != null:
			_frame_nodes[i] = node

func _frame_id_for_point(point: Vector2i) -> int:
	# rows: top=0 -> Rams6..10, middle=1 -> Rams1..5, bottom=2 -> Rams11..15
	if point.y < 0 or point.y > 4:
		return -1
	match point.x:
		0:
			return 6 + point.y
		1:
			return 1 + point.y
		2:
			return 11 + point.y
		_:
			return -1

func _apply_frame_rams(active_ids: Dictionary) -> void:
	if _frame_nodes.is_empty():
		return
	for id_var: Variant in _frame_nodes.keys():
		var id: int = int(id_var)
		var node: Node3D = _frame_nodes[id] as Node3D
		if node == null:
			continue
		node.visible = active_ids.has(id)

func _clear_frame_rams() -> void:
	if _frame_nodes.is_empty():
		return
	for node_var: Variant in _frame_nodes.values():
		var node: Node3D = node_var as Node3D
		if node != null:
			node.visible = false
