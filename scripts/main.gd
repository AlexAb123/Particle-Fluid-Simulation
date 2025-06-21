extends Node2D

@export var particle_count: int = 225
@export var smoothing_radius: int = 50
@export var particle_mass: float = 1
@export var pressure_multiplier: float = 500
@export var target_density: float = 3
@export var gravity: float = 0
@export_range(0, 1) var elasticity: float = 0.95
@export var viscocity: float = 1000

@export var gradient: Gradient

var positions: PackedVector2Array = PackedVector2Array()
var velocities: PackedVector2Array = PackedVector2Array()
var densities: PackedFloat32Array = PackedFloat32Array()
var pressures: PackedFloat32Array = PackedFloat32Array()
var forces: PackedVector2Array = PackedVector2Array()

@onready var fps_counter: Label = $FPSCounter

# Maps spatial bucket coordinates (Vector2i) to an Array of particle indices.
var spatial_buckets: Dictionary[Vector2i, PackedInt32Array] = {}

func _ready():
	var width = get_viewport_rect().size.x
	var height = get_viewport_rect().size.y
	for i in range(particle_count):
		positions.append(Vector2(randf() * width, randf() * height))
		velocities.append(Vector2(0,0))
		densities.append(0.0)
		pressures.append(0.0)
		forces.append(Vector2(0,0))

func _process(delta: float) -> void:
	
	fps_counter.text = str(int(Engine.get_frames_per_second())) + " fps"
	
	_simulate_step(delta)
	
	queue_redraw()
	
func _simulate_step(delta: float) -> void:
	_update_spatial_buckets()
	_update_densities()
	_update_pressures()
	_update_forces()
	_update_velocities(delta)
	_update_positions(delta)

func _draw():
	for i in range(particle_count):
		var pos = positions[i]
		var value = velocities[i].length() * 50 - 6
		draw_circle(pos, 3, gradient.sample(value))
 
func _get_spatial_bucket(pos: Vector2) -> Vector2i:
	return Vector2i(int(pos.x/smoothing_radius), int(pos.y/smoothing_radius))

# Returns a list of all other particles in neighbouring spatial buckets
func _get_spatial_bucket_neighbours(pos: Vector2) -> PackedInt32Array:
	var neighbours: PackedInt32Array = PackedInt32Array()
	var bucket = _get_spatial_bucket(pos)
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var neighbour_bucket = bucket + Vector2i(dx, dy)
			if spatial_buckets.has(neighbour_bucket):
				neighbours.append_array(spatial_buckets[neighbour_bucket])
	return neighbours
	
func _update_spatial_buckets():
	spatial_buckets.clear()
	for i in range(positions.size()):
		var pos = positions[i]
		var bucket = _get_spatial_bucket(pos)
		if not spatial_buckets.has(bucket):
			spatial_buckets[bucket] = PackedInt32Array()
		spatial_buckets[bucket].append(i)

func _update_velocities(delta: float) -> void:
	for i in range(particle_count):
		velocities[i] += forces[i] / particle_mass * delta
		velocities[i] += Vector2(0, gravity) * delta

func _update_positions(delta: float):
	for i in range(particle_count):
		positions[i] += velocities[i] * delta
		
		# Handle collisions with the edge of the screen
		if positions[i].x < 0:
			positions[i].x = 0
			velocities[i].x *= -1 * elasticity
		elif positions[i].x > get_viewport_rect().size.x:
			positions[i].x = get_viewport_rect().size.x
			velocities[i].x *= -1 * elasticity
		if positions[i].y < 0:
			positions[i].y = 0
			velocities[i].y *= -1 * elasticity
		elif positions[i].y > get_viewport_rect().size.y:
			positions[i].y = get_viewport_rect().size.y
			velocities[i].y *= -1 * elasticity

func _update_densities() -> void:
	for i in range(particle_count):
		densities[i] = _calculate_density_at(i)
func _update_pressures() -> void:
	for i in range(particle_count):
		pressures[i] = _density_to_pressure(densities[i])

func _calculate_density_at(particle_index: int) -> float:
	var density = 0.0
	var pos: Vector2 = positions[particle_index]
	for i in _get_spatial_bucket_neighbours(pos):
		var distance = pos.distance_to(positions[i])
		if distance > smoothing_radius: # If other particle is outside of smoothing radius, it won't have any influence on this particle
			continue
		var influence = _smoothing_function(distance)
		density += influence * particle_mass
	return density
	
func _update_forces():
	for i in range(particle_count):
		var v = _calculate_viscocity_force_at(i)
		var p = _calculate_pressure_force_at(i)
		forces[i] = p + v
		if i == 0:
			print(v)
			print(p)
			print()
		
	
func _calculate_pressure_force_at(particle_index: int) -> Vector2:
	
	var pos: Vector2 = positions[particle_index]
	var pressure: float = pressures[particle_index]
	var pressure_force: Vector2 = Vector2.ZERO
	
	for i in _get_spatial_bucket_neighbours(pos):
		
		if particle_index == i: # Particle doesn't exert a force on itself
			continue
			
		var other_pos: Vector2 = positions[i]
		var distance = pos.distance_to(other_pos)
		if distance > smoothing_radius: # If other particle is outside of smoothing radius, it won't apply any force on this particle
			continue
		var magnitude = _smoothing_function_derivative(distance)
		# If distance is 0 (the two particles are on top of eachother), choose a random direction.
		var direction = Vector2(1, 0).rotated(randf_range(0.0, 2*PI)) if distance == 0 else (other_pos - pos) / distance
		var shared_pressure = (pressure + pressures[i]) / 2
		pressure_force += -1 * particle_mass * magnitude * shared_pressure * direction / densities[i]
	
	return pressure_force

func _calculate_viscocity_force_at(particle_index: int) -> Vector2:
	var viscocity_force: Vector2 = Vector2.ZERO
	var pos: Vector2 = positions[particle_index]
	
	for i in _get_spatial_bucket_neighbours(pos):
		var distance = pos.distance_to(positions[i])
		var influence = _smoothing_function(distance)
		viscocity_force += (velocities[i] - velocities[particle_index]) * influence

	return viscocity_force * viscocity

func _smoothing_function(dst: float) -> float:
	return max(0, pow(smoothing_radius - dst, 3)) / (PI * pow(smoothing_radius, 5) / 10) # Divide by this to normalize (integral will always be 1) because the total contribution of a single particle to the density should NOT depend on the smoothing radius
func _smoothing_function_derivative(dst: float) -> float:
	return 0.0 if dst > smoothing_radius else -3 * pow(smoothing_radius - dst, 2) / (PI * pow(smoothing_radius, 5) / 10) # Divide by this to normalize (integral will always be 1) because the total contribution of a single particle to the density should NOT depend on the smoothing radius
	
# The further we are from the target density, the faster the particle should move, and the more pressure should be applied to it.
func _density_to_pressure(density: float) -> float:
	return (density - target_density) * pressure_multiplier
	

#Particles:
	#Smoothing radius
	#Smoothing function
	# Normalizing the smoothing function:
	# Why do we normalize? Because the total contribution of a single particle to the density should NOT depend on the smoothing radius.
	# In other words, the integral of the smoothing function should be constant.
	# Plug into desmos 3D for a visualization of non-normalized (the last 2 lines are the normalized form). Move radius, the total contribution (which is the volume of the surface) changes with respect to R
	# R=1
	# r=R
	# z=\max\left(0,\ \left(R-r\right)^{3}\right)\left\{z>0\right\}
	# \int_{0}^{2\pi}\int_{0}^{R}\max\left(0,\ \left(R-r\right)^{3}\right)rdrd\theta
	# z=\frac{\max\left(0,\ \left(R-r\right)^{3}\right)}{\frac{\pi R^{5}}{10}}\left\{z>0\right\}
	# \int_{0}^{2\pi}\int_{0}^{R}\frac{\max\left(0,\ \left(R-r\right)^{3}\right)}{\frac{\pi R^{5}}{10}}rdrd\theta
	# We just need to divide by some mulitple of R^5 to normalize it. Here we divide by pi R^5 / 10 just to make it equal to 1
		#Need Derivative of smoothing function
	#The influence of each particle is determined by the smoothing function. Has 0 influence at distance > smoothing radius
