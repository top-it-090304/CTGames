extends Button

@export var console_name: String = "SlotTestConsole"
@export var console_script_path: String = "res://Materials/slot_test_console.gd"

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	var cb: Callable = Callable(self, "_on_pressed")
	if not pressed.is_connected(cb):
		pressed.connect(cb)

func _on_pressed() -> void:
	var ui_root: Node = get_parent()
	if ui_root == null:
		return

	var console: Panel = ui_root.get_node_or_null(console_name) as Panel
	if console == null:
		console = Panel.new()
		console.name = console_name
		ui_root.add_child(console)
		var script: Script = load(console_script_path)
		if script != null:
			console.set_script(script)
		if console.has_method("_ensure_ui"):
			console.call("_ensure_ui")
		console.visible = false

	if console.visible:
		console.visible = false
		return

	var parent_node: Node = console.get_parent()
	if parent_node != null:
		parent_node.move_child(console, parent_node.get_child_count() - 1)
	if console.has_method("set_slot_ui_target"):
		var scene_root: Node = get_tree().current_scene
		if scene_root != null:
			var slot_ui: Control = scene_root.get_node_or_null("SubViewport/SlotUI") as Control
			console.call("set_slot_ui_target", slot_ui)
	console.visible = true
