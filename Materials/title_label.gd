extends Label

@export var shake_strength := 0.6
var base_position: Vector2

func _ready() -> void:
	base_position = position
	set_process(false)
	visibility_changed.connect(func() -> void: set_process(visible))

func _process(_delta: float) -> void:
	position = base_position + Vector2(
		randf_range(-shake_strength, shake_strength),
		randf_range(-shake_strength, shake_strength)
	)
