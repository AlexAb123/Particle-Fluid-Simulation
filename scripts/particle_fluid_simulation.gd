extends Node2D

@export var particle_count: int = 1000
var positions: PackedFloat32Array = PackedFloat32Array()
var velocities: PackedFloat32Array = PackedFloat32Array()
var densities: PackedFloat32Array = PackedFloat32Array()
var pressures: PackedFloat32Array = PackedFloat32Array()
var forces: PackedFloat32Array = PackedFloat32Array()

var width: float
var height: float

@onready var fps_counter: Label = $FPSCounter

@onready var gpu_particles_2d: GPUParticles2D = $GPUParticles2D

var rd: RenderingDevice

var uniform_set: RID
var pipeline: RID

# Buffers
var positions_buffer: RID
var velocities_buffer: RID

var position_texture_rd: Texture2DRD

func _ready():
	width = get_viewport_rect().size.x
	height = get_viewport_rect().size.y
	for i in range(particle_count):
		positions.append(randf() * width)
		positions.append(randf() * height)
		#positions.append(randf() * width/4 + width/2 - width/8)
		#positions.append(randf() * height/4 + height/2 - height/8)\
		
		
	var process_material = gpu_particles_2d.process_material as ShaderMaterial
	process_material.set_shader_parameter("positions_buffer", positions_buffer)
	_compute_shader_setup()


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
	
func _simulation_step() -> void:
	
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_dispatch(compute_list, particle_count, 1, 1)
	rd.compute_list_end()

	# Submit to GPU and wait for sync
	rd.submit()
	rd.sync()

func _render_particles() -> void:
	pass
	#var positions_bytes := rd.buffer_get_data(positions_buffer)
	#var positions_floats = positions_bytes.to_float32_array()
	#
	#for i in range(particle_count):
		#var x = positions_floats[i * 2]
		#var y = positions_floats[i * 2 + 1]
		#var t = Transform2D()
		#t.origin = Vector2(x, y)
		
func _process(delta: float) -> void:
	fps_counter.text = str(int(Engine.get_frames_per_second())) + " fps"
	_simulation_step()
	_render_particles()
