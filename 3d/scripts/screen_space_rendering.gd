extends Node3D

@export var particle_count: int = 1024
@export var particle_size: float = 10
@export var smoothing_radius: float = 50
@export var particle_mass: float = 500.0
@export var target_density: float = 0.1
@export var pressure_multiplier: float = 100000
@export var near_pressure_multiplier: float = 50000
@export var gravity: float = 150
@export_range(0, 1) var elasticity: float = 0.95
@export var viscosity: float = 50
@export var steps_per_frame: int = 1
@export var gradient: Gradient
@export var bounds: Vector3 = Vector3(500, 250, 250)
@export var origin: Vector3 = Vector3(-250, 0, -125)

var workgroup_size: int = 32

var density_kernel_factor: float = 15.0 / (pow(smoothing_radius, 5) * 2.0 * PI)
var near_density_kernel_factor: float = 15.0 / (pow(smoothing_radius, 6) * PI)
var viscosity_kernel_factor: float = 315.0 / (pow(smoothing_radius, 9) * 64.0 * PI)

var positions: PackedVector4Array = PackedVector4Array()
var velocities: PackedVector4Array = PackedVector4Array()
var densities: PackedFloat32Array = PackedFloat32Array()
var near_densities: PackedFloat32Array = PackedFloat32Array()

var grid_width: int
var grid_height: int
var grid_depth: int
var bucket_count: int

@onready var fps_counter: Label = $CanvasLayer/FPSCounter
@onready var sub_viewport: SubViewport = $SubViewport
@onready var mesh_instance_3d: MeshInstance3D = $SubViewport/MeshInstance3D
@onready var color_rect: ColorRect = $CanvasLayer/ColorRect

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
	
	grid_width = int(ceil(bounds.x / smoothing_radius))
	grid_height = int(ceil(bounds.y / smoothing_radius))
	grid_depth = int(ceil(bounds.z / smoothing_radius))
	bucket_count = grid_width * grid_height * grid_depth
	
	particle_data_image = Image.create(image_size, image_size, false, Image.FORMAT_RGBAH)
	
	for i in range(particle_count):
		#positions.append(Vector4(randf() * bounds.x, randf() * bounds.y, randf() * bounds.z, 0))
		positions.append(Vector4(randf() * bounds.x/4 + bounds.x/2 - bounds.x/8, randf() * bounds.y/4 + bounds.y/2 - bounds.y/8, randf() * bounds.z/4 + bounds.z/2 - bounds.z/8, 0))
		velocities.append(Vector4.ZERO)
	
	_mesh_setup()
	
	RenderingServer.call_on_render_thread(_setup_shaders)
	
func _mesh_setup():
	
	var vertices := PackedVector3Array()
	for i in range(particle_count):
		vertices.append(Vector3(i, 0, 0))
	var arr_mesh = ArrayMesh.new()
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_POINTS, arrays)
	mesh_instance_3d.mesh = arr_mesh
	
	process_material = mesh_instance_3d.material_override as ShaderMaterial
	process_material.set_shader_parameter("particle_count", particle_count)
	process_material.set_shader_parameter("particle_size", particle_size)
	process_material.set_shader_parameter("image_size", image_size)
	process_material.set_shader_parameter("origin", origin)
	var gradient_texture: GradientTexture1D = GradientTexture1D.new()
	gradient_texture.gradient = gradient
	process_material.set_shader_parameter("gradient_texture", gradient_texture)
	
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
	var clear_bucket_counts_shader := _create_compute_shader(load("res://3d/shaders/compute/clear_bucket_counts_3d.glsl"))
	var count_buckets_shader := _create_compute_shader(load("res://3d/shaders/compute/count_buckets_3d.glsl"))
	var prefix_sum_shader := _create_compute_shader(load("res://3d/shaders/compute/prefix_sum_3d.glsl"))
	var scatter_shader := _create_compute_shader(load("res://3d/shaders/compute/scatter_3d.glsl"))
	var densities_shader := _create_compute_shader(load("res://3d/shaders/compute/densities_3d.glsl"))
	var forces_shader := _create_compute_shader(load("res://3d/shaders/compute/forces_3d.glsl"))
	
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
	params_bytes.resize(84)
	params_bytes.encode_u32(0, particle_count)
	params_bytes.encode_float(4, bounds.x)
	params_bytes.encode_float(8, bounds.y)
	params_bytes.encode_float(12, bounds.z)
	params_bytes.encode_float(16, smoothing_radius)
	params_bytes.encode_u32(20, grid_width)
	params_bytes.encode_u32(24, grid_height)
	params_bytes.encode_u32(28, grid_depth)
	params_bytes.encode_u32(32, bucket_count)
	params_bytes.encode_float(36, particle_mass)
	params_bytes.encode_float(40, pressure_multiplier)
	params_bytes.encode_float(44, near_pressure_multiplier)
	params_bytes.encode_float(48, target_density)
	params_bytes.encode_float(52, gravity)
	params_bytes.encode_float(56, elasticity)
	params_bytes.encode_float(60, viscosity)
	params_bytes.encode_u32(64, steps_per_frame)
	params_bytes.encode_u32(68, image_size)
	params_bytes.encode_float(72, density_kernel_factor)
	params_bytes.encode_float(76, near_density_kernel_factor)
	params_bytes.encode_float(80, viscosity_kernel_factor)
	
	var params_buffer = rd.storage_buffer_create(params_bytes.size(), params_bytes)
	return _create_uniform(params_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, binding)
	
func _simulation_step(delta: float) -> void:
	_run_compute_pipeline(clear_bucket_counts_pipeline, clear_bucket_counts_uniform_set, ceil(bucket_count/float(workgroup_size)))
	_run_compute_pipeline(count_buckets_pipeline, count_buckets_uniform_set, ceil(particle_count/float(workgroup_size)))
	_run_compute_pipeline(prefix_sum_pipeline, prefix_sum_uniform_set, 1)
	_run_compute_pipeline(scatter_pipeline, scatter_uniform_set, ceil(particle_count/float(workgroup_size)))
	_run_compute_pipeline(densities_pipeline, densities_uniform_set, ceil(particle_count/float(workgroup_size)))
	_run_compute_pipeline_push_constant(forces_pipeline, forces_uniform_set, ceil(particle_count/float(workgroup_size)), [delta, 0.0, 0.0, 0.0])
	
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
