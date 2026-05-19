extends "res://Objects/totem_item.gd"

@export var flower_diamond_bias: int = 2

func _ready() -> void:
	totem_id = "flower"
	title = "Цветок"
	description = "Немного повышает шанс Алмазов."
	price_tokens = 2
	bonus_type = "symbol_bias:diamond"
	bonus_value = flower_diamond_bias
	super._ready()
