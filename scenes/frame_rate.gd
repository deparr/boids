extends Label


func _process(_delta: float) -> void:
	text = "%.0f" % Engine.get_frames_per_second()
