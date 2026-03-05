@tool
extends Panel

signal stopped

const ICON_TINT: Color = Color(1.28, 1.24, 1.18, 1.0)
const GLOW_TINT: Color = Color(1.0, 0.08, 0.03, 0.52)

@export var max_speed: float = 1300.0
@export var accel_time: float = 0.28
@export var min_spin_time: float = 0.8
@export var stop_time: float = 0.82
@export var swap_duration: float = 0.08

@export var icon_size: Vector2 = Vector2(250.0, 170.0)
@export var icon_separation: int = 6

@onready var box: VBoxContainer = $MarginContainer/VBoxContainer
@onready var margin: MarginContainer = $MarginContainer

var _h: float = 0.0
var _step: float = 0.0
var _speed: float = 0.0
var _state: int = 0
var _t: float = 0.0
var _settle_tween: Tween = null

var _want_top: Texture2D = null
var _want_mid: Texture2D = null
var _want_bot: Texture2D = null
var _symbol_pool: Array[Texture2D] = []
var _symbol_weights: Array[float] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	clip_contents = true
	_style_icons()

	_h = _detect_height()
	if _h <= 0.0:
		_h = size.y / 3.0
		if _h <= 0.0:
			_h = 170.0
	_step = _h + float(icon_separation)
	if _step <= 0.0:
		_step = _h
	box.position.y = _snap(box.position.y)

func start_spin() -> void:
	_state = 1
	_t = 0.0
	_speed = 0.0
	_want_top = null
	_want_mid = null
	_want_bot = null
	_ensure_symbol_pool_from_children()
	for child: Node in box.get_children():
		_set_icon_texture(child as TextureRect, _pick_random_texture(), false)

func stop_with_result(top: Texture2D, mid: Texture2D, bot: Texture2D) -> void:
	_want_top = top
	_want_mid = mid
	_want_bot = bot
	if _t < min_spin_time:
		if _state < 2:
			_state = 2
	else:
		_brake()

func stop_spin() -> void:
	_want_top = null
	_want_mid = null
	_want_bot = null
	if _t < min_spin_time:
		if _state < 2:
			_state = 2
	else:
		_brake()

func _process(delta: float) -> void:
	if _state == 0:
		return

	_t += delta
	if _state == 1:
		var a: float = clampf(_t / maxf(accel_time, 0.01), 0.0, 1.0)
		_speed = lerp(0.0, max_speed, 1.0 - pow(1.0 - a, 2.0))
		if _t >= accel_time:
			_state = 2
	elif _state == 2:
		_speed = max_speed
		if _want_mid != null and _t >= min_spin_time:
			_brake()

	_move(delta)

func _brake() -> void:
	if _state == 3:
		return
	_state = 3
	var tw: Tween = create_tween()
	tw.tween_property(self, "_speed", 0.0, stop_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.finished.connect(_on_brake_finished)

func _move(delta: float) -> void:
	box.position.y -= _speed * delta
	while box.position.y <= -_step:
		box.position.y += _step

		var first_child: Node = box.get_child(0)
		box.remove_child(first_child)
		box.add_child(first_child)
		if _state != 3:
			var moved_icon: TextureRect = first_child as TextureRect
			if moved_icon != null and _is_icon_fully_outside_view(moved_icon):
				_set_icon_texture(moved_icon, _pick_random_texture(), false)
			else:
				_set_random_hidden_icon()

func _on_brake_finished() -> void:
	_speed = 0.0
	_state = 4
	_settle_to_slot()

func _settle_to_slot() -> void:
	if _step <= 0.0:
		_finalize_stop()
		return

	var target_y: float = 0.0
	if box.position.y < -0.5:
		target_y = -_step

	var dist: float = absf(target_y - box.position.y)
	if dist <= 0.5:
		_finalize_stop()
		return

	var denom: float = maxf(max_speed * 0.75, 1.0)
	var settle_time: float = clampf(dist / denom, 0.06, 0.18)
	_settle_tween = create_tween()
	_settle_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_settle_tween.tween_property(box, "position:y", target_y, settle_time)
	_settle_tween.finished.connect(_finalize_stop)

func _finalize_stop() -> void:
	if _settle_tween != null:
		_settle_tween = null

	while box.position.y <= -_step:
		box.position.y += _step
		var first_child: Node = box.get_child(0)
		box.remove_child(first_child)
		box.add_child(first_child)

	box.position.y = _snap(box.position.y)
	_state = 0
	if _want_mid != null:
		_set_three(_want_top, _want_mid, _want_bot)
	emit_signal("stopped")

func _set_three(t: Texture2D, m: Texture2D, b: Texture2D) -> void:
	if box.get_child_count() < 3:
		return
	_set_icon_texture(box.get_child(0) as TextureRect, t, false)
	_set_icon_texture(box.get_child(1) as TextureRect, m, false)
	_set_icon_texture(box.get_child(2) as TextureRect, b, false)

func _set_icon_texture(icon: TextureRect, texture: Texture2D, smooth: bool = true) -> void:
	if icon == null:
		return
	if texture == null:
		return

	var glow: TextureRect = icon.get_node_or_null("Glow") as TextureRect
	var next_icon: TextureRect = icon.get_node_or_null("Next") as TextureRect
	var next_glow: TextureRect = icon.get_node_or_null("NextGlow") as TextureRect
	var current_texture: Texture2D = icon.texture

	if (not smooth) or Engine.is_editor_hint() or current_texture == null or current_texture == texture or next_icon == null:
		icon.texture = texture
		icon.modulate = ICON_TINT
		if glow != null:
			glow.texture = texture
			glow.modulate = GLOW_TINT
		if next_icon != null:
			next_icon.texture = texture
			next_icon.modulate = Color(ICON_TINT.r, ICON_TINT.g, ICON_TINT.b, 0.0)
		if next_glow != null:
			next_glow.texture = texture
			next_glow.modulate = Color(GLOW_TINT.r, GLOW_TINT.g, GLOW_TINT.b, 0.0)
		_kill_swap_tween(icon)
		return

	_kill_swap_tween(icon)
	next_icon.texture = texture
	next_icon.modulate = Color(ICON_TINT.r, ICON_TINT.g, ICON_TINT.b, 0.0)
	if next_glow != null:
		next_glow.texture = texture
		next_glow.modulate = Color(GLOW_TINT.r, GLOW_TINT.g, GLOW_TINT.b, 0.0)

	icon.modulate = Color(ICON_TINT.r, ICON_TINT.g, ICON_TINT.b, 1.0)
	if glow != null:
		glow.modulate = Color(GLOW_TINT.r, GLOW_TINT.g, GLOW_TINT.b, GLOW_TINT.a)

	var tw: Tween = create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(icon, "modulate:a", 0.0, swap_duration)
	tw.parallel().tween_property(next_icon, "modulate:a", 1.0, swap_duration)
	if glow != null:
		tw.parallel().tween_property(glow, "modulate:a", 0.0, swap_duration)
	if next_glow != null:
		tw.parallel().tween_property(next_glow, "modulate:a", GLOW_TINT.a, swap_duration)

	icon.set_meta("swap_tween", tw)
	tw.finished.connect(_on_swap_finished.bind(icon, texture))

func _kill_swap_tween(icon: TextureRect) -> void:
	if icon == null:
		return
	if icon.has_meta("swap_tween"):
		var old_tw: Tween = icon.get_meta("swap_tween") as Tween
		if old_tw != null:
			old_tw.kill()
		icon.remove_meta("swap_tween")

func _on_swap_finished(icon: TextureRect, texture: Texture2D) -> void:
	if icon == null or texture == null:
		return
	icon.texture = texture
	icon.modulate = ICON_TINT

	var glow: TextureRect = icon.get_node_or_null("Glow") as TextureRect
	if glow != null:
		glow.texture = texture
		glow.modulate = GLOW_TINT

	var next_icon: TextureRect = icon.get_node_or_null("Next") as TextureRect
	if next_icon != null:
		next_icon.texture = texture
		next_icon.modulate = Color(ICON_TINT.r, ICON_TINT.g, ICON_TINT.b, 0.0)

	var next_glow: TextureRect = icon.get_node_or_null("NextGlow") as TextureRect
	if next_glow != null:
		next_glow.texture = texture
		next_glow.modulate = Color(GLOW_TINT.r, GLOW_TINT.g, GLOW_TINT.b, 0.0)

	_kill_swap_tween(icon)

func set_symbol_pool(pool: Array[Texture2D], weights: Array[float]) -> void:
	_symbol_pool = pool.duplicate()
	_symbol_weights = weights.duplicate()

func _ensure_symbol_pool_from_children() -> void:
	if not _symbol_pool.is_empty():
		return
	for child: Node in box.get_children():
		var icon: TextureRect = child as TextureRect
		if icon != null and icon.texture != null:
			_symbol_pool.append(icon.texture)
	if _symbol_pool.is_empty() and _want_mid != null:
		_symbol_pool.append(_want_mid)
	if _symbol_weights.size() != _symbol_pool.size():
		_symbol_weights.resize(_symbol_pool.size())
		for i: int in range(_symbol_weights.size()):
			if _symbol_weights[i] <= 0.0:
				_symbol_weights[i] = 1.0

func _pick_random_texture() -> Texture2D:
	if _symbol_pool.is_empty():
		return null
	var idx: int = _pick_weighted_index()
	return _symbol_pool[idx]

func _pick_weighted_index() -> int:
	if _symbol_pool.is_empty():
		return 0
	if _symbol_weights.size() != _symbol_pool.size():
		_symbol_weights.resize(_symbol_pool.size())
		for i: int in range(_symbol_weights.size()):
			if _symbol_weights[i] <= 0.0:
				_symbol_weights[i] = 1.0

	var total: float = 0.0
	for w: float in _symbol_weights:
		total += maxf(w, 0.0)
	if total <= 0.0:
		return _rng.randi_range(0, _symbol_pool.size() - 1)

	var roll: float = _rng.randf_range(0.0, total)
	var acc: float = 0.0
	for i: int in range(_symbol_weights.size()):
		acc += maxf(_symbol_weights[i], 0.0)
		if roll < acc:
			return i
	return 0

func _detect_height() -> float:
	if box.get_child_count() == 0:
		return 0.0
	var tr: Control = box.get_child(0) as Control
	if tr == null:
		return 0.0
	if tr.size.y > 0.0:
		return tr.size.y
	return tr.custom_minimum_size.y

func _snap(y: float) -> float:
	if _step <= 0.0:
		return y
	return round(y / _step) * _step

func _set_random_hidden_icon() -> void:
	for i: int in range(box.get_child_count() - 1, -1, -1):
		var icon: TextureRect = box.get_child(i) as TextureRect
		if icon != null and _is_icon_fully_outside_view(icon):
			_set_icon_texture(icon, _pick_random_texture(), false)
			return

func _is_icon_fully_outside_view(icon: TextureRect) -> bool:
	var top_y: float = margin.offset_top + box.position.y + icon.position.y
	var bottom_y: float = top_y + icon_size.y
	return bottom_y < 0.0 or top_y > size.y

func get_middle_texture() -> Texture2D:
	var target_y: float = size.y * 0.5
	var best_dist: float = INF
	var best_icon: TextureRect = null

	for child: Node in box.get_children():
		var icon: TextureRect = child as TextureRect
		if icon == null:
			continue
		var top_y: float = margin.offset_top + box.position.y + icon.position.y
		var center_y: float = top_y + icon_size.y * 0.5
		var dist: float = absf(center_y - target_y)
		if dist < best_dist:
			best_dist = dist
			best_icon = icon

	if best_icon == null:
		return null
	return best_icon.texture

func _style_icons() -> void:
	box.add_theme_constant_override("separation", icon_separation)

	var item_count: int = box.get_child_count()
	var total_height: float = icon_size.y * float(item_count) + float(icon_separation) * float(maxi(item_count - 1, 0))
	margin.offset_left = 25
	margin.offset_top = 16
	margin.offset_right = 25 + icon_size.x
	margin.offset_bottom = 16 + total_height
	margin.scale = Vector2.ONE

	for child: Node in box.get_children():
		var icon: TextureRect = child as TextureRect
		if icon == null:
			continue
		icon.custom_minimum_size = icon_size
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		icon.modulate = ICON_TINT
		_ensure_icon_layers(icon)

func _ensure_icon_layers(icon: TextureRect) -> void:
	var glow: TextureRect = icon.get_node_or_null("Glow") as TextureRect
	if glow == null:
		glow = TextureRect.new()
		glow.name = "Glow"
		icon.add_child(glow)
		icon.move_child(glow, 0)

	var next_glow: TextureRect = icon.get_node_or_null("NextGlow") as TextureRect
	if next_glow == null:
		next_glow = TextureRect.new()
		next_glow.name = "NextGlow"
		icon.add_child(next_glow)
		icon.move_child(next_glow, 1)

	var next_icon: TextureRect = icon.get_node_or_null("Next") as TextureRect
	if next_icon == null:
		next_icon = TextureRect.new()
		next_icon.name = "Next"
		icon.add_child(next_icon)

	next_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	next_icon.texture = icon.texture
	next_icon.expand_mode = icon.expand_mode
	next_icon.stretch_mode = icon.stretch_mode
	next_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	next_icon.modulate = Color(ICON_TINT.r, ICON_TINT.g, ICON_TINT.b, 0.0)
	next_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	next_icon.z_index = 2

	next_glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	next_glow.offset_left = -20.0
	next_glow.offset_top = -16.0
	next_glow.offset_right = 20.0
	next_glow.offset_bottom = 16.0
	next_glow.texture = icon.texture
	next_glow.expand_mode = icon.expand_mode
	next_glow.stretch_mode = icon.stretch_mode
	next_glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	next_glow.modulate = Color(GLOW_TINT.r, GLOW_TINT.g, GLOW_TINT.b, 0.0)
	next_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	next_glow.z_index = -1

	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.offset_left = -20.0
	glow.offset_top = -16.0
	glow.offset_right = 20.0
	glow.offset_bottom = 16.0
	glow.texture = icon.texture
	glow.expand_mode = icon.expand_mode
	glow.stretch_mode = icon.stretch_mode
	glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	glow.modulate = GLOW_TINT
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.z_index = -2
