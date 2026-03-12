extends Node2D

@onready var play_button = $Play
@onready var quit_button = $Quit
@onready var message = $Label

var play_locked

var full_text = ""
var char_index = 0
var speed = 0.03

@export var shake_strength := 1.5

var base_play_pos: Vector2
var base_quit_pos: Vector2
var base_label_pos: Vector2


func _ready():
	base_play_pos = play_button.position
	base_quit_pos = quit_button.position
	base_label_pos = message.position


func _process(delta):
	play_button.position = base_play_pos + Vector2(
		randf_range(-shake_strength, shake_strength),
		randf_range(-shake_strength, shake_strength)
	)

	quit_button.position = base_quit_pos + Vector2(
		randf_range(-shake_strength, shake_strength),
		randf_range(-shake_strength, shake_strength)
	)

	message.position = base_label_pos + Vector2(
		randf_range(-shake_strength, shake_strength),
		randf_range(-shake_strength, shake_strength)
	)


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
	base_play_pos.y = target_y
	tween.tween_property(play_button, "position:y", target_y, 1.5)
	await tween.finished
