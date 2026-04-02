extends Control

@onready var text_label = $VBoxContainer/Label
@onready var continue_button = $VBoxContainer/Button

var full_text = "Привет.\n\nТы попал в систему.\nЗдесь никто не выигрывает.\n\nТвоя задача — выжить."

func _ready():
	text_label.text = full_text
	continue_button.pressed.connect(_on_continue_pressed)

func _on_continue_pressed():
	get_tree().change_scene_to_file("res://Game.tscn")
