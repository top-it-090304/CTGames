extends Control

@export var symbols: Array[Texture2D] = []
@export var weights: Array[int] = []

@export var reels_row_path: NodePath
@export var button_path: NodePath
@export var label_path: NodePath

var reels_row: HBoxContainer
var btn: Button
var label: Label

var _reels: Array = []
var _busy: bool = false

func _ready() -> void:
 randomize()

 reels_row = get_node_or_null(reels_row_path) as HBoxContainer
 btn = get_node_or_null(button_path) as Button
 label = get_node_or_null(label_path) as Label

 if reels_row == null:
  push_error("reels_row is null: set reels_row_path in Inspector")
  return
 if btn == null:
  push_error("btn is null: set button_path in Inspector")
  return
 if label == null:
  push_error("label is null: set label_path in Inspector")
  return

 _reels.clear()
 var children: Array[Node] = reels_row.get_children()
 for c: Node in children:
  if c is Panel and c.has_method("start_spin") and c.has_method("stop_with_result"):
   _reels.append(c)

 btn.pressed.connect(_spin)
 label.text = "READY"

func _spin() -> void:
 if _busy:
  return
 if symbols.is_empty() or weights.size() != symbols.size():
  label.text = "error symbols/weights"
  return
 if _reels.is_empty():
  label.text = "no reels"
  return

 _busy = true
 btn.disabled = true
 label.text = "SPIN"

 for r in _reels:
  r.start_spin()

 var mid: Array[Texture2D] = []
 mid.resize(_reels.size())
 for i: int in range(_reels.size()):
  mid[i] = _pick()

 await get_tree().create_timer(0.9).timeout

 for i: int in range(_reels.size()):
  var top: Texture2D = _pick()
  var bot: Texture2D = _pick()
  _reels[i].stop_with_result(top, mid[i], bot)
  await get_tree().create_timer(0.2).timeout

 label.text = _result(mid)
 btn.disabled = false
 _busy = false

func _pick() -> Texture2D:
 var total: int = 0
 for w: int in weights:
  total += w
 if total <= 0:
  return symbols[0]

 var r: int = randi() % total
 var acc: int = 0
 for i: int in range(weights.size()):
  acc += weights[i]
  if r < acc:
   return symbols[i]
 return symbols[0]

func _result(mid: Array[Texture2D]) -> String:
 if mid.is_empty():
  return "DONE"
 var first: Texture2D = mid[0]
 var count: int = 1
 for i: int in range(1, mid.size()):
  if mid[i] == first:
   count += 1
  else:
   break
 if count >= 5:
  return "JACKPOT"
 if count == 4:
  return "WIN x4"
 if count == 3:
  return "WIN x3"
 return "LOSE"
