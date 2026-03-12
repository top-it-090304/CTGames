extends Panel

signal buy_requested
signal close_requested

@onready var title_label: Label = get_node_or_null("TitleLabel") as Label
@onready var price_label: Label = get_node_or_null("PriceLabel") as Label
@onready var desc_label: RichTextLabel = get_node_or_null("DescLabel") as RichTextLabel
@onready var buy_button: Button = get_node_or_null("BuyButton") as Button
@onready var close_button: Button = get_node_or_null("CloseButton") as Button

var _current_offer: Dictionary = {}

func _ready() -> void:
	visible = false
	if buy_button != null and not buy_button.pressed.is_connected(_on_buy_pressed):
		buy_button.pressed.connect(_on_buy_pressed)
	if close_button != null and not close_button.pressed.is_connected(_on_close_pressed):
		close_button.pressed.connect(_on_close_pressed)

func show_offer(offer: Dictionary, current_tokens: int) -> void:
	_current_offer = offer.duplicate(true)
	if title_label != null:
		title_label.text = String(offer.get("title", "Тотем"))
	if desc_label != null:
		desc_label.text = String(offer.get("description", ""))
	if price_label != null:
		price_label.text = "Цена: %d TOK" % int(offer.get("price", 0))
	_refresh_buy_state(current_tokens)
	visible = true

func hide_panel() -> void:
	visible = false
	_current_offer.clear()

func is_open() -> bool:
	return visible

func refresh_tokens(current_tokens: int) -> void:
	if _current_offer.is_empty():
		return
	_refresh_buy_state(current_tokens)

func _refresh_buy_state(current_tokens: int) -> void:
	if buy_button == null:
		return
	var price: int = int(_current_offer.get("price", 0))
	var can_buy: bool = current_tokens >= price
	buy_button.disabled = not can_buy
	buy_button.text = "Купить" if can_buy else "Не хватает TOK"

func _on_buy_pressed() -> void:
	emit_signal("buy_requested")

func _on_close_pressed() -> void:
	hide_panel()
	emit_signal("close_requested")
