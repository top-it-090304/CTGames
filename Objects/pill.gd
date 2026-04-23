extends "res://Objects/totem_item.gd"

@export var pill_common_reduction: int = -2
@export var pill_jackpot_bias: int = 1

func _ready() -> void:
	totem_id = "pill"
	title = "Таблетка"
	description = "Чуть режет частые символы и немного бустит Семерку."
	price_tokens = 3
	bonus_type = "symbol_bias:lemon"
	bonus_value = pill_common_reduction
	extra_bonuses = "symbol_bias:cherry=%d\njackpot_bias=%d" % [pill_common_reduction, pill_jackpot_bias]
	super._ready()
