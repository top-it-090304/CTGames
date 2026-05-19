extends "res://Objects/totem_item.gd"

@export var pony_bonus_rounds: int = 3

func _ready() -> void:
	totem_id = "pony"
	title = "Пони"
	description = "Увеличивает шанс крупных символов на %d раунда.\n[b]Алмаз[/b] и [b]Сундук[/b] чаще." % pony_bonus_rounds
	price_tokens = 4
	bonus_type = "big_symbol_bias"
	bonus_value = pony_bonus_rounds
	super._ready()
