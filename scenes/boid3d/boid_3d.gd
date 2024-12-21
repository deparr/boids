extends MeshInstance3D
class_name Boid3D

var velocity: Vector3 = Vector3.ZERO:
	set(val):
		velocity = val
	get:
		return velocity

var direction: Vector3 = Vector3.ZERO:
	set(val):
		direction = val
	get:
		return direction
