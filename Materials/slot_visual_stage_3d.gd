extends Control

@export var viewport_size: Vector2i = Vector2i(1024, 768)
@export var reel_count: int = 5
@export var holder_count: int = 7
@export var reel_spacing: float = 1.48
@export var row_spacing: float = 1.46
@export var spin_speed: float = 8.8
@export var stop_stagger: float = 0.11
@export var settle_speed: float = 10.0
@export var camera_size: float = 3.22
@export var symbol_pixel_size: float = 0.0064
@export var glow_pixel_size: float = 0.0072

var _symbol_pool: Array[Texture2D] = []
var _symbol_weights: Array[float] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _viewport_host: SubViewportContainer
var _viewport: SubViewport
var _stage_root: Node3D
var _reels_root: Node3D
var _camera: Camera3D
var _reels: Array[Dictionary] = []
var _highlight_targets: Array[Dictionary] = []
var _highlight_time: float = 0.0

var _palettes: Array[Array] = [
	[Color(1.00, 0.50, 0.08, 1.0), Color(1.00, 0.90, 0.26, 1.0)],
	[Color(0.24, 0.95, 1.00, 1.0), Color(0.18, 1.00, 0.72, 1.0)],
	[Color(1.00, 0.34, 0.72, 1.0), Color(0.64, 0.92, 1.00, 1.0)],
	[Color(0.40, 1.00, 0.38, 1.0), Color(1.00, 0.88, 0.18, 1.0)],
]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.randomize()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_ensure_scene()
	_build_reels()
	_sync_layout()

func _process(delta: float) -> void:
	for reel_var: Variant in _reels:
		_update_reel(reel_var as Dictionary, delta)
	_update_highlights(delta)

func set_symbol_pool(symbols: Array[Texture2D], weights: Array[float]) -> void:
	_symbol_pool = symbols.duplicate()
	_symbol_weights = weights.duplicate()
	if _reels.is_empty():
		return
	for reel_var: Variant in _reels:
		var reel: Dictionary = reel_var as Dictionary
		for holder_var: Variant in reel.get("holders", []):
			var holder: Node3D = holder_var as Node3D
			if holder == null:
				continue
			_set_holder_texture(holder, _pick_texture())

func sync_layout() -> void:
	_sync_layout()

func set_stage_visible(active: bool) -> void:
	visible = active

func set_status_text(_text: String) -> void:
	pass

func start_spin_with_board(board: Array) -> void:
	if _symbol_pool.is_empty():
		return
	clear_combo_highlight()
	for col: int in range(mini(reel_count, _reels.size())):
		var reel: Dictionary = _reels[col] as Dictionary
		var reel_node: Node3D = reel.get("node") as Node3D
		reel["mode"] = "spinning"
		reel["speed"] = spin_speed + float(col) * 0.55
		reel["stop_delay"] = 0.72 + float(col) * stop_stagger
		reel["stop_elapsed"] = 0.0
		reel["target_textures"] = [
			_texture_from_board(board, 0, col),
			_texture_from_board(board, 1, col),
			_texture_from_board(board, 2, col),
		]
		reel["target_applied"] = false
		if reel_node != null:
			reel_node.position.y = 0.0
		for holder_var: Variant in reel.get("holders", []):
			var holder: Node3D = holder_var as Node3D
			_set_holder_texture(holder, _pick_texture())

func preview_board(board: Array) -> void:
	if _reels.is_empty():
		return
	for col: int in range(mini(reel_count, _reels.size())):
		var reel: Dictionary = _reels[col] as Dictionary
		var reel_node: Node3D = reel.get("node") as Node3D
		reel["mode"] = "idle"
		reel["speed"] = 0.0
		if reel_node != null:
			reel_node.position.y = 0.0
		reel["target_textures"] = [
			_texture_from_board(board, 0, col),
			_texture_from_board(board, 1, col),
			_texture_from_board(board, 2, col),
		]
		_apply_target_to_reel(reel)

func show_combo_highlight(points: Array, palette_index: int = 0) -> void:
	clear_combo_highlight()
	var palette: Array = _palettes[posmod(palette_index, _palettes.size())]
	for point_var: Variant in points:
		var point: Vector2i = _to_point(point_var)
		if point.x < 0 or point.x > 2:
			continue
		if point.y < 0 or point.y >= _reels.size():
			continue
		var reel: Dictionary = _reels[point.y] as Dictionary
		var holders: Array = reel.get("holders", [])
		if holders.size() < 3:
			continue
		var holder: Node3D = holders[point.x] as Node3D
		if holder == null:
			continue
		_highlight_targets.append({
			"holder": holder,
			"edge": palette[0],
			"shine": palette[1],
		})

func clear_combo_highlight() -> void:
	for info_var: Variant in _highlight_targets:
		var info: Dictionary = info_var as Dictionary
		var holder: Node3D = info.get("holder") as Node3D
		if holder == null:
			continue
		_restore_holder_highlight(holder)
	_highlight_targets.clear()

func _ensure_scene() -> void:
	_viewport_host = get_node_or_null("StageViewportHost") as SubViewportContainer
	if _viewport_host == null:
		_viewport_host = SubViewportContainer.new()
		_viewport_host.name = "StageViewportHost"
		add_child(_viewport_host)
	_viewport_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	_viewport_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport_host.stretch = true

	_viewport = _viewport_host.get_node_or_null("StageViewport") as SubViewport
	if _viewport == null:
		_viewport = SubViewport.new()
		_viewport.name = "StageViewport"
		_viewport_host.add_child(_viewport)
	_viewport.size = viewport_size
	_viewport.transparent_bg = true
	_viewport.handle_input_locally = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.msaa_3d = Viewport.MSAA_2X

	_stage_root = _viewport.get_node_or_null("StageRoot") as Node3D
	if _stage_root == null:
		_stage_root = Node3D.new()
		_stage_root.name = "StageRoot"
		_viewport.add_child(_stage_root)

	_camera = _stage_root.get_node_or_null("StageCamera") as Camera3D
	if _camera == null:
		_camera = Camera3D.new()
		_camera.name = "StageCamera"
		_stage_root.add_child(_camera)
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = camera_size
	_camera.position = Vector3(0.0, 0.0, 5.8)
	_camera.current = true

	_reels_root = _stage_root.get_node_or_null("Reels") as Node3D
	if _reels_root == null:
		_reels_root = Node3D.new()
		_reels_root.name = "Reels"
		_stage_root.add_child(_reels_root)

	_ensure_frame_meshes()

func _ensure_frame_meshes() -> void:
	var frame_root: Node3D = _stage_root.get_node_or_null("Frame") as Node3D
	if frame_root == null:
		frame_root = Node3D.new()
		frame_root.name = "Frame"
		_stage_root.add_child(frame_root)
		_add_plane(frame_root, "Back", Vector2(8.4, 4.8), Vector3(0.0, 0.0, -0.55), Color(0.02, 0.01, 0.01, 1.0), Color(0.0, 0.0, 0.0, 1.0))
		_add_plane(frame_root, "TopMask", Vector2(8.4, 1.42), Vector3(0.0, 2.6, 0.08), Color(0.0, 0.0, 0.0, 1.0), Color(0.0, 0.0, 0.0, 1.0))
		_add_plane(frame_root, "BottomMask", Vector2(8.4, 1.42), Vector3(0.0, -2.6, 0.08), Color(0.0, 0.0, 0.0, 1.0), Color(0.0, 0.0, 0.0, 1.0))
		_add_plane(frame_root, "TopGlow", Vector2(7.5, 0.12), Vector3(0.0, 1.86, -0.15), Color(1.0, 0.56, 0.12, 0.9), Color(1.0, 0.48, 0.08, 0.5))
		_add_plane(frame_root, "BottomGlow", Vector2(7.5, 0.12), Vector3(0.0, -1.86, -0.15), Color(1.0, 0.56, 0.12, 0.9), Color(1.0, 0.48, 0.08, 0.5))
		for i: int in range(reel_count - 1):
			var x_pos: float = (-float(reel_count - 1) * reel_spacing * 0.5) + float(i + 1) * reel_spacing - (reel_spacing * 0.5)
			_add_plane(frame_root, "Sep%d" % i, Vector2(0.09, 3.62), Vector3(x_pos, 0.0, 0.06), Color(1.0, 0.5, 0.08, 0.92), Color(1.0, 0.42, 0.06, 0.45))

func _add_plane(parent: Node3D, node_name: String, size: Vector2, pos: Vector3, albedo: Color, emission: Color) -> void:
	var plane: MeshInstance3D = parent.get_node_or_null(node_name) as MeshInstance3D
	if plane == null:
		plane = MeshInstance3D.new()
		plane.name = node_name
		parent.add_child(plane)
	var mesh := QuadMesh.new()
	mesh.size = size
	plane.mesh = mesh
	plane.position = pos
	var mat := StandardMaterial3D.new()
	mat.resource_local_to_scene = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = albedo
	mat.emission_enabled = emission.a > 0.0
	mat.emission = emission
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	plane.material_override = mat

func _build_reels() -> void:
	if not _reels.is_empty():
		return
	for col: int in range(reel_count):
		var reel_root := Node3D.new()
		reel_root.name = "Reel%d" % (col + 1)
		_reels_root.add_child(reel_root)
		var reel: Dictionary = {
			"node": reel_root,
			"holders": [],
			"mode": "idle",
			"speed": 0.0,
			"stop_delay": 0.0,
			"stop_elapsed": 0.0,
			"target_textures": [],
			"target_applied": false,
		}
		for holder_index: int in range(holder_count):
			var holder := Node3D.new()
			holder.name = "Holder%d" % holder_index
			reel_root.add_child(holder)

			var sprite := Sprite3D.new()
			sprite.name = "Icon"
			sprite.pixel_size = symbol_pixel_size
			sprite.shaded = false
			sprite.texture = _pick_texture()
			holder.add_child(sprite)

			var glow := Sprite3D.new()
			glow.name = "Glow"
			glow.pixel_size = glow_pixel_size
			glow.shaded = false
			glow.texture = sprite.texture
			glow.position = Vector3(0.0, 0.0, -0.02)
			glow.modulate = Color(1.0, 0.36, 0.08, 0.18)
			holder.add_child(glow)

			reel["holders"].append(holder)
		_reels.append(reel)
		_layout_reel_holders(reel)
	_sync_layout()

func _sync_layout() -> void:
	if _viewport != null:
		_viewport.size = viewport_size
	if _camera != null:
		_camera.size = camera_size
	for col: int in range(mini(reel_count, _reels.size())):
		var reel: Dictionary = _reels[col] as Dictionary
		var reel_root: Node3D = reel.get("node") as Node3D
		if reel_root == null:
			continue
		var total_width: float = float(reel_count - 1) * reel_spacing
		reel_root.position.x = -total_width * 0.5 + float(col) * reel_spacing
		_layout_reel_holders(reel)

func _layout_reel_holders(reel: Dictionary) -> void:
	var holders: Array = reel.get("holders", [])
	for index: int in range(holders.size()):
		var holder: Node3D = holders[index] as Node3D
		if holder == null:
			continue
		holder.position = Vector3(0.0, row_spacing - float(index) * row_spacing, 0.0)

func _update_reel(reel: Dictionary, delta: float) -> void:
	var reel_root: Node3D = reel.get("node") as Node3D
	if reel_root == null:
		return
	var mode: String = String(reel.get("mode", "idle"))
	if mode == "idle":
		return

	var speed: float = float(reel.get("speed", 0.0))
	reel_root.position.y += speed * delta
	while reel_root.position.y >= row_spacing:
		reel_root.position.y -= row_spacing
		_cycle_reel(reel)

	reel["stop_elapsed"] = float(reel.get("stop_elapsed", 0.0)) + delta
	if mode == "spinning":
		if float(reel.get("stop_elapsed", 0.0)) >= float(reel.get("stop_delay", 0.0)):
			reel["mode"] = "settling"
		return

	if mode == "settling":
		reel["speed"] = lerpf(speed, 0.0, delta * settle_speed)
		if not bool(reel.get("target_applied", false)) and speed <= spin_speed * 0.45:
			_apply_target_to_reel(reel)
		if bool(reel.get("target_applied", false)):
			reel_root.position.y = lerpf(reel_root.position.y, 0.0, delta * (settle_speed + 2.0))
		if speed <= 0.12 and absf(reel_root.position.y) <= 0.03:
			reel_root.position.y = 0.0
			reel["speed"] = 0.0
			reel["mode"] = "idle"

func _cycle_reel(reel: Dictionary) -> void:
	var holders: Array = reel.get("holders", [])
	if holders.is_empty():
		return
	var recycled: Node3D = holders.pop_back() as Node3D
	holders.push_front(recycled)
	reel["holders"] = holders
	_layout_reel_holders(reel)
	_set_holder_texture(recycled, _pick_texture())

func _apply_target_to_reel(reel: Dictionary) -> void:
	var holders: Array = reel.get("holders", [])
	var targets: Array = reel.get("target_textures", [])
	if holders.size() < 3:
		return
	for i: int in range(holders.size()):
		var holder: Node3D = holders[i] as Node3D
		if holder == null:
			continue
		if i < 3 and i < targets.size():
			_set_holder_texture(holder, targets[i] as Texture2D)
		else:
			_set_holder_texture(holder, _pick_texture())
	reel["target_applied"] = true

func _set_holder_texture(holder: Node3D, texture: Texture2D) -> void:
	if holder == null or texture == null:
		return
	var icon: Sprite3D = holder.get_node_or_null("Icon") as Sprite3D
	var glow: Sprite3D = holder.get_node_or_null("Glow") as Sprite3D
	if icon != null:
		icon.texture = texture
		icon.modulate = Color(1.10, 1.07, 1.02, 1.0)
	if glow != null:
		glow.texture = texture
		glow.modulate = Color(1.0, 0.36, 0.08, 0.18)
	holder.scale = Vector3.ONE

func _restore_holder_highlight(holder: Node3D) -> void:
	_set_holder_texture(holder, _texture_from_holder(holder))

func _texture_from_holder(holder: Node3D) -> Texture2D:
	var icon: Sprite3D = holder.get_node_or_null("Icon") as Sprite3D
	return null if icon == null else icon.texture

func _pick_texture() -> Texture2D:
	if _symbol_pool.is_empty():
		return null
	if _symbol_weights.size() != _symbol_pool.size():
		return _symbol_pool[_rng.randi_range(0, _symbol_pool.size() - 1)]
	var total: float = 0.0
	for weight_var: Variant in _symbol_weights:
		total += maxf(float(weight_var), 0.0)
	if total <= 0.0:
		return _symbol_pool[_rng.randi_range(0, _symbol_pool.size() - 1)]
	var pick: float = _rng.randf() * total
	var accum: float = 0.0
	for i: int in range(_symbol_weights.size()):
		accum += maxf(float(_symbol_weights[i]), 0.0)
		if pick <= accum:
			return _symbol_pool[i]
	return _symbol_pool.back()

func _texture_from_board(board: Array, row: int, col: int) -> Texture2D:
	if row < 0 or row >= board.size():
		return null
	var line: Array = board[row] as Array
	if col < 0 or col >= line.size():
		return null
	var index: int = int(line[col])
	if index < 0 or index >= _symbol_pool.size():
		return null
	return _symbol_pool[index]

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

func _update_highlights(delta: float) -> void:
	if _highlight_targets.is_empty():
		return
	_highlight_time += delta
	var pulse: float = 0.5 + 0.5 * sin(_highlight_time * 5.2)
	for info_var: Variant in _highlight_targets:
		var info: Dictionary = info_var as Dictionary
		var holder: Node3D = info.get("holder") as Node3D
		if holder == null:
			continue
		var icon: Sprite3D = holder.get_node_or_null("Icon") as Sprite3D
		var glow: Sprite3D = holder.get_node_or_null("Glow") as Sprite3D
		var edge: Color = info.get("edge", Color.WHITE)
		var shine: Color = info.get("shine", Color.WHITE)
		holder.scale = Vector3.ONE * (1.0 + 0.06 * pulse)
		if icon != null:
			icon.modulate = Color(
				maxf(1.10, edge.r * 1.18),
				maxf(1.07, edge.g * 1.18),
				maxf(1.02, edge.b * 1.10),
				1.0
			)
		if glow != null:
			glow.modulate = Color(
				shine.r,
				shine.g,
				shine.b,
				0.26 + 0.28 * pulse
			)
