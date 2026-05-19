## save_system.gd
## Autoload-синглтон. Добавь в Project → Project Settings → Autoload
## с именем SaveSystem и путём res://Materials/save_system.gd
extends Node

const SAVE_PATH := "user://savegame.cfg"
const SAVE_VERSION := 1

## Возвращает true если файл сохранения существует
func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

## Удаляет сохранение (сброс прогресса)
func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)

## Сохраняет текущее состояние игры.
## data — Dictionary с полями: money, spins_left, tickets, round_data (опционально)
func save_game(data: Dictionary) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", SAVE_VERSION)
	cfg.set_value("meta", "timestamp", Time.get_unix_time_from_system())
	cfg.set_value("player", "money",      int(data.get("money",      0)))
	cfg.set_value("player", "spins_left", int(data.get("spins_left", 0)))
	cfg.set_value("player", "tickets",    int(data.get("tickets",    0)))
	
	# Данные раунда
	var round_data: Dictionary = data.get("round_data", {})
	for key: String in round_data.keys():
		cfg.set_value("round", key, round_data[key])
		
	# Данные тотемов
	var totem_data: Dictionary = data.get("totem_data", {})
	for key: String in totem_data.keys():
		cfg.set_value("totems", key, totem_data[key])
		
	var err := cfg.save(SAVE_PATH)
	if err != OK:
		push_error("[SaveSystem] Не удалось сохранить: %s" % error_string(err))
	else:
		print("[SaveSystem] Прогресс сохранён.")

func load_game() -> Dictionary:
	if not has_save():
		return {}
	var cfg := ConfigFile.new()
	var err := cfg.load(SAVE_PATH)
	if err != OK:
		push_error("[SaveSystem] Не удалось загрузить: %s" % error_string(err))
		return {}

	var result: Dictionary = {}
	result["money"]      = int(cfg.get_value("player", "money",      0))
	result["spins_left"] = int(cfg.get_value("player", "spins_left", 0))
	result["tickets"]    = int(cfg.get_value("player", "tickets",    0))

	var round_data: Dictionary = {}
	if cfg.has_section("round"):
		for key: String in cfg.get_section_keys("round"):
			round_data[key] = cfg.get_value("round", key)
	result["round_data"] = round_data

	var totem_data: Dictionary = {}
	if cfg.has_section("totems"):
		for key: String in cfg.get_section_keys("totems"):
			totem_data[key] = cfg.get_value("totems", key)
	result["totem_data"] = totem_data

	print("[SaveSystem] Прогресс загружен: ", result)
	return result
