extends Node2D

@export var flock: BoidFlock2D

@onready var fps_label: Label = %FPS
@onready var cohesion_slider: HSlider = %CohesionSlider
@onready var separation_slider: HSlider = %SeparationSlider
@onready var alignment_slider: HSlider = %AlignmentSlider
@onready var flock_size: SpinBox = %FlockSizeSpinBox


func _ready() -> void:
	cohesion_slider.set_value_no_signal(flock.cohesion_weight)
	cohesion_slider.value_changed.connect(func(value: float): flock.cohesion_weight = value)

	separation_slider.set_value_no_signal(flock.separation_weight)
	separation_slider.value_changed.connect(func(value: float): flock.separation_weight = value)

	alignment_slider.set_value_no_signal(flock.alignment_weight)
	alignment_slider.value_changed.connect(func(value: float): flock.alignment_weight = value)

	flock_size.set_value_no_signal(flock.boid_count)
	flock_size.value_changed.connect(func(value: float): flock.resize_flock(int(value)))
	flock_size.editable = true

	get_viewport().size_changed.connect(handle_window_resize)
	handle_window_resize()
	flock.setup()
	flock.set_process(true)


func _process(_delta: float) -> void:
	fps_label.text = "%.0f fps" % Engine.get_frames_per_second()


func handle_window_resize() -> void:
	var size = get_viewport().get_visible_rect().size
	flock.world_dim = size
