extends Control

signal finished_all

@onready var text_label: RichTextLabel = $Text
@onready var hint: Label = $Hint

var pages: Array[String] = []
var page_i := 0
var typing := false
var speed := 0.03
var _full := ""
var _t := 0.0
var _char_i := 0

func start_dialogue(new_pages: Array[String], cps := 33.0):
	
	speed = 1.0 / max(cps, 1.0)
	pages = new_pages
	page_i = 0
	visible = true
	_show_page()

func _show_page():
	_full = pages[page_i]
	text_label.text = ""
	hint.text = "Enter / Tap"
	hint.visible = false
	typing = true
	_t = 0.0
	_char_i = 0

func _process(delta):
	if not typing:
		return
	_t += delta
	while _t >= speed and _char_i < _full.length():
		_t -= speed
		text_label.text += _full[_char_i]
		_char_i += 1
	if _char_i >= _full.length():
		typing = false
		hint.visible = true

func next():
	if not visible:
		return

	
	if typing:
		typing = false
		text_label.text = _full
		hint.visible = true
		return

	
	page_i += 1
	if page_i >= pages.size():
		visible = false
		emit_signal("finished_all")
	else:
		_show_page()

func _unhandled_input(event):
	if not visible:
		return
	if event.is_action_pressed("ui_accept") or event is InputEventMouseButton:
		next()
