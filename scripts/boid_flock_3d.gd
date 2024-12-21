extends Node
class_name BoidFlock3D

const boid_scn := preload("res://scenes/boid3d/boid_3d.tscn")

var world_dim: Vector3:
	set(val):
		world_dim = val

@export var flock_size := 90

@export var cohesion_weight := 1.7:
	set(val):
		cohesion_weight = val
	get:
		return cohesion_weight
@export var separation_weight := 2.6:
	set(val):
		separation_weight = val
	get:
		return separation_weight
@export var alignment_weight := 1.4:
	set(val):
		alignment_weight = val
	get:
		return alignment_weight

@export var max_steer_force := 3.0

@export var influence_radius := 10.0
@export var avoidance_radius := 3.0

@export var max_speed := 0.25
@export var min_speed := 0.11
@export_range(60, 180) var view_angle := 135

@export var color_grad: Gradient

var flock: Array

func _ready() -> void:
	world_dim = Vector3(50, 50, 50)
	init_flock()
	reset_flock()

func _process(delta: float) -> void:
	var neighbors = []
	neighbors.resize(flock_size)
	for i in flock_size:
		var boid = flock[i]
		var acceleration := Vector3.ZERO
		var pos: Vector3 = boid.position
		for j in flock_size:
			if i == j:
				continue
			var boid2 = flock[j]
			var distance = boid.position.distance_to(boid2.position)
			# TODO view angle
			if distance < influence_radius:
				var nearby = neighbors[i]
				if not nearby:
					nearby = []
					neighbors[i] = nearby
				nearby.append(j)

		if neighbors[i]:
			var group_center = Vector3.ZERO
			var group_heading = Vector3.ZERO
			var group_avoidance_heading = Vector3.ZERO
			for n in neighbors[i]:
				var boid2 = flock[n]
				group_center += boid2.position
				group_heading += boid2.direction
				var offset = boid2.position - boid.position
				var sqr_dist = offset.x * offset.x + offset.y * offset.y + offset.z * offset.z
				if sqr_dist < avoidance_radius * avoidance_radius:
					group_avoidance_heading -= offset / sqr_dist

			group_center /= len(neighbors[i])

			var offset_to_center = group_center - boid.position
			var cohesion_force: Vector3 = steer_towards(offset_to_center, boid.velocity) * self.cohesion_weight
			var separation_force: Vector3 = steer_towards(group_avoidance_heading, boid.velocity) * self.separation_weight
			var alignment_force: Vector3 = steer_towards(group_heading, boid.velocity) * self.alignment_weight

			acceleration += cohesion_force
			acceleration += separation_force
			acceleration += alignment_force

		boid.velocity += acceleration * delta
		var dir: Vector3 = boid.velocity.normalized()
		var speed = boid.velocity.length()
		speed = clampf(speed, min_speed, max_speed)
		boid.velocity = dir * speed
		# boid.transform.basis = Basis(dir)

		pos += boid.velocity

		if pos.x < 0:
			pos.x = world_dim.x
		elif pos.x > world_dim.x:
			pos.x = 0
		elif pos.y < 0:
			pos.y = world_dim.y
		elif pos.y > world_dim.y:
			pos.y = 0
		elif pos.z < 0:
			pos.z = world_dim.z
		elif pos.z > world_dim.z:
			pos.z = 0

		boid.position = pos
		# boid.transform = boid.transform.looking_at(boid.velocity)
		# var t: Transform3D = boid.transform

func init_flock() -> void:
	if flock:
		for boid in flock:
			if boid and not boid.is_queued_for_deletion():
				boid.queue_free()
	flock = []
	flock.resize(flock_size)
	for i in range(flock_size):
		var boid = boid_scn.instantiate()
		self.add_child(boid)
		flock[i] = boid

	# paused = false

func reset_flock() -> void:
	if flock_size != len(flock):
		var new_flock = []
		new_flock.resize(flock_size)
		for i in len(flock):
			if i >= len(new_flock):
				break
			new_flock[i] = flock[i]
	for boid in flock:
		boid.position = Vector3(
			randf_range(0, world_dim.x),
			randf_range(0, world_dim.y),
			randf_range(0, world_dim.z),
		)
		boid.velocity = boid.position.normalized() * ((min_speed + max_speed) / 2)


func steer_towards(towards: Vector3, velocity: Vector3) -> Vector3:
	var v := towards.normalized() * max_speed - velocity
	return clamp_magnitude(v, self.max_steer_force)

func clamp_magnitude(v: Vector3, _max: float) -> Vector3:
	return v.normalized() * max(v.length(), _max)

