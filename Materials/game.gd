@tool
extends Node3D

@onready var slot_ui: Control = $SubViewport/SlotUI

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.keycode == KEY_SPACE or key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER:
			_request_spin()

func _request_spin() -> void:
	if slot_ui != null and slot_ui.has_method("request_spin"):
		slot_ui.request_spin()
