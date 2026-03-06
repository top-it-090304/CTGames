extends Node2D

@onready var play_button = $Play
@onready var quit_button = $Quit
@onready var message = $Label

var full_text = ""
var char_index = 0
var speed = 0.03

func _on_play_pressed():
	get_tree().change_scene_to_file("res://Materials/game.tscn")

func _on_quit_pressed():
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
	
func fade_out_text():
	var tween = create_tween()
	tween.tween_property(message, "modulate:a", 0.0, 2.0)
	await tween.finished
	message.visible = false
func move_play_button():
	var tween = create_tween()
	var target_y = get_viewport_rect().size.y * 0.6
	tween.tween_property(play_button, "position:y", target_y, 1.5)
