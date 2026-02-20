extends Panel

@export var max_speed: float = 1800.0
@export var accel_time: float = 0.18
@export var min_spin_time: float = 0.8
@export var stop_time: float = 0.55

@onready var box: VBoxContainer = $MarginContainer/VBoxContainer

var _h: float = 0.0
var _speed: float = 0.0
var _state: int = 0
var _t: float = 0.0

var _want_top: Texture2D = null
var _want_mid: Texture2D = null
var _want_bot: Texture2D = null
var _prepared: bool = false

func _ready() -> void:
 clip_contents = true
 _h = _detect_height()
 if _h <= 0.0:
  _h = size.y / 3.0
  if _h <= 0.0:
   _h = 160.0
 box.position.y = _snap(box.position.y)

func start_spin() -> void:
 _state = 1
 _t = 0.0
 _speed = 0.0
 _prepared = false
 _want_top = null
 _want_mid = null
 _want_bot = null

func stop_with_result(top: Texture2D, mid: Texture2D, bot: Texture2D) -> void:
 _want_top = top
 _want_mid = mid
 _want_bot = bot
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
  var a: float = clamp(_t / max(accel_time, 0.01), 0.0, 1.0)
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
 _prepared = false
 var tw: Tween = create_tween()
 tw.tween_property(self, "_speed", 0.0, stop_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
 tw.finished.connect(_finish)

func _move(delta: float) -> void:
 box.position.y -= _speed * delta
 while box.position.y <= -_h:
  box.position.y += _h
  var n: Node = box.get_child(0)
  box.remove_child(n)
  box.add_child(n)
 if _state == 3 and not _prepared and _speed < max_speed * 0.45 and _want_mid != null:
  _prepared = true
  _set_three(_want_top, _want_mid, _want_bot)

func _finish() -> void:
 _speed = 0.0
 _state = 0
 box.position.y = _snap(box.position.y)
 if _want_mid != null:
  _set_three(_want_top, _want_mid, _want_bot)

func _set_three(t: Texture2D, m: Texture2D, b: Texture2D) -> void:
 if box.get_child_count() < 3:
  return
 var a: TextureRect = box.get_child(0) as TextureRect
 var c: TextureRect = box.get_child(1) as TextureRect
 var d: TextureRect = box.get_child(2) as TextureRect
 if a: a.texture = t
 if c: c.texture = m
 if d: d.texture = b

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
 if _h <= 0.0:
  return y
 return round(y / _h) * _h
