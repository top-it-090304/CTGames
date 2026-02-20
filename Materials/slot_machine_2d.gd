extends Control

@onready var reel1 = $HBoxContainer/Reel1
@onready var reel2 = $HBoxContainer/Reel2
@onready var reel3 = $HBoxContainer/Reel3

func _on_SpinButton_pressed():
	
	
	reel1.start_spin()
	reel2.start_spin()
	reel3.start_spin()
	
	await get_tree().create_timer(1.5).timeout
	reel1.stop_spin()
	
	await get_tree().create_timer(0.4).timeout
	reel2.stop_spin()
	
	await get_tree().create_timer(0.4).timeout
	reel3.stop_spin()
