extends Node2D

@export var particle_count: int = 1000
@export var particle_size: float = 1.0/4
@export var smoothing_radius: float = 50
@export var particle_mass: float = 25
@export var pressure_multiplier: float = 100000
@export var target_density: float = 0.2
@export var gravity: float = 200
@export_range(0, 1) var elasticity: float = 0.95
@export var viscocity: float = 200
@export var steps_per_frame: int = 1
@export var gradient: Gradient

var positions: PackedVector2Array = PackedVector2Array()
var velocities: PackedVector2Array = PackedVector2Array()
var densities: PackedFloat32Array = PackedFloat32Array()
var pressures: PackedFloat32Array = PackedFloat32Array()
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
var image_size = int(ceil(sqrt(particle_count)))

func _ready():
	
	gpu_particles_2d.amount = particle_count
	gpu_particles_2d.scale = Vector2(0.1, 0.1)
	
	screen_width = get_viewport_rect().size.x
	screen_height = get_viewport_rect().size.y
	
	grid_width = int(ceil(screen_width / smoothing_radius))
	grid_height = int(ceil(screen_height / smoothing_radius))
	bucket_count = grid_width * grid_height
	
	print(bucket_count)
	
	particle_data_image = Image.create(image_size, image_size, false, Image.FORMAT_RGBAH)
	
	for i in range(particle_count):
		#positions.append(Vector2(randf() * screen_width, randf() * screen_height))
		positions.append(Vector2(randf() * screen_width/4 + screen_width/2 - screen_width/8, randf() * screen_height/4 + screen_height/2 - screen_height/8))
		#positions.append(Vector2.ZERO)
		velocities.append(Vector2(0, 0))
	
	# Particle shader setup

	process_material = gpu_particles_2d.process_material as ShaderMaterial
	process_material.set_shader_parameter("particle_count", particle_count)
	process_material.set_shader_parameter("particle_size", particle_size)
	process_material.set_shader_parameter("image_size", image_size)
	var gradient_texture: GradientTexture1D = GradientTexture1D.new()
	gradient_texture.gradient = gradient
	gradient_texture.width = 100
	process_material.set_shader_parameter("gradient_texture", gradient_texture)
	
	RenderingServer.call_on_render_thread(_setup_shaders)
	
	
var rd: RenderingDevice

# Compute shader pipelines
var clear_bucket_counts_pipeline: RID # Clears bucket counts. Needs bucket_count invocations.
var count_buckets_pipeline: RID # Counts buckets for bucket sort. Needs bucket_count invocations.
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
var pressures_buffer: RID
var forces_buffer: RID

# Uniform sets
var clear_bucket_counts_uniform_set: RID
var count_buckets_uniform_set: RID
var prefix_sum_uniform_set: RID
var scatter_uniform_set: RID
var densities_uniform_set: RID
var forces_uniform_set: RID

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
	var clear_bucket_counts_shader := _create_compute_shader(load("res://shaders/compute/clear_bucket_counts.glsl"))
	var count_buckets_shader := _create_compute_shader(load("res://shaders/compute/count_buckets.glsl"))
	var prefix_sum_shader := _create_compute_shader(load("res://shaders/compute/prefix_sum.glsl"))
	var scatter_shader := _create_compute_shader(load("res://shaders/compute/scatter.glsl"))
	var densities_shader := _create_compute_shader(load("res://shaders/compute/densities.glsl"))
	var forces_shader := _create_compute_shader(load("res://shaders/compute/forces.glsl"))
	
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
	pressures_buffer = rd.storage_buffer_create(4 * particle_count)
	
	# Create uniforms
	var params_uniform := _create_params_uniform(0)
	
	var bucket_indices_uniform := _create_uniform(bucket_indices_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 1)
	var bucket_counts_uniform := _create_uniform(bucket_counts_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 2)
	var bucket_prefix_sum_uniform := _create_uniform(bucket_prefix_sum_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 3)
	var bucket_offsets_uniform := _create_uniform(bucket_offsets_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 4)
	var particles_by_bucket_uniform := _create_uniform(particles_by_bucket_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 5)
	
	var positions_uniform := _create_uniform(positions_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 6)
	var densities_uniform := _create_uniform(densities_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 7)
	var pressures_uniform := _create_uniform(pressures_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 8)
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
		pressures_uniform],
		densities_shader,
		0)
	forces_uniform_set = rd.uniform_set_create(
		[params_uniform, 
		bucket_offsets_uniform,
		particles_by_bucket_uniform,
		positions_uniform,
		densities_uniform,
		pressures_uniform,
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
	params_bytes.encode_float(36, target_density)
	params_bytes.encode_float(40, gravity)
	params_bytes.encode_float(44, elasticity)
	params_bytes.encode_float(48, viscocity)
	params_bytes.encode_u32(52, steps_per_frame)
	params_bytes.encode_u32(56, image_size)
	
	var params_buffer = rd.storage_buffer_create(params_bytes.size(), params_bytes)
	return _create_uniform(params_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, binding)
	
func _simulation_step(delta: float) -> void:
	_run_compute_pipeline(clear_bucket_counts_pipeline, clear_bucket_counts_uniform_set, ceil(bucket_count/1024.0))
	_run_compute_pipeline(count_buckets_pipeline, count_buckets_uniform_set, ceil(bucket_count/1024.0))
	_run_compute_pipeline(prefix_sum_pipeline, prefix_sum_uniform_set, 1)
	_run_compute_pipeline(scatter_pipeline, scatter_uniform_set, ceil(particle_count/1024.0))
	_run_compute_pipeline(densities_pipeline, densities_uniform_set, ceil(particle_count/1024.0))
	_run_compute_pipeline_delta(forces_pipeline, forces_uniform_set, ceil(particle_count/1024.0), delta)
	
	var output_bytes := rd.buffer_get_data(densities_buffer)
	var output := Array(output_bytes.to_float32_array())
	print("density: ", output.max())
	output_bytes = rd.buffer_get_data(positions_buffer)
	output = Array(output_bytes.to_float32_array())
	print("pos: ", output.max())
	output_bytes = rd.buffer_get_data(velocities_buffer)
	output = Array(output_bytes.to_float32_array())
	print("vel: ",  output.max())
	output_bytes = rd.buffer_get_data(pressures_buffer)
	output = Array(output_bytes.to_float32_array())
	print("pressure: ",  output.max())
	
	print("-------------------------------------------")
	# For debugging counting sort
	#var output_bytes := rd.buffer_get_data(bucket_indices_buffer)
	#var output := output_bytes.to_int32_array()
	#print("Bucket indices: ", output)
	#
	#output_bytes = rd.buffer_get_data(bucket_counts_buffer)
	#output = output_bytes.to_int32_array()
	#print("Bucket counts: ", output)
	#
	#output_bytes = rd.buffer_get_data(bucket_prefix_sum_buffer)
	#output = output_bytes.to_int32_array()
	#print("Prefix sum: ", output)
	#
	#output_bytes = rd.buffer_get_data(bucket_offsets_buffer)
	#output = output_bytes.to_int32_array()
	#print("Bucket offsets: ", output)
	#
	#output_bytes = rd.buffer_get_data(particles_by_bucket_buffer)
	#output = output_bytes.to_int32_array()
	#print("Particles by bucket: ", output)
	
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

func _run_compute_pipeline_delta(pipeline: RID, uniform_set: RID, thread_count: int, delta: float) -> void:
	var push_constant_bytes := PackedByteArray()
	push_constant_bytes.resize(16)  # Make it 16 bytes instead of 4
	push_constant_bytes.encode_float(0, delta)
	# Fill the rest with zeros for padding
	push_constant_bytes.encode_float(4, 0.0)
	push_constant_bytes.encode_float(8, 0.0)
	push_constant_bytes.encode_float(12, 0.0)
	
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_set_push_constant(compute_list, push_constant_bytes, push_constant_bytes.size())
	rd.compute_list_dispatch(compute_list, thread_count, 1, 1)
	rd.compute_list_end()
	# Don't need rd.submit() or rd.sync(). It only applies for local rendering devices (we are using the global one)

func _physics_process(delta: float) -> void:
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
	rd.free_rid(pressures_buffer)
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
	rd.free_rid(forces_uniform_set)
