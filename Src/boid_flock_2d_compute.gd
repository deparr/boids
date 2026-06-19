class_name BoidFlockCompute2D
extends Node2D


@export var boid_count := 10
@export var colors: PackedColorArray
@export var polygon_points:  PackedVector2Array

@export var influence_radius_2 := 14400.0
@export var avoidance_radius_2 := 2025.0

@export var cohesion_weight := 1.85
@export var separation_weight := 2.60
@export var alignment_weight := 1.65

@export var max_steer_force := 3.0
@export var speed_limit = Vector2(3.0, 5.0)

var boids: Array[Boid]
var world_dim: Vector2

var compute_boid := ComputeBoid.new()

var backing_buffer: PackedByteArray
var push_constant: PackedByteArray
var rdbuffer: RID
var uniform_set: RID

var rd: RenderingDevice
var shader: RID
var pipeline: RID


func _ready() -> void:
	set_process(false)

	rd = RenderingServer.create_local_rendering_device()
	print(rd)
	var shader_source = RDShaderSource.new()
	shader_source.language = RenderingDevice.SHADER_LANGUAGE_GLSL
	var src_string = FileAccess.get_file_as_string("res://Src/boid_flock.comp.glsl")
	shader_source.source_compute = src_string
	var spriv = rd.shader_compile_spirv_from_source(shader_source)

	shader = rd.shader_create_from_spirv(spriv)
	pipeline = rd.compute_pipeline_create(shader)

	push_constant = PackedByteArray()
	push_constant.resize(16)
	push_constant.encode_float(0, avoidance_radius_2)
	push_constant.encode_float(4, influence_radius_2)
	push_constant.encode_u32(8, boid_count)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_EXIT_TREE:
			cleanup()


func _process(delta: float) -> void:
	for i in boid_count:
		var offset := i * compute_boid_size
		var boid := boids[i]
		backing_buffer.encode_float(offset, boid.position.x)
		backing_buffer.encode_float(offset + 4, boid.position.y)
		backing_buffer.encode_float(offset + 8, boid.direction.x)
		backing_buffer.encode_float(offset + 12, boid.direction.y)
	
	rd.buffer_update(rdbuffer, 0, backing_buffer.size(), backing_buffer)

	var compute_list = rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_set_push_constant(compute_list, push_constant, push_constant.size())
	rd.compute_list_dispatch(compute_list, boid_count / 64, 1, 1)
	rd.compute_list_end()

	rd.submit()
	rd.sync()

	var result = rd.buffer_get_data(rdbuffer)

	for i in boid_count:
		var acceleration = Vector2.ZERO

		var boid := boids[i]
		var updated_boid := _read_compute_boid(result, i * compute_boid_size)
		if updated_boid.neighbors > 0:
			var center_avg: Vector2 = updated_boid.group_center / updated_boid.neighbors
			var offset_to_center = center_avg - boid.position
			acceleration += steer_towards(offset_to_center, boid.velocity) * cohesion_weight
			acceleration += steer_towards(updated_boid.separation_heading, boid.velocity) * separation_weight
			acceleration += steer_towards(updated_boid.group_heading, boid.velocity) * alignment_weight

		boid.velocity += acceleration * delta
		var dir = boid.velocity.normalized()
		var speed = boid.velocity.length()
		speed = clampf(speed, speed_limit.x, speed_limit.y)
		boid.velocity = dir * speed

		var new_pos = boid.position + boid.velocity
		if new_pos.x < -5.:
			new_pos.x = world_dim.x
		elif new_pos.x > world_dim.x + 5.:
			new_pos.x = 0.
		if new_pos.y < -5.:
			new_pos.y = world_dim.y
		elif new_pos.y > world_dim.y + 5.:
			new_pos.y = 0.

		boid.position = new_pos
		boid.direction = dir
		boid.rotation = boid.velocity.angle()

		RenderingServer.canvas_item_set_transform(boid.rid, Transform2D(boid.rotation, boid.position))



func steer_towards(towards: Vector2, velocity: Vector2) -> Vector2:
	var v: Vector2 =  towards.normalized() * speed_limit.y - velocity
	var clamped := v.normalized() * minf(v.length(), max_steer_force)
	return clamped


func setup():
	boids = []
	boids.resize(boid_count)
	backing_buffer = PackedByteArray()
	backing_buffer.resize(boid_count * compute_boid_size)

	for i in boid_count:
		var boid = Boid.new()
		boid.color = colors[i % colors.size()]
		boid.direction = Vector2.from_angle(randf_range(0., TAU))
		boid.position = Vector2(randf_range(0., world_dim.x), randf_range(0., world_dim.y))
		boid.velocity = boid.direction * randf_range(speed_limit.x, speed_limit.y)
		var rid = RenderingServer.canvas_item_create()
		RenderingServer.canvas_item_add_polygon(rid, polygon_points, PackedColorArray([boid.color]))
		RenderingServer.canvas_item_set_parent(rid, get_canvas_item())
		boid.rid = rid
		boids[i] = boid

	rdbuffer = rd.storage_buffer_create(backing_buffer.size(), backing_buffer)
	var uniform = RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniform.binding = 0
	uniform.add_id(rdbuffer)

	uniform_set = rd.uniform_set_create([uniform], shader, 0)


func cleanup():
	for boid in boids:
		RenderingServer.free_rid(boid.rid)
	rd.free_rid(uniform_set)
	rd.free_rid(rdbuffer)
	rd.free_rid(shader)
	rd.free()


func set_boid_colors(new_colors: PackedColorArray) -> void:
	colors = new_colors

	for i in boid_count:
		var boid := boids[i]
		boid.color = colors[i % colors.size()]
		RenderingServer.canvas_item_clear(boid.rid)
		RenderingServer.canvas_item_add_polygon(boid.rid, polygon_points, PackedColorArray([boid.color]))


func _read_compute_boid(buf: PackedByteArray, offset: int) -> ComputeBoid:
	compute_boid.position = Vector2(buf.decode_float(offset), buf.decode_float(offset + 4))
	compute_boid.direction = Vector2(buf.decode_float(offset + 8), buf.decode_float(offset + 12))
	compute_boid.group_heading = Vector2(buf.decode_float(offset + 16), buf.decode_float(offset + 20))
	compute_boid.group_center = Vector2(buf.decode_float(offset + 24), buf.decode_float(offset + 28))
	compute_boid.separation_heading = Vector2(buf.decode_float(offset + 32), buf.decode_float(offset + 36))
	compute_boid.neighbors = buf.decode_u32(40)
	return compute_boid


const compute_boid_size = 48
# not actually instantiated on gdscript side
class ComputeBoid extends Object:
	var position: Vector2       # 8
	var direction: Vector2      # 16
	var group_heading: Vector2  # 24
	var group_center: Vector2   # 32
	var separation_heading: Vector2 # 40
	var neighbors: int # 44
	var pad: int # 48


class Boid extends Object:
	var position: Vector2
	var direction: Vector2
	var velocity: Vector2
	var rotation: float
	var color: Color
	var rid: RID
