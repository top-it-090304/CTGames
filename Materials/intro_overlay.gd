extends Node

signal active_changed(active: bool)
signal camera_hint_requested(hint: String)

@export var target_canvaslayer_path: NodePath = ^"../UI"
@export var start_on_ready: bool = true
@export var chars_per_sec: float = 42.0
@onready var evil_voice: AudioStreamPlayer3D = get_node_or_null("EvilVoice")
const COLOR_TEXT := "#FFFFFF"
const COLOR_COIN := "#F0D34E"
const FONT_SIZE := 34
const PIXEL_FONT: FontFile = preload("res://textures/pixeloidsans/PixeloidSans.ttf")

var _hud_layer: CanvasLayer
var _box: Panel
var _text: RichTextLabel
var _hint: Label
var _choices: HBoxContainer
var _btn_yes: Button
var _btn_no: Button

var _active := false
var _steps: Array[Dictionary] = []
var _step_i := 0

var _typing := false
var _char_progress := 0.0
var _waiting_choice := false
var _no_branch := false

var _pending_steps: Array[Dictionary] = []

func _ready() -> void:
	_setup_ui()
	if start_on_ready:
		if not SaveSystem.has_save():
			start(_build_default_steps())

func start(steps: Array[Dictionary] = []) -> void:
	var actual_steps: Array[Dictionary] = steps
	if actual_steps.is_empty():
		actual_steps = _build_default_steps()

	if _box == null or _text == null:
		_pending_steps = actual_steps.duplicate(true)
		call_deferred("_setup_ui")
		return

	_steps = actual_steps.duplicate(true)
	_step_i = 0
	_no_branch = false
	_active = true
	_box.visible = true
	emit_signal("active_changed", true)
	_show_step()

func is_active() -> bool:
	return _active

func _setup_ui() -> void:
	_hud_layer = get_node_or_null(target_canvaslayer_path) as CanvasLayer
	if _hud_layer == null:
		_hud_layer = get_node_or_null("../MainHUD") as CanvasLayer
	if _hud_layer == null:
		_hud_layer = get_node_or_null("../UI") as CanvasLayer
	if _hud_layer == null:
		call_deferred("_setup_ui")
		return

	_box = _hud_layer.get_node_or_null("IntroDialogueBox") as Panel
	if _box == null:
		_box = Panel.new()
		_box.name = "IntroDialogueBox"
		_hud_layer.add_child(_box)

	_text = _box.get_node_or_null("Text") as RichTextLabel
	if _text == null:
		_text = RichTextLabel.new()
		_text.name = "Text"
		_box.add_child(_text)

	_hint = _box.get_node_or_null("Hint") as Label
	if _hint == null:
		_hint = Label.new()
		_hint.name = "Hint"
		_box.add_child(_hint)

	_choices = _box.get_node_or_null("Choices") as HBoxContainer
	if _choices == null:
		_choices = HBoxContainer.new()
		_choices.name = "Choices"
		_box.add_child(_choices)

	_btn_yes = _choices.get_node_or_null("Yes") as Button
	if _btn_yes == null:
		_btn_yes = Button.new()
		_btn_yes.name = "Yes"
		_btn_yes.text = "Да"
		_choices.add_child(_btn_yes)

	_btn_no = _choices.get_node_or_null("No") as Button
	if _btn_no == null:
		_btn_no = Button.new()
		_btn_no.name = "No"
		_btn_no.text = "Нет"
		_choices.add_child(_btn_no)

	if not _btn_yes.pressed.is_connected(_on_yes_pressed):
		_btn_yes.pressed.connect(_on_yes_pressed)
	if not _btn_no.pressed.is_connected(_on_no_pressed):
		_btn_no.pressed.connect(_on_no_pressed)

	_box.anchor_left = 0.0
	_box.anchor_right = 1.0
	_box.anchor_top = 1.0
	_box.anchor_bottom = 1.0
	_box.offset_left = 0.0
	_box.offset_right = 0.0
	_box.offset_top = -182.0
	_box.offset_bottom = 0.0
	_box.mouse_filter = Control.MOUSE_FILTER_STOP

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 1.0)
	bg.corner_radius_top_left = 0
	bg.corner_radius_top_right = 0
	bg.corner_radius_bottom_left = 0
	bg.corner_radius_bottom_right = 0
	_box.add_theme_stylebox_override("panel", bg)

	_text.anchor_left = 0.0
	_text.anchor_right = 1.0
	_text.anchor_top = 0.0
	_text.anchor_bottom = 1.0
	_text.offset_left = 34.0
	_text.offset_right = -34.0
	_text.offset_top = 22.0
	_text.offset_bottom = -70.0
	_text.bbcode_enabled = true
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD
	_text.scroll_active = false
	_text.add_theme_font_override("normal_font", PIXEL_FONT)
	_text.add_theme_font_override("bold_font", PIXEL_FONT)
	_text.add_theme_font_size_override("normal_font_size", FONT_SIZE)
	_text.add_theme_font_size_override("bold_font_size", FONT_SIZE)
	_text.add_theme_color_override("default_color", Color(1.0, 1.0, 1.0, 1.0))
	_text.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1.0))
	_text.add_theme_constant_override("outline_size", 2)
	_text.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	_hint.anchor_left = 0.0
	_hint.anchor_right = 1.0
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.offset_left = 26.0
	_hint.offset_right = -26.0
	_hint.offset_top = -44.0
	_hint.offset_bottom = -12.0
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.text = "Tap — далее"
	_hint.add_theme_font_override("font", PIXEL_FONT)
	_hint.add_theme_font_size_override("font_size", 24)
	_hint.add_theme_color_override("font_color", Color(0.86, 0.86, 0.86, 1.0))
	_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1.0))
	_hint.add_theme_constant_override("outline_size", 2)
	_hint.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_hint.visible = false

	_choices.anchor_left = 1.0
	_choices.anchor_right = 1.0
	_choices.anchor_top = 1.0
	_choices.anchor_bottom = 1.0
	_choices.offset_left = -230.0
	_choices.offset_right = -18.0
	_choices.offset_top = -106.0
	_choices.offset_bottom = -46.0
	_choices.alignment = BoxContainer.ALIGNMENT_END
	_choices.add_theme_constant_override("separation", 20)
	_choices.mouse_filter = Control.MOUSE_FILTER_STOP
	_choices.visible = false

	for btn: Button in [_btn_yes, _btn_no]:
		btn.custom_minimum_size = Vector2(96.0, 52.0)
		btn.focus_mode = Control.FOCUS_NONE
		btn.flat = true
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.add_theme_font_override("font", PIXEL_FONT)
		btn.add_theme_font_size_override("font_size", 56)
		btn.add_theme_color_override("font_color",          Color(0.95, 0.95, 0.95, 1.0))
		btn.add_theme_color_override("font_hover_color",    Color(1.0, 0.86, 0.08, 1.0))
		btn.add_theme_color_override("font_pressed_color", Color(0.75, 0.75, 0.75, 1.0))
		btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1.0))
		btn.add_theme_constant_override("outline_size", 2)
		btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	_box.visible = false

	if not _pending_steps.is_empty() and not _active:
		var queued: Array[Dictionary] = _pending_steps.duplicate(true)
		_pending_steps.clear()
		start(queued)

func _process(delta: float) -> void:
	if not _active or not _typing:
		return

	_char_progress += delta * chars_per_sec
	_text.visible_characters = int(_char_progress)
	if _text.visible_characters >= _text.get_total_character_count():
		_typing = false
		if evil_voice != null:
			evil_voice.stop()
		if _waiting_choice:
			_choices.visible = true
		else:
			_hint.visible = true

func _input(event: InputEvent) -> void:
	if not _active:
		return

	if _waiting_choice:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		if k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER or k.keycode == KEY_SPACE:
			_next()
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_next()
			get_viewport().set_input_as_handled()
			return

	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_next()
			get_viewport().set_input_as_handled()
			return

func _next() -> void:
	if _typing:
		_text.visible_characters = _text.get_total_character_count()
		_typing = false
		if evil_voice != null:
			evil_voice.stop()
		if _waiting_choice:
			_choices.visible = true
		else:
			_hint.visible = true
		return

	if _waiting_choice:
		return

	if _no_branch:
		_finish()
		return

	_step_i += 1
	_show_step()

func _show_step() -> void:
	if _step_i >= _steps.size():
		_finish()
		return

	var step: Dictionary = _steps[_step_i]
	var raw_text: String = String(step.get("text", ""))
	_text.text = _style_line(raw_text)
	_text.visible_characters = 0
	_char_progress = 0.0
	_typing = true
	_waiting_choice = step.get("choice", false)
	if evil_voice != null and not evil_voice.playing:
		evil_voice.play()
	_choices.visible = false
	_hint.text = "Tap — далее"
	_hint.visible = false

	var cam_hint: String = String(step.get("camera_hint", ""))
	if not cam_hint.is_empty():
		emit_signal("camera_hint_requested", cam_hint)

func _finish() -> void:
	_active = false
	_waiting_choice = false
	_no_branch = false
	_typing = false
	if _box != null:
		_box.visible = false
	emit_signal("active_changed", false)

func _on_yes_pressed() -> void:
	if not _active or not _waiting_choice:
		return
	_waiting_choice = false
	_choices.visible = false
	_hint.visible = false
	_step_i += 1
	_show_step()

func _on_no_pressed() -> void:
	if not _active or not _waiting_choice:
		return
	_waiting_choice = false
	_choices.visible = false
	_no_branch = true
	_text.text = _style_line("Ну и сам разбирайся!")
	_text.visible_characters = 0
	_char_progress = 0.0
	_typing = true
	_hint.text = "Tap — закрыть"
	_hint.visible = false

func _style_line(raw_text: String) -> String:
	var colored: String = _highlight_coin_words(raw_text)
	return "[font_size=%d][b][color=%s]%s[/color][/b][/font_size]" % [FONT_SIZE, COLOR_TEXT, colored]

func _highlight_coin_words(raw_text: String) -> String:
	var rx := RegEx.new()
	rx.compile("(?i)монет[а-яё]*")
	var out := ""
	var from_i := 0
	for m: RegExMatch in rx.search_all(raw_text):
		var s: int = m.get_start()
		var e: int = m.get_end()
		out += raw_text.substr(from_i, s - from_i)
		out += "[color=%s]%s[/color]" % [COLOR_COIN, m.get_string()]
		from_i = e
	out += raw_text.substr(from_i)
	return out

func _build_default_steps() -> Array[Dictionary]:
	return [
		{"text": "Добро пожаловать! Говорят, ты обожаешь игры!"},
		{"text": "Тогда ты по адресу! Здесь можно играть сколько душе угодно!"},
		{"text": "Что ж... Объяснить тебе, как здесь все устроено?", "choice": true},
		{"text": "...Тогда слушай внимательно! Повторять я не буду!"},
		{"text": "Сюда нужно вносить полученные монеты!"},
		{"text": "Если не внесешь указанное число монет за отведенные раунды... Эм, в общем, увидишь!", "camera_hint": "debt_machine"},
		{"text": "В конце каждого раунда тебе полагаются проценты от внесенных монет. Чем больше взнос, тем больше доход!"},
		{"text": "Если внесешь долг досрочно, получишь билеты в подарок за каждый оставшийся раунд!", "camera_hint": "ticket_machine"},
		{"text": "Так... Перейдем к слот-машине!!! Только тебе решать, сколько спинов будет в раунде!", "camera_hint": "slot_machine"},
		{"text": "В конце каждого раунда тебе также полагается 1 билет. Или больше — при определенных условиях."},
		{"text": "Ты можешь потратить билеты на покупку талисманов! Они повысят твой шанс на выживание!"},
		{"text": "Ну все, я закругляюсь! Ты все равно все не запомнишь!"}
	]
