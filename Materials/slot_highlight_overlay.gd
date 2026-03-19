extends Control

@export var pulse_speed: float = 4.8
@export var outer_alpha: float = 0.22
@export var fill_alpha: float = 0.10

var _rects: Array[Rect2] = []
var _palette_index: int = 0
var _palettes: Array[Array] = [
	[Color(0.33, 1.0, 0.35, 1.0), Color(1.0, 0.92, 0.22, 1.0)],
	[Color(0.18, 0.95, 1.0, 1.0), Color(0.86, 0.28, 1.0, 1.0)],
	[Color(1.0, 0.55, 0.12, 1.0), Color(1.0, 0.18, 0.18, 1.0)],
	[Color(1.0, 0.38, 0.72, 1.0), Color(0.52, 0.95, 1.0, 1.0)],
]

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

func _process(_delta: float) -> void:
	if visible and not _rects.is_empty():
		queue_redraw()

func set_highlights(rects: Array, palette_index: int) -> void:
	_rects.clear()
	for rect_var: Variant in rects:
		if rect_var is Rect2:
			var rect: Rect2 = rect_var
			if rect.size.x > 0.0 and rect.size.y > 0.0:
				_rects.append(rect)
	_palette_index = posmod(palette_index, _palettes.size())
	visible = not _rects.is_empty()
	queue_redraw()

func clear_highlights() -> void:
	_rects.clear()
	visible = false
	queue_redraw()

func _draw() -> void:
	if _rects.is_empty() or _palettes.is_empty():
		return

	var palette: Array = _palettes[_palette_index]
	var c0: Color = palette[0]
	var c1: Color = palette[1]
	var t: float = 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.001 * pulse_speed)
	var edge: Color = c0.lerp(c1, t)
	var glow: Color = c1.lerp(c0, t)
	var fill: Color = Color(glow.r, glow.g, glow.b, fill_alpha)
	var outer: Color = Color(glow.r, glow.g, glow.b, outer_alpha)
	var white_shine: Color = Color(1.0, 1.0, 1.0, 0.16)

	for rect: Rect2 in _rects:
		draw_rect(rect, fill, true)
		draw_rect(rect.grow(7.0), outer, false, 5.0)
		draw_rect(rect.grow(3.0), glow, false, 3.0)
		draw_rect(rect, edge, false, 3.0)
		draw_rect(rect.grow(-2.0), white_shine, false, 1.0)
