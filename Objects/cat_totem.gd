extends "res://totem_item.gd"

func _ready() -> void:
	totem_id = "cat"
	title = "Кот"
	description = "+1 Ф к любому выигрышу"
	price_tokens = 3
	bonus_type = "flat_win_bonus"
	bonus_value = 1
	super._ready()
