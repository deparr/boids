extends Label


func _process(_delta: float) -> void:
	text = "%.0ffps" % Engine.get_frames_per_second()
