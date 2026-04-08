extends Control

@export var pulse_speed: float = 3.6
@export var outer_alpha: float = 0.78
@export var fill_alpha: float = 0.18
@export var inner_fill_alpha: float = 0.22
@export var border_width: float = 5.0
@export var glow_width: float = 9.0

var _rects: Array[Rect2] = []
var _palette_index: int = 0
var _palettes: Array[Array] = [
	[Color(1.0, 0.05, 0.96, 1.0), Color(1.0, 0.80, 0.18, 1.0)],
	[Color(0.30, 0.95, 1.0, 1.0), Color(0.24, 1.0, 0.74, 1.0)],
	[Color(1.0, 0.30, 0.70, 1.0), Color(0.64, 0.92, 1.0, 1.0)],
	[Color(1.0, 0.70, 0.14, 1.0), Color(1.0, 0.36, 0.12, 1.0)],
]

func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2.ZERO
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 80
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
	var glow_outer: Color = Color(glow.r, glow.g, glow.b, outer_alpha)
	var glow_mid: Color = Color(edge.r, edge.g, edge.b, minf(outer_alpha + 0.08, 1.0))
	var dark_fill: Color = Color(0.18, 0.02, 0.03, inner_fill_alpha)
	var tint_fill: Color = Color(edge.r, edge.g, edge.b, fill_alpha)
	var shine: Color = Color(1.0, 1.0, 1.0, 0.20 + 0.08 * t)

	for rect: Rect2 in _rects:
		var frame_rect: Rect2 = rect.grow(-8.0)
		if frame_rect.size.x <= 8.0 or frame_rect.size.y <= 8.0:
			frame_rect = rect

		draw_rect(frame_rect, dark_fill, true)
		draw_rect(frame_rect.grow(-3.0), tint_fill, true)
		draw_rect(frame_rect.grow(glow_width), Color(glow_outer.r, glow_outer.g, glow_outer.b, glow_outer.a * 0.26), false, border_width + 6.0)
		draw_rect(frame_rect.grow(4.0), Color(glow_mid.r, glow_mid.g, glow_mid.b, glow_mid.a * 0.45), false, border_width + 2.0)
		draw_rect(frame_rect, edge, false, border_width)
		draw_rect(frame_rect.grow(-2.0), shine, false, 1.5)
