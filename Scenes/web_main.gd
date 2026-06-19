extends CanvasLayer

@onready var flock: BoidFlock2D = $BoidFlock2D
@onready var menu: FlockControls = $FlockControls


func _ready() -> void:
	menu.cohesion.tooltip_text = "Tendency of boids to steer towards the center of neighboring boids"
	menu.separation.tooltip_text = "Tendency of boids to steer away from neighboring boids"
	menu.alignment.tooltip_text = "Tendency of boids to align themselves the heading of neighboring boids"

	menu.cohesion.set_value_no_signal(flock.cohesion_weight)
	menu.separation.set_value_no_signal(flock.separation_weight)
	menu.alignment.set_value_no_signal(flock.alignment_weight)

	menu.cohesion.value_changed.connect(_update_flock_parameter.bind(0))
	menu.separation.value_changed.connect(_update_flock_parameter.bind(1))
	menu.alignment.value_changed.connect(_update_flock_parameter.bind(2))

	menu.flock_size.set_value_no_signal(flock.boid_count)
	menu.flock_size.value_changed.connect(_update_flock_parameter.bind(3))

	$GitLink/Version.tooltip_text = "@GIT_REV@"

	menu.color_set_change.connect(_on_color_selected)

	get_viewport().size_changed.connect(_on_window_resize)
	_on_window_resize()

	flock.colors = menu.get_selected_colors()
	flock.setup()
	flock.set_process(true)


func _on_color_selected(new_colors: PackedColorArray) -> void:
	flock.set_boid_colors(new_colors)


func _update_flock_parameter(value: float, which: int) -> void:
	match which:
		0:
			flock.cohesion_weight = value
		1:
			flock.separation_weight = value
		2:
			flock.alignment_weight = value
		3:
			flock.resize_flock(int(value))


func _on_window_resize() -> void:
	var size := get_viewport().get_visible_rect().size
	flock.world_dim = size
