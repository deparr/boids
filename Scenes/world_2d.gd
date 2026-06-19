extends Node2D

@export var flock: BoidFlock2D

@onready var menu: FlockControls = $World/FlockControls


func _ready() -> void:
	menu.cohesion.set_value_no_signal(flock.cohesion_weight)
	menu.cohesion.value_changed.connect(func(value: float): flock.cohesion_weight = value)

	menu.separation.set_value_no_signal(flock.separation_weight)
	menu.separation.value_changed.connect(func(value: float): flock.separation_weight = value)

	menu.alignment.set_value_no_signal(flock.alignment_weight)
	menu.alignment.value_changed.connect(func(value: float): flock.alignment_weight = value)

	menu.flock_size.set_value_no_signal(flock.boid_count)
	menu.flock_size.value_changed.connect(func(value: float): flock.resize_flock(int(value)))
	menu.flock_size.editable = true

	get_viewport().size_changed.connect(handle_window_resize)
	handle_window_resize()

	menu.color_set_change.connect(_on_color_selected)
	flock.colors = menu.get_selected_colors()
	flock.setup()
	flock.set_process(true)


func _on_color_selected(new_colors: PackedColorArray) -> void:
	flock.set_boid_colors(new_colors)


func handle_window_resize() -> void:
	var size = get_viewport().get_visible_rect().size
	flock.world_dim = size
