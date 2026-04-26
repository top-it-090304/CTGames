extends Panel

## Панель купленных тотемов.
## Автоматически скрывается (fade) во время вращения барабанов.
## Метод add_totem(offer) добавляет карточку с анимацией.

const PIXEL_FONT := preload("res://textures/pixeloidsans/PixeloidSans.ttf")

# Путь к SlotUI (можно задать в Inspector; если пусто — ищем по имени)
@export var slot_ui_path: NodePath = ^""

var _slot_ui: Node = null
var _list: VBoxContainer = null

# ─── Инициализация ────────────────────────────────────────────────────────────

func _ready() -> void:
	# Найти SlotUI
	if slot_ui_path != NodePath("") and not slot_ui_path.is_empty():
		_slot_ui = get_node_or_null(slot_ui_path)
	if _slot_ui == null:
		var root: Node = get_tree().current_scene
		if root == null:
			root = get_tree().get_root()
		_slot_ui = _find_by_name(root, "SlotUI")

	_list = get_node_or_null("TotemList") as VBoxContainer

	# Применяем шрифт к заглушке и заголовку (созданы в редакторе)
	var title_lbl: Label = get_node_or_null("TitleLabel") as Label
	if title_lbl != null:
		title_lbl.add_theme_font_override("font", PIXEL_FONT)
	var empty_lbl: Label
	if _list != null:
		empty_lbl = _list.get_node_or_null("EmptyLabel") as Label
	if empty_lbl != null:
		empty_lbl.add_theme_font_override("font", PIXEL_FONT)

	modulate.a = 1.0

# ─── Fade при вращении ────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	var spinning: bool = (
		_slot_ui != null
		and _slot_ui.has_method("is_spinning")
		and _slot_ui.call("is_spinning")
	)
	var target: float = 0.0 if spinning else 1.0
	modulate.a = move_toward(modulate.a, target, delta * 6.0)

# ─── Добавить карточку тотема ────────────────────────────────────────────────

func add_totem(offer: Dictionary) -> void:
	if _list == null:
		_list = get_node_or_null("TotemList") as VBoxContainer
	if _list == null:
		return

	# Скрываем заглушку
	var empty: Label = _list.get_node_or_null("EmptyLabel") as Label
	if empty != null:
		empty.visible = false

	var title_s: String  = String(offer.get("title", "?"))
	var bonus_val: int   = int(offer.get("bonus_value", 0))

	# Карточка
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.modulate.a   = 0.0

	var style := StyleBoxFlat.new()
	style.bg_color                   = Color(0.10, 0.07, 0.18, 0.92)
	style.border_color               = Color(0.55, 0.42, 0.12, 0.5)
	style.border_width_left          = 1
	style.border_width_right         = 1
	style.border_width_top           = 1
	style.border_width_bottom        = 1
	style.corner_radius_top_left     = 4
	style.corner_radius_top_right    = 4
	style.corner_radius_bottom_left  = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left        = 8
	style.content_margin_right       = 8
	style.content_margin_top         = 5
	style.content_margin_bottom      = 5
	card.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(hbox)

	# Название тотема
	var name_lbl := Label.new()
	name_lbl.text = title_s
	name_lbl.add_theme_font_override("font", PIXEL_FONT)
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.75, 1.0))
	name_lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	name_lbl.add_theme_constant_override("outline_size", 1)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.vertical_alignment    = VERTICAL_ALIGNMENT_CENTER
	name_lbl.mouse_filter          = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(name_lbl)

	# Значение бонуса
	if bonus_val != 0:
		var bonus_lbl := Label.new()
		bonus_lbl.text = "+%d" % bonus_val if bonus_val > 0 else "%d" % bonus_val
		bonus_lbl.add_theme_font_override("font", PIXEL_FONT)
		bonus_lbl.add_theme_font_size_override("font_size", 13)
		bonus_lbl.add_theme_color_override("font_color", Color(0.45, 1.0, 0.45, 1.0))
		bonus_lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
		bonus_lbl.add_theme_constant_override("outline_size", 1)
		bonus_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		bonus_lbl.mouse_filter       = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(bonus_lbl)

	_list.add_child(card)

	# Анимация: появление карточки
	var tw: Tween = create_tween()
	tw.tween_property(card, "modulate:a", 1.0, 0.35).set_ease(Tween.EASE_OUT)

	# Анимация: рост панели
	_animate_height()

# ─── Анимированное изменение высоты ──────────────────────────────────────────

func _animate_height() -> void:
	if _list == null:
		return
	var count: int = 0
	for child: Node in _list.get_children():
		if child.name != "EmptyLabel" and child.visible:
			count += 1

	# 36px на заголовок+разделитель, 32px на каждую карточку, 5px зазор между ними
	var content_h: float
	if count == 0:
		content_h = 22.0  # высота заглушки
	else:
		content_h = float(count) * 32.0 + maxf(float(count) - 1.0, 0.0) * 5.0

	var new_bottom: float = offset_top + 20.0 + 36.0 + content_h  # PAD*2 + header + content

	var tw: Tween = create_tween()
	tw.tween_property(self, "offset_bottom", new_bottom, 0.3) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

# ─── Утилита ──────────────────────────────────────────────────────────────────

func _find_by_name(from: Node, target: String) -> Node:
	if from.name == target:
		return from
	for child: Node in from.get_children():
		var found: Node = _find_by_name(child, target)
		if found != null:
			return found
	return null
