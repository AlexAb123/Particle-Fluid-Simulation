extends Node2D

@onready var gpu_particles_2d: GPUParticles2D = $GPUParticles2D

@export_range(0, 500) var particle_count: int = 250
@export_range(0, 1000) var smoothing_radius: float = 100
@export_range(0, 5000) var particle_mass: float = 1000
@export_range(0, 2500) var target_density: float = 500
@export_range(0, 50) var pressure_multiplier: float = 4

var image_size = int(ceil(sqrt(particle_count)))
var positions: Array[Vector2] = []
var velocities: Array[Vector2] = []
var densities: Array[float] = []
var gradients: Array[Vector2] = []

var data_image: Image
var data_texture: ImageTexture

func _ready() -> void:
	data_image = Image.create(image_size, image_size, false, Image.FORMAT_RGBAF)
	gpu_particles_2d.amount = particle_count
	
	_initialize_data()
	_update_densities()
	_update_data_texture()
	
func _initialize_data():
	for i in particle_count:
		positions.append(Vector2(randf() * get_viewport_rect().size.x, randf() * get_viewport_rect().size.y))
		velocities.append(Vector2(0,0))
		densities.append(0.0)

# Updates the data texture and passes it into the particle shader
func _update_data_texture():
	for i in particle_count:
		data_image.set_pixel(i % image_size, int(i / image_size), Color(positions[i].x, positions[i].y, densities[i], 0))
	data_texture = ImageTexture.create_from_image(data_image)
	gpu_particles_2d.process_material.set_shader_parameter("particle_data", data_texture)
	
func _process(delta: float) -> void:
	DisplayServer.window_set_title("FPS: " + str(Engine.get_frames_per_second()))
	print(particle_mass)

func _update_densities():
	for i in particle_count:
		densities[i] = _calculate_density(positions[i])
func _calculate_density(pos: Vector2):
	var density = 0.0
	for i in particle_count:
		var distance = pos.distance_to(positions[i])
		var influence = smoothing_function(smoothing_radius, distance)
		density += influence * particle_mass
	return density

func _calculate_density_gradient(pos: Vector2):
	var gradient: Vector2 = Vector2.ZERO
	for i in particle_count:
		var distance = pos.distance_to(positions[i])
		# If distance is 0 (the two particles are on top of eachother, or it's comparing to itself), choose a random direction.
		var direction = Vector2(1, 0).rotated(randf_range(0.0, 2*PI)) if distance == 0 else (positions[i] - pos) / distance
		var magnitude = smoothing_function_derivative(smoothing_radius, distance)
		gradient += particle_mass * direction * magnitude
	return gradient

# The further we are from the target density, the faster the particle should move.
func _convert_density_to_pressure(density):
	return (density - target_density) * pressure_multiplier

func _update_positions():
	pass

func smoothing_function(rad, dst):
	return max(0, pow(rad - dst, 3)) /  (PI * pow(rad, 5) / 10 ) # Divide by this to normalize (integral will always be 1) because the total contribution of a single particle to the density should NOT depend on the smoothing radius
func smoothing_function_derivative(rad, dst):
	return 0.0 if dst > rad else -3 * pow(rad - dst, 2) / (PI * pow(rad, 5) / 10 ) # Divide by this to normalize (integral will always be 1) because the total contribution of a single particle to the density should NOT depend on the smoothing radius
	
#var buffer : RID
#var rd : RenderingDevice
#var input := PackedFloat32Array([1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
## Called when the node enters the scene tree for the first time.
#func _ready() -> void:
	## Create a local rendering device.
	#rd = RenderingServer.create_local_rendering_device()
	#
	## Load GLSL shader
	#var shader_file := load("res://shaders/compute_shader.glsl")
	#var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	#var shader := rd.shader_create_from_spirv(shader_spirv)
	#
	## Prepare our data. We use floats in the shader, so we need 32 bit.
	#var input_bytes := input.to_byte_array()
	#
	## Create a storage buffer that can hold our float values.
	## Each float has 4 bytes (32 bit) so 10 x 4 = 40 bytes
	#buffer = rd.storage_buffer_create(input_bytes.size(), input_bytes)
#
	## Create a uniform to assign the buffer to the rendering device
	#var uniform := RDUniform.new()
	#uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	#uniform.binding = 0 # this needs to match the "binding" in our shader file
	#uniform.add_id(buffer)
	#var uniform_set := rd.uniform_set_create([uniform], shader, 0) # the last parameter (0) needs to match the "set" in our shader file
	#
	## Create a compute pipeline
	#var pipeline := rd.compute_pipeline_create(shader)
	#var compute_list := rd.compute_list_begin()
	#rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	#rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	#rd.compute_list_dispatch(compute_list, 2, 1, 1)
	#rd.compute_list_end()
	#
	## Submit to GPU and wait for sync
	#rd.submit()
	#rd.sync()
#
	## Read back the data from the buffer
	#var output_bytes := rd.buffer_get_data(buffer)
	#var output := output_bytes.to_float32_array()
	#print("Input: ", input)
	#print("Output: ", output)

	
	
	
	
#Particles:
	#Smoothing radius
	#Smoothing function
	# Normalizing the smoothing function:
	# Why do we normalize? Because the total contribution of a single particle to the density should NOT depend on the smoothing radius
	# Plug into desmos 3D for a visualization of non-normalized (the last 2 linse are the normalized form). Move radius, the total contribution (which is the volume of the surface) changes with respect to R
	# R=1
	# r=R
	# z=\max\left(0,\ \left(R-r\right)^{3}\right)\left\{z>0\right\}
	# \int_{0}^{2\pi}\int_{0}^{R}\max\left(0,\ \left(R-r\right)^{3}\right)rdrd\theta
	# z=\frac{\max\left(0,\ \left(R-r\right)^{3}\right)}{\frac{\pi R^{5}}{10}}\left\{z>0\right\}
	# \int_{0}^{2\pi}\int_{0}^{R}\frac{\max\left(0,\ \left(R-r\right)^{3}\right)}{\frac{\pi R^{5}}{10}}rdrd\theta
	# We just need to divide by some mulitple of R^5 to normalize it. Here we divide by pi R^5 / 10 just to make it equal to 0
		#Need Derivative of smoothing function
	#The influence of each particle is determined by the smoothing function. Has 0 influence at distance > smoothing radius
