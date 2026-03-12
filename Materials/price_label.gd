extends Label

@export var intensity := 6.0
var base_pos: Vector2

func _ready():
	base_pos = position

func _process(delta):
	position = base_pos + Vector2(
		sin(Time.get_ticks_msec() * 0.02) * intensity,
		cos(Time.get_ticks_msec() * 0.018) * intensity
	)
