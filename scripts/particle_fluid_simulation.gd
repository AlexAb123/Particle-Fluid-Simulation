extends Node2D

@export var particle_count: int = 2
var positions: PackedFloat32Array = PackedFloat32Array()
var velocities: PackedFloat32Array = PackedFloat32Array()
var densities: PackedFloat32Array = PackedFloat32Array()
var pressures: PackedFloat32Array = PackedFloat32Array()
var forces: PackedFloat32Array = PackedFloat32Array()

@onready var fps_counter: Label = $FPSCounter

@onready var multi_mesh_instance_2d: MultiMeshInstance2D = $MultiMeshInstance2D
# Maps spatial bucket coordinates (Vector2i) to an Array of particle indices.
var spatial_buckets: Dictionary[Vector2i, PackedInt32Array] = {}
func _ready():

	for i in range(particle_count):
		positions.append(i)
		positions.append(i)
		velocities.append(i)
		velocities.append(2)

	_multi_mesh_setup()
	_compute_shader_setup()

var rd: RenderingDevice
var uniform_set: RID
var pipeline: RID
# Buffers
var positions_buffer: RID
var velocities_buffer: RID
func _compute_shader_setup() -> void:
	# Create a local rendering device.
	rd = RenderingServer.create_local_rendering_device()
	# Load GLSL shader
	var shader_file := load("res://shaders/compute_shader.glsl")
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	var shader := rd.shader_create_from_spirv(shader_spirv)

	# Create Buffers
	var positions_bytes := positions.to_byte_array()
	positions_buffer = rd.storage_buffer_create(positions_bytes.size(), positions_bytes)

	var velocities_bytes := velocities.to_byte_array()
	velocities_buffer = rd.storage_buffer_create(velocities_bytes.size(), velocities_bytes)

	# Create Uniforms
	var positions_uniform := RDUniform.new()
	positions_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	positions_uniform.binding = 0
	positions_uniform.add_id(positions_buffer)
	var velocities_uniform := RDUniform.new()
	velocities_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	velocities_uniform.binding = 1
	velocities_uniform.add_id(velocities_buffer)

	uniform_set = rd.uniform_set_create(
		[positions_uniform, velocities_uniform],
		shader, 
		0) # the last parameter (the 0) needs to match the "set" in our shader file

	# Create a compute pipeline
	pipeline = rd.compute_pipeline_create(shader)
func _gpu_step() -> void:
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_dispatch(compute_list, particle_count * 2, 1, 1)
	rd.compute_list_end()

	# Submit to GPU and wait for sync
	rd.submit()
	rd.sync()

	_render_particles()

func _render_particles() -> void:
	var positions_bytes := rd.buffer_get_data(positions_buffer)
	var positions_floats = positions_bytes.to_float32_array()
	for i in range(particle_count):
		var x = positions_floats[i * 2]
		var y = positions_floats[i * 2 + 1]
		var transform = Transform2D()
		transform.origin = Vector2(x, y)
		multi_mesh_instance_2d.multimesh.set_instance_transform_2d(i, transform)
func _multi_mesh_setup() -> void:
	multi_mesh_instance_2d.multimesh.instance_count = particle_count
func _process(delta: float) -> void:
	fps_counter.text = str(int(Engine.get_frames_per_second())) + " fps"
	_gpu_step()
