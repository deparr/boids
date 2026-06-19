extends Node

func _ready() -> void:
	if OS.has_feature("web"):
		get_tree().call_deferred(&"change_scene_to_file", "res://Scenes/web_main.tscn")
	else:
		get_tree().call_deferred(&"change_scene_to_file", "res://Scenes/main.tscn")
