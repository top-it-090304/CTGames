extends Button

@export var shake_strength: float = 0.7
@export var cycle_seconds: float = 1.0
@export var border_width: int = 3
@export var bg_color: Color = Color(0.02, 0.02, 0.02, 0.92)
@export var border_colors: Array[Color] = [
	Color(1.0, 0.48, 0.08, 1.0),
	Color(1.0, 0.82, 0.18, 1.0),
	Color(1.0, 1.0, 1.0, 1.0),
]

var base_position: Vector2
var _last_color_index: int = -1

func _ready() -> void:
	base_position = position
	focus_mode = Control.FOCUS_NONE
	flat = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_border_color(border_colors[0] if not border_colors.is_empty() else Color(1.0, 0.48, 0.08, 1.0))

func _process(_delta: float) -> void:
	var t: float = float(Time.get_ticks_msec()) * 0.001
	position = base_position + Vector2(
		sin(t * 3.1) * shake_strength,
		cos(t * 2.7) * shake_strength * 0.8
	)

	if border_colors.is_empty():
		return
	var safe_cycle: float = max(cycle_seconds, 0.1)
	var idx: int = int(floor(t / safe_cycle)) % border_colors.size()
	if idx != _last_color_index:
		_last_color_index = idx
		_apply_border_color(border_colors[idx])

func _apply_border_color(color: Color) -> void:
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style: StyleBoxFlat = get_theme_stylebox(state) as StyleBoxFlat
		if style != null:
			style = style.duplicate() as StyleBoxFlat
		else:
			style = StyleBoxFlat.new()
		style.bg_color = bg_color
		style.border_width_left = border_width
		style.border_width_top = border_width
		style.border_width_right = border_width
		style.border_width_bottom = border_width
		style.border_color = color
		add_theme_stylebox_override(state, style)
