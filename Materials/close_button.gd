extends Button

@export var shake_strength := 0.6
var base_position: Vector2

func _ready():
	base_position = position
	set_process(false)
	visibility_changed.connect(_on_visibility_changed)

func _on_visibility_changed() -> void:
	set_process(visible)

func _process(_delta: float) -> void:
	position = base_position + Vector2(
		randf_range(-shake_strength, shake_strength),
		randf_range(-shake_strength, shake_strength)
	)
