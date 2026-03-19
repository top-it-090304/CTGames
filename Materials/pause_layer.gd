extends CanvasLayer

var pause_panel: Panel
var is_paused: bool = false

func _ready() -> void:
	pause_panel = get_node_or_null("PausePanel") as Panel
	if pause_panel == null:
		return
	pause_panel.visible = false

	var resume_btn := pause_panel.get_node_or_null("ResumeButton") as Button
	var quit_btn   := pause_panel.get_node_or_null("QuitButton") as Button
	if resume_btn != null:
		resume_btn.pressed.connect(_on_resume_pressed)
	if quit_btn != null:
		quit_btn.pressed.connect(_on_quit_pressed)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_ESCAPE:
			_toggle_pause()
			get_viewport().set_input_as_handled()

func _toggle_pause() -> void:
	is_paused = !is_paused
	get_tree().paused = is_paused
	if pause_panel != null:
		pause_panel.visible = is_paused

func _on_resume_pressed() -> void:
	is_paused = false
	get_tree().paused = false
	if pause_panel != null:
		pause_panel.visible = false

func _on_quit_pressed() -> void:
	get_tree().paused = false
	get_tree().quit()
