extends Label

@export var intensity := 6.0
var base_pos: Vector2

func _ready() -> void:
	base_pos = position
	set_process(false)
	visibility_changed.connect(func() -> void: set_process(visible))

func _process(_delta: float) -> void:
	var t: float = float(Time.get_ticks_msec()) * 0.001
	position = base_pos + Vector2(
		sin(t * 20.0) * intensity,
		cos(t * 18.0) * intensity
	)
