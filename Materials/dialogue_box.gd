extends Control

signal finished_all

const PIXEL_FONT: FontFile = preload("res://textures/pixeloidsans/PixeloidSans.ttf")

@onready var text_label: RichTextLabel = _resolve_text_label()
@onready var hint: Label = _resolve_hint_label()

var pages: Array[String] = []
var page_i := 0
var typing := false
var speed := 0.03
var _full := ""
var _t := 0.0
var _char_i := 0
var _text_base_position := Vector2.ZERO
var _hint_base_position := Vector2.ZERO

func _ready() -> void:
	if text_label != null:
		text_label.add_theme_font_override("normal_font", PIXEL_FONT)
		text_label.add_theme_font_override("bold_font", PIXEL_FONT)
		text_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_text_base_position = text_label.position
	if hint != null:
		hint.add_theme_font_override("font", PIXEL_FONT)
		hint.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_hint_base_position = hint.position
	set_process(false)

func _resolve_text_label() -> RichTextLabel:
	var direct: RichTextLabel = get_node_or_null("Text") as RichTextLabel
	if direct != null:
		return direct
	return get_node_or_null("RichTextLabel") as RichTextLabel

func _resolve_hint_label() -> Label:
	var direct: Label = get_node_or_null("Hint") as Label
	if direct != null:
		return direct
	return get_node_or_null("Label") as Label

func start_dialogue(new_pages: Array[String], cps := 33.0) -> void:
	speed = 1.0 / max(cps, 1.0)
	pages = new_pages
	page_i = 0
	visible = true
	set_process(true)
	_show_page()

func _show_page() -> void:
	_full = pages[page_i]
	if text_label != null:
		text_label.text = ""
	if hint != null:
		hint.text = "Tap"
		hint.visible = false
	typing = true
	_t = 0.0
	_char_i = 0

func _process(delta: float) -> void:
	if visible:
		var t: float = float(Time.get_ticks_msec()) * 0.001
		if text_label != null:
			text_label.position = _text_base_position + Vector2(sin(t * 2.8) * 0.8, cos(t * 3.3) * 0.55)
		if hint != null:
			hint.position = _hint_base_position + Vector2(sin(t * 2.3 + 0.6) * 0.55, cos(t * 2.7 + 0.3) * 0.35)

	if not typing:
		return
	_t += delta
	while _t >= speed and _char_i < _full.length():
		_t -= speed
		if text_label != null:
			text_label.text += _full[_char_i]
		_char_i += 1
	if _char_i >= _full.length():
		typing = false
		if hint != null:
			hint.visible = true

func next() -> void:
	if not visible:
		return
	if typing:
		typing = false
		if text_label != null:
			text_label.text = _full
		if hint != null:
			hint.visible = true
		return
	page_i += 1
	if page_i >= pages.size():
		visible = false
		set_process(false)
		emit_signal("finished_all")
	else:
		_show_page()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_accept") or event is InputEventMouseButton:
		next()
