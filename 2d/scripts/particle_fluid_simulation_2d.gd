extends Node2D

@export var particle_count: int = 1024
@export var particle_size: float = 1.0/8
@export var smoothing_radius: float = 50
@export var particle_mass: float = 50
@export var target_density: float = 0.2
@export var pressure_multiplier: float = 300000
@export var near_pressure_multiplier: float = 100000
@export var gravity: float = 150
@export_range(0, 1) var elasticity: float = 0.95
@export var viscosity: float = 50
@export var steps_per_frame: int = 1
@export var mouse_force_multiplier: float = 200
@export var mouse_force_radius: float = 150
@export var gradient: Gradient

var mouse_force_strength: float
var mouse_force_position: Vector2

var positions: PackedVector2Array = PackedVector2Array()
var velocities: PackedVector2Array = PackedVector2Array()
var densities: PackedFloat32Array = PackedFloat32Array()
var near_densities: PackedFloat32Array = PackedFloat32Array()
var forces: PackedVector2Array = PackedVector2Array()

var screen_width: float
var screen_height: float
var grid_width: int
var grid_height: int
var bucket_count: int

@onready var fps_counter: Label = $FPSCounter
@onready var gpu_particles_2d: GPUParticles2D = $GPUParticles2D
var process_material: ShaderMaterial

var particle_data_image: Image
var particle_data_texture_rd: Texture2DRD
var particle_data_buffer : RID
var image_size: int

var rd: RenderingDevice

# Compute shader pipelines
var clear_bucket_counts_pipeline: RID # Clears bucket counts. Needs bucket_count invocations.
var count_buckets_pipeline: RID # Counts buckets for bucket sort. Needs particle_count invocations.
var prefix_sum_pipeline: RID # Runs a prefix sum on bucket_counts and generates bucket_offsets for quick neighbour search. Needs 1 invocation (because it does not yet use a parallel prefix sum algorithm).
var scatter_pipeline: RID # Scatters the prefix sum to create particles_by_bucket which is used alongside bucket_offsets for quick neighbour search. Needs particle_count invocations.
var densities_pipeline: RID # Calculates densities and pressure to every particle. Needs particle_count invocations.
var forces_pipeline: RID # Uses density and pressure calculations to caluclate and apply forces to every particle. Needs particle_count invocations.

# Buffers
var bucket_indices_buffer: RID
var bucket_counts_buffer: RID
var bucket_prefix_sum_buffer: RID
var bucket_offsets_buffer: RID
var particles_by_bucket_buffer: RID
var positions_buffer: RID
var velocities_buffer: RID
var densities_buffer: RID
var near_densities_buffer: RID
var forces_buffer: RID

# Uniform sets
var clear_bucket_counts_uniform_set: RID
var count_buckets_uniform_set: RID
var prefix_sum_uniform_set: RID
var scatter_uniform_set: RID
var densities_uniform_set: RID
var near_densities_uniform_set: RID
var forces_uniform_set: RID

func _ready():
	
	image_size = int(ceil(sqrt(particle_count)))
	gpu_particles_2d.amount = particle_count
	gpu_particles_2d.scale = Vector2(0.1, 0.1)
	
	screen_width = get_viewport_rect().size.x
	screen_height = get_viewport_rect().size.y
	
	print(screen_width)
	print(screen_height)
	
	grid_width = int(ceil(screen_width / smoothing_radius))
	grid_height = int(ceil(screen_height / smoothing_radius))
	bucket_count = grid_width * grid_height
	
	print(bucket_count)
	particle_data_image = Image.create(image_size, image_size, false, Image.FORMAT_RGBAH)
	
	for i in range(particle_count):
		#positions.append(Vector2(randf() * screen_width, randf() * screen_height))
		positions.append(Vector2(randf() * screen_width/4 + screen_width/2 - screen_width/8, randf() * screen_height/4 + screen_height/2 - screen_height/8))
		velocities.append(Vector2(0, 0))
	
	# Particle shader setup
	process_material = gpu_particles_2d.process_material as ShaderMaterial
	process_material.set_shader_parameter("particle_count", particle_count)
	process_material.set_shader_parameter("particle_size", particle_size)
	process_material.set_shader_parameter("image_size", image_size)
	var gradient_texture: GradientTexture1D = GradientTexture1D.new()
	gradient_texture.gradient = gradient
	process_material.set_shader_parameter("gradient_texture", gradient_texture)
	
	RenderingServer.call_on_render_thread(_setup_shaders)
	
func _input(event):
	if event is InputEventMouseMotion:
		mouse_force_position = event.position
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			mouse_force_strength = int(event.pressed) * mouse_force_multiplier
		if event.button_index == MOUSE_BUTTON_RIGHT:
			mouse_force_strength = -1 * int(event.pressed) * mouse_force_multiplier
			
func _setup_shaders() -> void:
	
	# Get global rendering device
	rd = RenderingServer.get_rendering_device()
	
	# Connect compute shader to particle shader
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

	# Load compute shaders
	var clear_bucket_counts_shader := _create_compute_shader(load("res://2d/shaders/compute/clear_bucket_counts_2d.glsl"))
	var count_buckets_shader := _create_compute_shader(load("res://2d/shaders/compute/count_buckets_2d.glsl"))
	var prefix_sum_shader := _create_compute_shader(load("res://2d/shaders/compute/prefix_sum_2d.glsl"))
	var scatter_shader := _create_compute_shader(load("res://2d/shaders/compute/scatter_2d.glsl"))
	var densities_shader := _create_compute_shader(load("res://2d/shaders/compute/densities_2d.glsl"))
	var forces_shader := _create_compute_shader(load("res://2d/shaders/compute/forces_2d.glsl"))
	
	# Initialize Pipelines
	clear_bucket_counts_pipeline = rd.compute_pipeline_create(clear_bucket_counts_shader)
	count_buckets_pipeline = rd.compute_pipeline_create(count_buckets_shader)
	prefix_sum_pipeline = rd.compute_pipeline_create(prefix_sum_shader)
	scatter_pipeline = rd.compute_pipeline_create(scatter_shader)
	densities_pipeline = rd.compute_pipeline_create(densities_shader)
	forces_pipeline = rd.compute_pipeline_create(forces_shader)
	
	# Create buffers - int/uint/float: 4 bytes. vec2: 8 bytes
	bucket_indices_buffer = rd.storage_buffer_create(4 * particle_count)
	bucket_counts_buffer = rd.storage_buffer_create(4 * bucket_count)
	bucket_prefix_sum_buffer = rd.storage_buffer_create(4 * bucket_count)
	bucket_offsets_buffer = rd.storage_buffer_create(4 * bucket_count)
	particles_by_bucket_buffer = rd.storage_buffer_create(4 * particle_count)
	
	var positions_bytes := positions.to_byte_array()
	positions_buffer = rd.storage_buffer_create(positions_bytes.size(), positions_bytes)
	var velocities_bytes := velocities.to_byte_array()
	velocities_buffer = rd.storage_buffer_create(velocities_bytes.size(), velocities_bytes)
	densities_buffer = rd.storage_buffer_create(4 * particle_count)
	near_densities_buffer = rd.storage_buffer_create(4 * particle_count)
	
	# Create uniforms
	var params_uniform := _create_params_uniform(0)
	
	var bucket_indices_uniform := _create_uniform(bucket_indices_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 1)
	var bucket_counts_uniform := _create_uniform(bucket_counts_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 2)
	var bucket_prefix_sum_uniform := _create_uniform(bucket_prefix_sum_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 3)
	var bucket_offsets_uniform := _create_uniform(bucket_offsets_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 4)
	var particles_by_bucket_uniform := _create_uniform(particles_by_bucket_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 5)
	
	var positions_uniform := _create_uniform(positions_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 6)
	var densities_uniform := _create_uniform(densities_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 7)
	var near_densities_uniform := _create_uniform(near_densities_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 8)
	var velocities_uniform := _create_uniform(velocities_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 9)
	
	var particle_data_uniform := _create_uniform(particle_data_buffer, RenderingDevice.UNIFORM_TYPE_IMAGE, 10)
	
	# Create uniform sets
	clear_bucket_counts_uniform_set = rd.uniform_set_create(
		[params_uniform,
		bucket_counts_uniform],
		clear_bucket_counts_shader,
		0) # the last parameter (the 0) needs to match the "set" in our shader file
	count_buckets_uniform_set = rd.uniform_set_create(
		[params_uniform,
	 	bucket_indices_uniform,
		bucket_counts_uniform,
		positions_uniform],
		count_buckets_shader,
		0)
	prefix_sum_uniform_set = rd.uniform_set_create(
		[params_uniform, 
		bucket_counts_uniform,
		bucket_prefix_sum_uniform,
		bucket_offsets_uniform],
		prefix_sum_shader,
		0)
	scatter_uniform_set = rd.uniform_set_create(
		[params_uniform, 
		bucket_indices_uniform,
		bucket_prefix_sum_uniform,
		particles_by_bucket_uniform],
		scatter_shader,
		0)
	densities_uniform_set = rd.uniform_set_create(
		[params_uniform, 
		bucket_offsets_uniform,
		particles_by_bucket_uniform,
		positions_uniform,
		densities_uniform,
		near_densities_uniform],
		densities_shader,
		0)
	forces_uniform_set = rd.uniform_set_create(
		[params_uniform, 
		bucket_offsets_uniform,
		particles_by_bucket_uniform,
		positions_uniform,
		densities_uniform,
		near_densities_uniform,
		velocities_uniform,
		particle_data_uniform],
		forces_shader,
		0)
		
func _create_uniform(buffer: RID, uniform_type: RenderingDevice.UniformType, binding: int) -> RDUniform:
	var uniform := RDUniform.new()
	uniform.uniform_type = uniform_type
	uniform.binding = binding
	uniform.add_id(buffer)
	return uniform
	
func _create_params_uniform(binding: int) -> RDUniform:
	var params_bytes := PackedByteArray()
	params_bytes.resize(68)
	params_bytes.encode_u32(0, particle_count)
	params_bytes.encode_float(4, screen_width)
	params_bytes.encode_float(8, screen_height)
	params_bytes.encode_float(12, smoothing_radius)
	params_bytes.encode_u32(16, grid_width)
	params_bytes.encode_u32(20, grid_height)
	params_bytes.encode_u32(24, bucket_count)
	params_bytes.encode_float(28, particle_mass)
	params_bytes.encode_float(32, pressure_multiplier)
	params_bytes.encode_float(36, near_pressure_multiplier)
	params_bytes.encode_float(40, target_density)
	params_bytes.encode_float(44, gravity)
	params_bytes.encode_float(48, elasticity)
	params_bytes.encode_float(52, viscosity)
	params_bytes.encode_u32(56, steps_per_frame)
	params_bytes.encode_u32(60, image_size)
	
	var params_buffer = rd.storage_buffer_create(params_bytes.size(), params_bytes)
	return _create_uniform(params_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, binding)
	
func _simulation_step(delta: float) -> void:
	_run_compute_pipeline(clear_bucket_counts_pipeline, clear_bucket_counts_uniform_set, ceil(bucket_count/1024.0))
	_run_compute_pipeline(count_buckets_pipeline, count_buckets_uniform_set, ceil(particle_count/1024.0))
	_run_compute_pipeline(prefix_sum_pipeline, prefix_sum_uniform_set, 1)
	_run_compute_pipeline(scatter_pipeline, scatter_uniform_set, ceil(particle_count/1024.0))
	_run_compute_pipeline(densities_pipeline, densities_uniform_set, ceil(particle_count/1024.0))
	_run_compute_pipeline_push_constant(forces_pipeline, forces_uniform_set, ceil(particle_count/1024.0), [delta, mouse_force_strength, mouse_force_position.x, mouse_force_position.y, mouse_force_radius, 0.0, 0.0, 0.0])
	
func _create_compute_shader(shader_file: Resource) -> RID:
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	return rd.shader_create_from_spirv(shader_spirv)

func _run_compute_pipeline(pipeline: RID, uniform_set: RID, thread_count: int) -> void:
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_dispatch(compute_list, thread_count, 1, 1)
	rd.compute_list_end()
	# Don't need rd.submit() or rd.sync(). It only applies for local rendering devices (we are using the global one)

func _run_compute_pipeline_push_constant(pipeline: RID, uniform_set: RID, thread_count: int, push_constant: Array) -> void: # push_constant array must be at least length 4 (some weird compute shader thing)
	var push_constant_bytes := PackedByteArray()
	push_constant_bytes.resize(4 * push_constant.size())
	for i in range(push_constant.size()):
		push_constant_bytes.encode_float(4 * i, push_constant[i])
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_set_push_constant(compute_list, push_constant_bytes, push_constant_bytes.size())
	rd.compute_list_dispatch(compute_list, thread_count, 1, 1)
	rd.compute_list_end()
	# Don't need rd.submit() or rd.sync(). It only applies for local rendering devices (we are using the global one)

func _process(delta: float) -> void:
	fps_counter.text = str(int(Engine.get_frames_per_second())) + " fps"
	for i in range(steps_per_frame):
		_simulation_step(delta)
		
func _exit_tree() -> void:
	rd.free_rid(bucket_indices_buffer)
	rd.free_rid(bucket_counts_buffer)
	rd.free_rid(bucket_prefix_sum_buffer)
	rd.free_rid(bucket_offsets_buffer)
	rd.free_rid(particles_by_bucket_buffer)
	rd.free_rid(positions_buffer)
	rd.free_rid(velocities_buffer)
	rd.free_rid(densities_buffer)
	rd.free_rid(near_densities_buffer)
	rd.free_rid(clear_bucket_counts_pipeline)
	rd.free_rid(count_buckets_pipeline)
	rd.free_rid(prefix_sum_pipeline)
	rd.free_rid(scatter_pipeline)
	rd.free_rid(densities_pipeline)
	rd.free_rid(forces_pipeline)
	rd.free_rid(clear_bucket_counts_uniform_set)
	rd.free_rid(count_buckets_uniform_set)
	rd.free_rid(prefix_sum_uniform_set)
	rd.free_rid(scatter_uniform_set)
	rd.free_rid(densities_uniform_set)
	rd.free_rid(near_densities_uniform_set)
	rd.free_rid(forces_uniform_set)
