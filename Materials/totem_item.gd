extends Node3D

signal pressed(item: Node3D)

@export var totem_id: String = "cat"
@export var title: String = "Кот"
@export_multiline var description: String = "+1 Ф к любому выигрышу"
@export var price_tokens: int = 3
@export var bonus_type: String = "flat_win_bonus"
@export var bonus_value: int = 1
@export var interact_area_path: NodePath = ^"InteractArea"

var _interact_area: Area3D
var _shop_enabled: bool = true

func _ready() -> void:
	_interact_area = get_node_or_null(interact_area_path) as Area3D
	if _interact_area == null:
		push_warning("Totem item '%s' has no InteractArea" % name)
		return
	_interact_area.input_ray_pickable = true
	var cb: Callable = Callable(self, "_on_interact_input_event")
	if not _interact_area.input_event.is_connected(cb):
		_interact_area.input_event.connect(cb)

func get_offer_data() -> Dictionary:
	return {
		"id": totem_id,
		"title": title,
		"description": description,
		"price": maxi(price_tokens, 0),
		"bonus_type": bonus_type,
		"bonus_value": bonus_value,
	}

func set_shop_enabled(active: bool) -> void:
	_shop_enabled = active
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
