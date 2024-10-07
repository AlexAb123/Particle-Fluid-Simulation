extends Node2D

var NUM_BOIDS = 50000
var boid_pos = []
var boid_vel = []
var max_vel = 50
func _ready():
	_generate_boids()
func _generate_boids():
	for i in NUM_BOIDS:
		var p = Vector2(randf() * get_viewport_rect().size.x, randf()  * get_viewport_rect().size.y)
		print(p)
		boid_pos.append(p)
		boid_vel.append(Vector2(randf_range(-1.0, 1.0) * max_vel, randf_range(-1.0, 1.0) * max_vel))

#var buffer : RID
#var rd : RenderingDevice
#var input := PackedFloat32Array([1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
#
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

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
	
	
	
#Particles:
	#Smoothing radius
	#Smoothing function
		#Need Derivative of smoothing function
	#The influence of each particle is determined by the smoothing function. Has 0 influence at distance > smoothing radius
	
