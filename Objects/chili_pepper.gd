extends "res://Objects/totem_item.gd"

@export var pepper_bonus_rounds: int = 3

func _ready() -> void:
	totem_id = "pepper"
	title = "Перец"
	description = "Подогревает удачу на %d раунда.\n[b]Семёрки[/b] чуть чаще (джекпот)." % pepper_bonus_rounds
	price_tokens = 5
	bonus_type = "jackpot_bias"
	bonus_value = pepper_bonus_rounds
	super._ready()
