extends Node2D
class_name DebugDraw

var color: Color
var radius: float
var old_pos := Vector2.ZERO

func _init(_color: Color, _radius: float) -> void:
	color = _color
	radius = _radius
	self.show_behind_parent = true

func _draw():
	draw_circle(self.position, self.radius, self.color)
	draw_line(old_pos, self.position, Color.RED)

