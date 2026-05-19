@tool
extends Node3D

@export var preview_in_editor: bool = true:
	set(value):
		preview_in_editor = value
		_rebuild()
@export var frame_width: float = 9.2:
	set(value):
		frame_width = maxf(value, 0.1)
		_rebuild()
@export var frame_height: float = 6.8:
	set(value):
		frame_height = maxf(value, 0.1)
		_rebuild()
@export var frame_depth: float = 0.08:
	set(value):
		frame_depth = maxf(value, 0.001)
		_rebuild()
@export var border_thickness: float = 0.22:
	set(value):
		border_thickness = maxf(value, 0.01)
		_rebuild()
@export var border_inset: float = 0.0:
	set(value):
		border_inset = value
		_rebuild()
@export var backdrop_z: float = -0.06:
	set(value):
		backdrop_z = value
		_rebuild()
@export var frame_z: float = 0.0:
	set(value):
		frame_z = value
		_rebuild()
@export var backdrop_color: Color = Color(0, 0, 0, 1):
	set(value):
		backdrop_color = value
		_rebuild()
@export var frame_color: Color = Color(1.0, 0.52, 0.08, 1.0):
	set(value):
		frame_color = value
		_rebuild()
@export var emission_color: Color = Color(1.0, 0.45, 0.08, 1.0):
	set(value):
		emission_color = value
		_rebuild()
@export var emission_energy: float = 1.2:
	set(value):
		emission_energy = maxf(value, 0.0)
		_rebuild()

const GENERATED_PREFIX: String = "_generated_"

func _enter_tree() -> void:
	if Engine.is_editor_hint():
		call_deferred("_rebuild")

func _ready() -> void:
	_rebuild()

func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE and Engine.is_editor_hint():
		call_deferred("_rebuild")

func _rebuild() -> void:
	if not is_inside_tree():
		return
	if Engine.is_editor_hint() and not preview_in_editor:
		_clear_generated()
		return
	_clear_generated()
	_create_backdrop()
	_create_frame()

func _clear_generated() -> void:
	for child: Node in get_children():
		if child.name.begins_with(GENERATED_PREFIX):
			child.free()

func _create_backdrop() -> void:
	var backdrop := MeshInstance3D.new()
	backdrop.name = GENERATED_PREFIX + "Backdrop"
	var quad := QuadMesh.new()
	quad.size = Vector2(frame_width, frame_height)
	backdrop.mesh = quad
	backdrop.position = Vector3(0.0, 0.0, backdrop_z)
	backdrop.material_override = _make_unshaded_material(backdrop_color, Color.BLACK, 0.0)
	add_child(backdrop)
	_assign_owner(backdrop)

func _create_frame() -> void:
	var inner_width: float = maxf(frame_width - border_inset * 2.0, border_thickness)
	var inner_height: float = maxf(frame_height - border_inset * 2.0, border_thickness)
	var half_w: float = inner_width * 0.5
	var half_h: float = inner_height * 0.5
	var half_t: float = border_thickness * 0.5

	_create_bar(
		GENERATED_PREFIX + "Top",
		Vector3(inner_width, border_thickness, frame_depth),
		Vector3(0.0, half_h - half_t, frame_z)
	)
	_create_bar(
		GENERATED_PREFIX + "Bottom",
		Vector3(inner_width, border_thickness, frame_depth),
		Vector3(0.0, -half_h + half_t, frame_z)
	)
	_create_bar(
		GENERATED_PREFIX + "Left",
		Vector3(border_thickness, inner_height, frame_depth),
		Vector3(-half_w + half_t, 0.0, frame_z)
	)
	_create_bar(
		GENERATED_PREFIX + "Right",
		Vector3(border_thickness, inner_height, frame_depth),
		Vector3(half_w - half_t, 0.0, frame_z)
	)

func _create_bar(node_name: String, mesh_size: Vector3, mesh_position: Vector3) -> void:
	var bar := MeshInstance3D.new()
	bar.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = mesh_size
	bar.mesh = mesh
	bar.position = mesh_position
	bar.material_override = _make_unshaded_material(frame_color, emission_color, emission_energy)
	add_child(bar)
	_assign_owner(bar)

func _assign_owner(node: Node) -> void:
	if not Engine.is_editor_hint():
		return
	var edited_root: Node = get_tree().edited_scene_root
	if edited_root != null:
		node.owner = edited_root

func _make_unshaded_material(albedo: Color, emission: Color, energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = albedo
	mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.emission_enabled = energy > 0.0
	mat.emission = emission
	mat.emission_energy_multiplier = energy
	return mat
