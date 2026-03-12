extends Label

@export var shake_strength := 0.6
var base_position: Vector2

func _ready():
	base_position = position

func _process(delta):
	position = base_position + Vector2(
		randf_range(-shake_strength, shake_strength),
		randf_range(-shake_strength, shake_strength)
	)
