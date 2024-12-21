class_name Boid
extends Polygon2D


var velocity: Vector2 = Vector2.ZERO:
	set(val):
		velocity = val
	get:
		return velocity

var direction: Vector2 = Vector2.ZERO:
	set(val):
		direction = val
	get:
		return direction
