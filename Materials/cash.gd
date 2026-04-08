extends AnimationPlayer

@export var money_mesh: Mesh
@export var ticket_mesh: Mesh
@export var coin_spawn_marker_path: NodePath = ^"Coin_spawn"
@export var ticket_spawn_marker_path: NodePath = ^"TicketSpawn"
@export var coin_life_time: float = 12.8
@export var ticket_life_time: float = 5.2
@export var coin_spawn_up: float = 0.55
@export var coin_spawn_forward: float = 0.35
@export var ticket_spawn_up: float = 0.50
@export var ticket_spawn_forward: float = 0.35
@export var coin_impulse_min: float = 0.22
@export var coin_impulse_max: float = 0.55
@export var ticket_impulse: float = 0.95
@export var coin_count_per_emit: int = 6
@export var coin_emit_interval: float = 0.13
@export var coin_mesh_lay_flat_degrees: Vector3 = Vector3(90.0, 0.0, 0.0)
@export var coin_friction: float = 1.2
@export var coin_bounce: float = 0.02
@export var coin_linear_damp: float = 0.85
@export var coin_angular_damp: float = 1.35

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _coin_emit_timer: Timer
var _coin_emit_remaining: int = 0
var _coin_emit_mesh: Mesh

func _ready() -> void:
	_rng.randomize()
	if money_mesh == null:
		money_mesh = load("res://Objects/money.mesh") as Mesh
	if ticket_mesh == null:
		ticket_mesh = _extract_mesh_from_scene("res://Objects/bilet.glb")
	if ticket_mesh == null:
		ticket_mesh = _make_placeholder_mesh(false)
	if money_mesh == null:
		money_mesh = _make_placeholder_mesh(true)

func emit_coins(count: int = -1) -> void:
	var coin_mesh: Mesh = money_mesh if money_mesh != null else _make_placeholder_mesh(true)
	var total: int = coin_count_per_emit if count < 0 else maxi(count, 0)
	if total <= 0:
		return

	# If interval <= 0, spawn instantly (old behavior).
	if coin_emit_interval <= 0.0:
		for _i: int in range(total):
			_spawn_one_coin(coin_mesh)
		return

	_coin_emit_mesh = coin_mesh
	_coin_emit_remaining = total
	_ensure_coin_timer()
	# Emit one immediately, then drip-feed the rest.
	_emit_one_coin_tick()
	_coin_emit_timer.start()

func _ensure_coin_timer() -> void:
	if _coin_emit_timer != null:
		return
	_coin_emit_timer = Timer.new()
	_coin_emit_timer.one_shot = false
	_coin_emit_timer.autostart = false
	add_child(_coin_emit_timer)
	_coin_emit_timer.timeout.connect(_emit_one_coin_tick)

func _emit_one_coin_tick() -> void:
	if _coin_emit_remaining <= 0:
		if _coin_emit_timer != null:
			_coin_emit_timer.stop()
		return
	_coin_emit_remaining -= 1
	_spawn_one_coin(_coin_emit_mesh)
	if _coin_emit_timer != null:
		_coin_emit_timer.wait_time = maxf(coin_emit_interval, 0.01)

func _spawn_one_coin(coin_mesh: Mesh) -> void:
	var body: RigidBody3D = _spawn_rigid(coin_mesh, coin_life_time, 0.05)
	if body == null:
		return
	var spread: Vector3 = Vector3(
		_rng.randf_range(-0.16, 0.16),
		_rng.randf_range(coin_spawn_up * 0.7, coin_spawn_up),
		-_rng.randf_range(coin_spawn_forward * 0.7, coin_spawn_forward)
	)
	body.global_position += spread * 0.18
	var impulse_dir: Vector3 = Vector3(
		_rng.randf_range(-0.25, 0.25),
		_rng.randf_range(0.15, 0.55),
		-_rng.randf_range(0.35, 0.85)
	).normalized()
	var impulse: float = _rng.randf_range(coin_impulse_min, coin_impulse_max)
	body.apply_impulse(impulse_dir * impulse)
	body.apply_torque_impulse(Vector3(
		_rng.randf_range(-0.22, 0.22),
		_rng.randf_range(-0.22, 0.22),
		_rng.randf_range(-0.22, 0.22)
	))

func emit_ticket() -> void:
	var mesh: Mesh = ticket_mesh if ticket_mesh != null else _make_placeholder_mesh(false)
	var body: RigidBody3D = _spawn_rigid(mesh, ticket_life_time, 0.04)
	if body == null:
		return
	body.global_position += Vector3(0.0, ticket_spawn_up * 0.12, -ticket_spawn_forward * 0.2)
	var impulse_dir: Vector3 = Vector3(
		_rng.randf_range(-0.08, 0.08),
		_rng.randf_range(0.15, 0.35),
		-_rng.randf_range(0.95, 1.15)
	).normalized()
	body.apply_impulse(impulse_dir * ticket_impulse)
	body.apply_torque_impulse(Vector3(
		_rng.randf_range(-0.22, 0.22),
		_rng.randf_range(-0.22, 0.22),
		_rng.randf_range(-0.22, 0.22)
	))

func _spawn_rigid(mesh: Mesh, life_time: float, mass_value: float) -> RigidBody3D:
	if mesh == null:
		return null
	var host: Node3D = get_parent() as Node3D
	if host == null:
		return null
	var marker: Node3D = null
	if mesh == money_mesh and not coin_spawn_marker_path.is_empty():
		marker = host.get_node_or_null(coin_spawn_marker_path) as Node3D
		if marker == null:
			marker = _fallback_find_marker(host, ["Coin_spawn", "CoinSpawn", "Coinspawn", "coinspawn"])
	elif mesh == ticket_mesh and not ticket_spawn_marker_path.is_empty():
		marker = host.get_node_or_null(ticket_spawn_marker_path) as Node3D
		if marker == null:
			marker = _fallback_find_marker(host, ["TicketSpawn", "Ticketspawn", "ticketspawn"])
	var body := RigidBody3D.new()
	body.mass = mass_value
	body.gravity_scale = 1.0
	body.linear_damp = coin_linear_damp if mesh == money_mesh else 0.18
	body.angular_damp = coin_angular_damp if mesh == money_mesh else 0.24
	body.continuous_cd = true

	if mesh == money_mesh:
		var pm := PhysicsMaterial.new()
		pm.friction = coin_friction
		pm.bounce = coin_bounce
		body.physics_material_override = pm

	host.get_parent().add_child(body)
	body.global_transform = marker.global_transform if marker != null else host.global_transform

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	if mesh == money_mesh:
		mesh_instance.rotation_degrees = coin_mesh_lay_flat_degrees
	body.add_child(mesh_instance)

	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.06
	shape.shape = sphere
	body.add_child(shape)

	_destroy_later(body, maxf(life_time, 0.8))
	return body

func _fallback_find_marker(root: Node, names: Array[String]) -> Node3D:
	if root == null:
		return null
	for n: String in names:
		var direct: Node3D = root.get_node_or_null(n) as Node3D
		if direct != null:
			return direct
		var nested: Node3D = _find_node3d_by_name_recursive(root, n)
		if nested != null:
			return nested
	return null

func _find_node3d_by_name_recursive(root: Node, name_to_find: String) -> Node3D:
	for child: Node in root.get_children():
		if child.name == name_to_find:
			return child as Node3D
		var nested: Node3D = _find_node3d_by_name_recursive(child, name_to_find)
		if nested != null:
			return nested
	return null

func _destroy_later(node: Node, time_sec: float) -> void:
	var timer: SceneTreeTimer = get_tree().create_timer(time_sec)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(node):
			node.queue_free()
	)

func _extract_mesh_from_scene(scene_path: String) -> Mesh:
	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		return null
	var instance: Node = packed.instantiate()
	if instance == null:
		return null
	var mesh: Mesh = _find_first_mesh_recursive(instance)
	instance.queue_free()
	return mesh

func _find_first_mesh_recursive(root: Node) -> Mesh:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		var mesh_node: MeshInstance3D = node as MeshInstance3D
		if mesh_node != null and mesh_node.mesh != null:
			return mesh_node.mesh
		for child: Node in node.get_children():
			stack.append(child)
	return null

func _make_placeholder_mesh(is_coin: bool) -> Mesh:
	if is_coin:
		var sphere := SphereMesh.new()
		sphere.radius = 0.09
		sphere.height = 0.18
		return sphere
	var box := BoxMesh.new()
	box.size = Vector3(0.18, 0.03, 0.08)
	return box
