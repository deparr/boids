extends Node
class_name BoidFlock2D

const boid_scn := preload("res://scenes/boid.tscn")

var world_dim: Vector2i:
	set(val):
		world_dim = val + Vector2i(5, 5)

var paused := false
@export var flock_size := 10:
	set(val):
		paused = true
		flock_size = val
		self.call_deferred("init_flock")
		self.call_deferred("reset_flock")
	get:
		return flock_size

var do_cohesion := true:
	set(val):
		do_cohesion = val
var do_separation := true:
	set(val):
		do_separation = val
var do_alignment := true:
	set(val):
		do_alignment = val

@export var cohesion_weight := 1.85:
	set(val):
		cohesion_weight = val
	get:
		return cohesion_weight
@export var separation_weight := 2.6:
	set(val):
		separation_weight = val
	get:
		return separation_weight
@export var alignment_weight := 1.65:
	set(val):
		alignment_weight = val
	get:
		return alignment_weight

@export var max_steer_force := 3.0

@export var max_speed := 5.0
@export var min_speed := 3.0

@export_range(60, 180) var view_angle := 135
@export var influence_radius := 120.0
@export var avoidance_radius := 45.0

@export var default_color := Color("#93a8b8")
@export var color_grad: Gradient


var flock: Array

func _ready() -> void:
	if color_grad == null:
		print("missing color gradient, defaulting to %s" % default_color)
	world_dim = get_viewport().size
	init_flock()
	reset_flock()
	print("cohesion: %.2f | separation: %.2f | alignment: %.2f" % [cohesion_weight, separation_weight, alignment_weight])

func _process(delta: float) -> void:
	if paused:
		return
	var neighbors = []
	neighbors.resize(flock_size)
	for i in flock_size:
		var boid = flock[i]
		var acceleration = Vector2.ZERO
		var pos: Vector2 = boid.position
		for j in flock_size:
			if i == j:
				continue
			var boid2 = flock[j]
			var distance = boid.position.distance_to(boid2.position)
			var angle = abs(rad_to_deg(boid.position.angle_to_point(boid2.position)))
			if distance <= influence_radius and angle <= view_angle:
				var adj_list = neighbors[i]
				if not adj_list:
					adj_list = []
					neighbors[i] = adj_list
				adj_list.append(j)

		if neighbors[i]:
			var group_center = Vector2.ZERO
			var group_heading = Vector2.ZERO
			var group_avoidance_heading = Vector2.ZERO
			for n in neighbors[i]:
				var boid2 = flock[n]
				group_center += boid2.position
				group_heading += boid2.direction
				var offset = boid2.position - boid.position
				var sqr_dist = offset.x * offset.x + offset.y * offset.y
				if sqr_dist < avoidance_radius * avoidance_radius:
					group_avoidance_heading -= offset / sqr_dist

			group_center /= len(neighbors[i])

			var offset_to_center = group_center - boid.position
			var cohesion_force: Vector2 = steer_towards(offset_to_center, boid.velocity) * self.cohesion_weight
			var separation_force: Vector2 = steer_towards(group_avoidance_heading, boid.velocity) * self.separation_weight
			var alignment_force: Vector2 = steer_towards(group_heading, boid.velocity) * self.alignment_weight

			if do_cohesion:
				acceleration += cohesion_force
			if do_separation:
				acceleration += separation_force
			if do_alignment:
				acceleration += alignment_force

		boid.velocity += acceleration * delta
		var dir = boid.velocity.normalized()
		var speed = boid.velocity.length()
		speed = clampf(speed, min_speed, max_speed)
		boid.velocity = dir * speed

		pos += boid.velocity

		if pos.x < -5:
			pos.x = world_dim.x
		elif pos.x > world_dim.x:
			pos.x = -5
		elif pos.y < -5:
			pos.y = world_dim.y
		elif pos.y > world_dim.y:
			pos.y = -5

		boid.position = pos
		boid.rotation = boid.velocity.angle()
		boid.direction = Vector2.from_angle(boid.rotation)

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
		if color_grad:
			var color = color_grad.sample(randf())
			boid.color = color
		else:
			boid.color = default_color

	paused = false

func reset_flock() -> void:
	for boid in flock:
		boid.position = Vector2(
			randf_range(0, world_dim.x),
			randf_range(0, world_dim.y),
		)
		boid.rotation = randf_range(0, TAU)
		boid.direction = Vector2.from_angle(boid.rotation)
		boid.velocity = boid.direction * ((min_speed + max_speed) / 2)

func steer_towards(towards: Vector2, velocity: Vector2) -> Vector2:
	var v: Vector2 = towards.normalized() * max_speed - velocity
	return clamp_magnitude(v, self.max_steer_force)

func clamp_magnitude(v: Vector2, _max: float) -> Vector2:
	return v.normalized() * minf(v.length(), _max)

