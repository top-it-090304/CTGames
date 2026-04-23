extends "res://Objects/totem_item.gd"

@export var gem_diamond_bias: int = 3
@export var gem_win_multiplier_percent: int = 10

func _ready() -> void:
	totem_id = "gem_green"
	title = "Изумруд"
	description = "Сильнее повышает шанс Алмазов и немного усиливает выигрыш."
	price_tokens = 4
	bonus_type = "symbol_bias:diamond"
	bonus_value = gem_diamond_bias
	extra_bonuses = "win_multiplier_percent=%d" % gem_win_multiplier_percent
	super._ready()
