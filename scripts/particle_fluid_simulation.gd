extends Node2D

@export var particle_count: int = 1
@export var smoothing_radius: float = 50
@export var particle_mass: float = 1
@export var pressure_multiplier: float = 500
@export var target_density: float = 3
@export var gravity: float = 0
@export_range(0, 1) var elasticity: float = 0.95
@export var viscocity: float = 50
@export var steps_per_frame: int = 2


var positions: PackedVector2Array = PackedVector2Array()
var velocities: PackedVector2Array = PackedVector2Array()
var densities: PackedFloat32Array = PackedFloat32Array()
var pressures: PackedFloat32Array = PackedFloat32Array()
var forces: PackedVector2Array = PackedVector2Array()

var screen_width: float
var screen_height: float

@onready var fps_counter: Label = $FPSCounter
@onready var gpu_particles_2d: GPUParticles2D = $GPUParticles2D
var process_material: ShaderMaterial

var particle_data_image: Image
var particle_data_texture : ImageTexture
var particle_data_texture_rd: Texture2DRD
var particle_data_buffer : RID
var image_size = int(ceil(sqrt(particle_count)))


func _ready():
	gpu_particles_2d.amount = particle_count
	
	screen_width = get_viewport_rect().size.x
	screen_height = get_viewport_rect().size.y
	
	particle_data_image = Image.create(image_size, image_size, false, Image.FORMAT_RGBAH)
	for i in range(particle_count):
		#positions.append(randf() * screen_width
		#positions.append(randf() * screen_height
		positions.append(Vector2(0, 0))
		velocities.append(Vector2(1, 1))
		#positions.append(randf() * screen_width/4 + screen_width/2 - screen_width/8)
		#positions.append(randf() * screen_height/4 + screen_height/2 - screen_height/8)
		
	process_material = gpu_particles_2d.process_material as ShaderMaterial
	process_material.set_shader_parameter("particle_count", particle_count)
	process_material.set_shader_parameter("image_size", image_size)
	print(positions)
	print(velocities)
	
	RenderingServer.call_on_render_thread(_setup_shaders)
	
	

var rd: RenderingDevice

var uniform_set: RID
var pipeline: RID

# Buffers
var positions_buffer: RID
var velocities_buffer: RID


func _setup_shaders() -> void:
	# Create a local rendering device.
	rd = RenderingServer.get_rendering_device()
	
	# --- Connect Compute Shader to Particle Shader ---
	
	var fmt := RDTextureFormat.new()
	fmt.width = image_size
	fmt.height = image_size
	fmt.format = RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
	fmt.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
	
	var view := RDTextureView.new()
	particle_data_buffer = rd.texture_create(fmt, view, [particle_data_image.get_data()])
	particle_data_texture_rd = Texture2DRD.new()
	particle_data_texture_rd.texture_rd_rid = particle_data_buffer # Connect texture to buffer
	process_material.set_shader_parameter("particle_data", particle_data_texture_rd) # Texture stored by reference, will be updated in the particle shader once the compute shader edits it
	# --- === ---
	
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
	var positions_uniform := _create_uniform(positions_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 0)
	var velocities_uniform := _create_uniform(velocities_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 1)
	var params_uniform := _create_params_uniform(2)
	var particle_data_uniform = _create_uniform(particle_data_buffer, RenderingDevice.UNIFORM_TYPE_IMAGE, 3)
	

	uniform_set = rd.uniform_set_create(
		[positions_uniform, 
		velocities_uniform,
		params_uniform,
		particle_data_uniform],
		shader, 
		0) # the last parameter (the 0) needs to match the "set" in our shader file

	# Create a compute pipeline 
	pipeline = rd.compute_pipeline_create(shader)
	
func _create_uniform(buffer: RID, uniform_type: RenderingDevice.UniformType, binding: int) -> RDUniform:
	var uniform := RDUniform.new()
	uniform.uniform_type = uniform_type
	uniform.binding = binding
	uniform.add_id(buffer)
	return uniform
	
	
	
	
func _create_params_uniform(binding: int) -> RDUniform:
	var params_bytes := PackedByteArray()
	params_bytes.resize(52)
	params_bytes.encode_u32(0, particle_count)
	params_bytes.encode_float(4, screen_width)
	params_bytes.encode_float(8, screen_height)
	params_bytes.encode_float(12, smoothing_radius)
	params_bytes.encode_float(16, particle_mass)
	params_bytes.encode_float(20, pressure_multiplier)
	params_bytes.encode_float(24, target_density)
	params_bytes.encode_float(28, gravity)
	params_bytes.encode_float(32, elasticity)
	params_bytes.encode_float(36, viscocity)
	params_bytes.encode_u32(40, steps_per_frame)
	params_bytes.encode_u32(44, image_size)

	var params_buffer = rd.storage_buffer_create(params_bytes.size(), params_bytes)
	return _create_uniform(params_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, binding)
	
func _simulation_step() -> void:
	
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	
	rd.compute_list_dispatch(compute_list, ceil(particle_count/1024.0), 1, 1)
	rd.compute_list_end()
	# Submit to GPU and wait for sync
	rd.submit()
	rd.sync()

func _process(delta: float) -> void:
	fps_counter.text = str(int(Engine.get_frames_per_second())) + " fps"
	_simulation_step()
