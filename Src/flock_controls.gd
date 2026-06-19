class_name FlockControls
extends Control

signal color_set_change(new_colors: PackedColorArray)

@export var color_sets: Array[PackedColorArray] = [
	PackedColorArray([Color(0.4, 0.69, 1),Color(0.28, 0.51, 0.9),Color(0.1, 0.62, 0.84),Color(0.31, 0.45, 0.98)]),
	PackedColorArray([Color(0.67, 0.28, 0.98),Color(0.78, 0.52, 0.98),Color(0.91, 0.42, 0.98),Color(0.98, 0.36, 0.91)]),
	PackedColorArray([Color(1, 0.53, 0.41),Color(0.96, 0.35, 0.22),Color(0.86, 0.44, 0),Color(0.94, 0.4, 0.1)]),
]

@onready var cohesion: HSlider = %CohesionSlider
@onready var separation: HSlider = %SeparationSlider
@onready var alignment: HSlider = %AlignmentSlider
@onready var flock_size: SpinBox = %FlockSizeSpinBox
@onready var color_options: OptionButton = %ColorOptions
@onready var fps_label: Label = %FPS


func _ready() -> void:
	color_options.item_selected.connect(_emit_selected_colors)


func _process(_delta: float) -> void:
	fps_label.text = "%0.f fps" % Engine.get_frames_per_second()


func get_selected_colors() -> PackedColorArray:
	return color_sets[color_options.selected]


func _emit_selected_colors(idx: int) -> void:
	color_set_change.emit(color_sets[idx])

