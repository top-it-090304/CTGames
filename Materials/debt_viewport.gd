extends SubViewport

func _ready() -> void:
	render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
