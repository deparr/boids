extends Node

func _ready() -> void:
	if OS.has_feature("web"):
		get_tree().change_scene_to_file.call_deferred("res://Scenes/web_main.tscn") 
	else:
		get_tree().change_scene_to_file.call_deferred("res://Scenes/main.tscn") 
