extends Node2D

@onready var reset_button: Button = $Ui/ResetButton
@onready var cohesion_slider: Slider = $Ui.get_node("%Cohesion")
@onready var separation_slider: Slider = $Ui.get_node("%Separation")
@onready var alignment_slider: Slider = $Ui.get_node("%Alignment")
@onready var do_cohesion: CheckButton = $Ui.get_node("%ToggleCohesion")
@onready var do_separation: CheckButton = $Ui.get_node("%ToggleSeparation")
@onready var do_alignment: CheckButton = $Ui.get_node("%ToggleAlignment")
@onready var size_spinner: SpinBox = $Ui.get_node("%FlockSize")
@onready var flock: BoidFlock2D = $BoidFlock
@onready var bg: Polygon2D = $Background

func _ready() -> void:
	reset_button.pressed.connect(flock.reset_flock)
	get_tree().get_root().size_changed.connect(_resize_bg)

	cohesion_slider.value_changed.connect(_update_cohesion)
	separation_slider.value_changed.connect(_update_separation)
	alignment_slider.value_changed.connect(_update_alignment)

	cohesion_slider.set_value_no_signal(flock.cohesion_weight)
	separation_slider.set_value_no_signal(flock.separation_weight)
	alignment_slider.set_value_no_signal(flock.alignment_weight)

	do_cohesion.toggled.connect(_update_do_cohesion)
	do_separation.toggled.connect(_update_do_separation)
	do_alignment.toggled.connect(_update_do_alignment)

	size_spinner.set_value_no_signal(flock.flock_size)
	size_spinner.value_changed.connect(_update_flock_size)
	_resize_bg()

func _update_cohesion(val: float) -> void:
	flock.cohesion_weight = val

func _update_separation(val: float) -> void:
	flock.separation_weight = val

func _update_alignment(val: float) -> void:
	flock.alignment_weight = val

func _update_do_cohesion(val: bool) -> void:
	flock.do_cohesion = val

func _update_do_separation(val: bool) -> void:
	flock.do_separation = val

func _update_do_alignment(val: bool) -> void:
	flock.do_alignment = val

func _update_flock_size(val: float) -> void:
	flock.flock_size = floori(val)

func _resize_bg() -> void:
	var dim = get_viewport().size
	bg.polygon = PackedVector2Array([
		Vector2.ZERO,
		Vector2(float(dim.x), 0.0),
		Vector2(float(dim.x), float(dim.y)),
		Vector2(0.0, float(dim.y)),
	])
	flock.world_dim = dim

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_released("ui_toggle"):
		$Ui.visible = !$Ui.visible
