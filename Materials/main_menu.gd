extends Node2D

@onready var play_button = $Play
@onready var quit_button = $Quit
@onready var message = $Label

var play_locked
var full_text = ""
var char_index = 0
var speed = 0.03

func _ready():
	_configure_button(play_button)
	_configure_button(quit_button)
	_configure_label(message)

func _configure_button(btn: Button) -> void:
	btn.add_theme_color_override("font_color",         Color(1.0, 1.0, 1.0, 1.0))
	btn.add_theme_color_override("font_hover_color",   Color(1.0, 0.86, 0.08, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color(0.8, 0.65, 0.0,  1.0))
	btn.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0,   1.0))
	btn.add_theme_constant_override("outline_size", 3)
	btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.15, 0.15, 0.15, 0.9)
	normal.corner_radius_top_left     = 8
	normal.corner_radius_top_right    = 8
	normal.corner_radius_bottom_left  = 8
	normal.corner_radius_bottom_right = 8

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.25, 0.22, 0.05, 1.0)
	hover.corner_radius_top_left     = 8
	hover.corner_radius_top_right    = 8
	hover.corner_radius_bottom_left  = 8
	hover.corner_radius_bottom_right = 8

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(0.18, 0.15, 0.02, 1.0)
	pressed.corner_radius_top_left     = 8
	pressed.corner_radius_top_right    = 8
	pressed.corner_radius_bottom_left  = 8
	pressed.corner_radius_bottom_right = 8

	btn.add_theme_stylebox_override("normal",  normal)
	btn.add_theme_stylebox_override("hover",   hover)
	btn.add_theme_stylebox_override("pressed", pressed)

func _configure_label(lbl: Label) -> void:
	lbl.add_theme_color_override("font_color",         Color(1.0, 1.0, 1.0, 1.0))
	lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _on_play_pressed():
	if play_locked:
		return
	get_tree().change_scene_to_file("res://Materials/game.tscn")

func _on_quit_pressed():
	play_locked = true
	quit_button.visible = false

	full_text = "Думаешь так легко уйти от ответственности?"
	message.text = full_text
	message.visible = true
	message.visible_characters = 0

	char_index = 0
	type_text()

func type_text():
	while char_index <= full_text.length():
		message.visible_characters = char_index
		char_index += 1
		await get_tree().create_timer(speed).timeout
	await get_tree().create_timer(3).timeout
	fade_out_text()
	move_play_button()
	await get_tree().create_timer(2).timeout
	play_locked = false

func fade_out_text():
	var tween = create_tween()
	tween.tween_property(message, "modulate:a", 0.0, 2.0)
	await tween.finished
	message.visible = false

func move_play_button():
	var tween = create_tween()
	var target_y = get_viewport_rect().size.y * 0.6
	tween.tween_property(play_button, "position:y", target_y, 1.5)
