extends Control

@export var stage_root_path: NodePath = ^"../../ScreenStage3D"
@export var reels_root_path: NodePath = ^"../../ScreenStage3D/ReelsRoot"

var _stage_root: Node3D
var _reels_root: Node3D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	_bind_nodes()

func set_stage_visible(active: bool) -> void:
	visible = active
	_bind_nodes()
	if _stage_root != null:
		_stage_root.visible = active

func set_symbol_pool(_symbols: Array[Texture2D], _weights: Array[float]) -> void:
	pass

func sync_layout() -> void:
	_bind_nodes()
	if _reels_root != null and _reels_root.has_method("sync_layout"):
		_reels_root.call("sync_layout")

func set_status_text(_text: String) -> void:
	pass

func start_spin_with_board(board: Array) -> void:
	_bind_nodes()
	if _reels_root != null and _reels_root.has_method("start_spin_with_board"):
		_reels_root.call("start_spin_with_board", board)

func preview_board(board: Array) -> void:
	_bind_nodes()
	if _reels_root != null and _reels_root.has_method("preview_board"):
		_reels_root.call("preview_board", board)

func show_combo_highlight(points: Array, palette_index: int = 0) -> void:
	_bind_nodes()
	if _reels_root != null and _reels_root.has_method("show_combo_highlight"):
		_reels_root.call("show_combo_highlight", points, palette_index)

func clear_combo_highlight() -> void:
	_bind_nodes()
	if _reels_root != null and _reels_root.has_method("clear_combo_highlight"):
		_reels_root.call("clear_combo_highlight")

func is_spinning() -> bool:
	_bind_nodes()
	return _reels_root != null and _reels_root.has_method("is_spinning") and _reels_root.call("is_spinning")

func _bind_nodes() -> void:
	_stage_root = get_node_or_null(stage_root_path) as Node3D
	_reels_root = get_node_or_null(reels_root_path) as Node3D
