class_name BoidFlock2D
extends Node2D

@export var boid_count := 10;
@export var colors: Array[Color] = [ Color.from_rgba8(0xff, 0xe3, 0x04) ]
@export var polygon_points:  PackedVector2Array

@export var influence_radius := 120.0
@export var view_angle := 135.0
@export var avoidance_radius_2 := 2025.0

@export var cohesion_weight := 1.85
@export var separation_weight := 2.60
@export var alignment_weight := 1.65

@export var max_steer_force := 3.0
@export var speed_limit = Vector2(3.0, 5.0)

var boids: Array[Boid]
var world_dim: Vector2


func _ready() -> void:
	if polygon_points.size() < 3:
		push_error("boidflockgd: polygon_points has < 3 points")
		return
	set_process(false)


func _process(delta: float) -> void:
	for i in boids.size():
		var boid := boids[i]
		var updated_transform = step_boid(boid, i, delta)
		RenderingServer.canvas_item_set_transform(boid.rid, updated_transform)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_EXIT_TREE:
			cleanup()


func step_boid(boid: Boid, index: int, delta: float) -> Transform2D:
	var acceleration := Vector2.ZERO
	var pos := boid.position

	var group_center := Vector2.ZERO
	var group_heading := Vector2.ZERO
	var group_avoidance_heading := Vector2.ZERO
	var neighbor_count := 0
	for j in boids.size():
		if j == index:
			continue

		var boid2 := boids[j]
		var distance := boid.position.distance_to(boid2.position)
		var angle = abs(rad_to_deg(boid.position.angle_to_point(boid2.position)))
		if distance > influence_radius or angle > view_angle:
			continue
		neighbor_count += 1
		group_center += boid2.position
		group_heading += boid2.direction
		var offset = boid2.position - boid.position
		var sqr_dist = offset.x * offset.x + offset.y * offset.y
		if sqr_dist < avoidance_radius_2:
			group_avoidance_heading -= offset / sqr_dist
	
	if neighbor_count > 0:
		group_center /= neighbor_count

		var offset_to_center = group_center - boid.position
		var cohesion_force = steer_towards(offset_to_center, boid.velocity) * cohesion_weight
		var separation_force = steer_towards(group_avoidance_heading, boid.velocity) * separation_weight
		var alignment_force = steer_towards(group_heading, boid.velocity) * alignment_weight

		acceleration += cohesion_force
		acceleration += separation_force
		acceleration += alignment_force

	boid.velocity += acceleration * delta
	var dir = boid.velocity.normalized()
	var speed = boid.velocity.length()
	speed = clampf(speed, speed_limit.x, speed_limit.y)
	boid.velocity = dir * speed

	pos += boid.velocity

	if pos.x < -5.0:
		pos.x = world_dim.x
	elif pos.x > world_dim.x + 5:
		pos.x = 0
	elif pos.y < -5.0:
		pos.y = world_dim.y
	elif pos.y > world_dim.y + 5:
		pos.y = 0
	
	boid.position = pos
	boid.direction = dir
	boid.rotation = boid.velocity.angle()

	return Transform2D(boid.rotation, boid.position)


func steer_towards(towards: Vector2, velocity: Vector2) -> Vector2:
	var v: Vector2 = towards.normalized() * speed_limit.y - velocity
	var clamped = v.normalized() * minf(v.length(), max_steer_force)
	return clamped


func resize_flock(new_count: int) -> void:
	set_process(false)
	cleanup()
	boid_count = new_count
	setup()
	set_process(true)


func setup() -> void:
	boids = []
	boids.resize(boid_count)

	for i in boid_count:
		var boid := Boid.new()
		boid.color = colors.pick_random()
		boid.direction = Vector2.from_angle(randf_range(0.0, TAU))
		boid.position = world_dim * Vector2(randf(), randf())
		boid.velocity = boid.direction * randf_range(speed_limit.x, speed_limit.y)
		var rid = RenderingServer.canvas_item_create()
		RenderingServer.canvas_item_add_polygon(rid, polygon_points, [boid.color])
		RenderingServer.canvas_item_set_parent(rid, self.get_canvas_item())
		boid.rid = rid
		boids[i] = boid


func cleanup() -> void:
	for boid in boids:
		RenderingServer.free_rid(boid.rid)
		boid.free()


class Boid extends Object:
	var position: Vector2
	var direction: Vector2
	var velocity: Vector2
	var rotation: float
	var color: Color
	var rid: RID
