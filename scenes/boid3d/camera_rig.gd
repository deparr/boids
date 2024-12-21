extends Node3D

@export var orbit_sensitivity: float = 0.3  # Sensitivity of orbiting
@export var zoom_sensitivity: float = 2.0   # Sensitivity of zoom
@export var min_distance: float = 1.0       # Minimum zoom distance
@export var max_distance: float = 50.0      # Maximum zoom distance
@onready var camera = $Camera3D

var pitch_yaw = Vector2()  # Stores rotation angles (pitch and yaw)
var distance: float = 10.0  # Distance of the camera from the target

func _ready():
    # Initialize the camera position
    _update_camera()

func _input(event):
    if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
        # Rotate based on mouse movement
        pitch_yaw.x -= event.relative.y * orbit_sensitivity  # Pitch (up/down)
        pitch_yaw.y -= event.relative.x * orbit_sensitivity  # Yaw (left/right)
        # pitch_yaw.x = clamp(pitch_yaw.x, -89, 89)  # Prevent flipping at the poles
        _update_camera()
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_UP:
        # Zoom in
        distance -= zoom_sensitivity
        distance = max(distance, min_distance)
        _update_camera()
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
        # Zoom out
        distance += zoom_sensitivity
        distance = min(distance, max_distance)
        _update_camera()

func _update_camera():
    # Calculate the new camera position
    var camera_position = Vector3(
        distance * cos(deg_to_rad(pitch_yaw.x)) * sin(deg_to_rad(pitch_yaw.y)),
        distance * sin(deg_to_rad(pitch_yaw.x)),
        distance * cos(deg_to_rad(pitch_yaw.x)) * cos(deg_to_rad(pitch_yaw.y))
    )
    camera.transform.origin = camera_position
    camera.look_at(Vector3.ZERO)  # Or the position of the orbit center

