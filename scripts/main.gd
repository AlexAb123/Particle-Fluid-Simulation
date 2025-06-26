extends Node2D

@export var particle_count: int = 225
@export var smoothing_radius: int = 50
@export var particle_mass: float = 1
@export var pressure_multiplier: float = 500
@export var target_density: float = 3
@export var gravity: float = 0
@export_range(0, 1) var elasticity: float = 0.95
@export var viscocity: float = 50
@export var steps_per_frame: int = 1

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
		#positions.append(Vector2(randf() * width, randf() * height))
		positions.append(Vector2(randf() * width/4 + width/2 - width/8, randf() * height/4 + height/2 - height/8))
		velocities.append(Vector2(0,0))
		densities.append(0.0)
		pressures.append(0.0)
		forces.append(Vector2(0,0))

func _process(delta: float) -> void:
	
	fps_counter.text = str(int(Engine.get_frames_per_second())) + " fps"
	
	for i in range(steps_per_frame):
		_simulate_step(delta)

	
	queue_redraw()
	#var total = 0
	#for d in densities:
		#total += d
	#print("Total Density: " + str(total))
	#
	#print("Density: " + str(densities[0]))
	#print("Density Error: " + str(densities[0] - target_density))
	#print("Pressure: " + str(pressures[0]))
	
	
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
		draw_circle(pos, 3, gradient.sample(velocities[i].length()/250))
 
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
		velocities[i] += forces[i] / densities[i] * delta
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
		var influence = _density_kernel(distance)
		density += influence * particle_mass
	return density
	
func _update_forces():
	for i in range(particle_count):
		forces[i] = _calculate_forces_at(i)

func _calculate_forces_at(particle_index: int) -> Vector2:
	var pos: Vector2 = positions[particle_index]
	var pressure: float = pressures[particle_index]
	var pressure_force: Vector2 = Vector2.ZERO
	var viscocity_force: Vector2 = Vector2.ZERO
	for i in _get_spatial_bucket_neighbours(pos):
		if particle_index == i: # Particle doesn't exert a force on itself
				continue
		var other_pos: Vector2 = positions[i]
		var distance = pos.distance_to(other_pos)
		if distance > smoothing_radius: # If other particle is outside of smoothing radius, it won't apply any force on this particle
			continue
			
		var magnitude = _density_kernel_derivative(distance)
		var direction = Vector2(1, 0).rotated(randf_range(0.0, 2*PI)) if distance == 0 else (other_pos - pos) / distance
		var shared_pressure = (pressure + pressures[i]) / 2
		pressure_force += particle_mass / densities[i] * magnitude * shared_pressure * direction
		
		var influence = _density_kernel(distance)
		viscocity_force += viscocity * (velocities[i] - velocities[particle_index]) * influence / densities[i]
	
	return pressure_force + viscocity_force
	
func _density_kernel(dst: float) -> float:
	if dst >= smoothing_radius:
		return 0
	var factor = pow(smoothing_radius, 3) * PI / 1.5
	return pow(smoothing_radius - dst, 2) / factor
func _density_kernel_derivative(dst: float) -> float:
	if dst >= smoothing_radius:
		return 0
	var factor = pow(smoothing_radius, 3) * PI / 1.5
	return -2 * (smoothing_radius - dst) / factor
	
# The further we are from the target density, the faster the particle should move, and the more pressure should be applied to it.
func _density_to_pressure(density: float) -> float:
	return max(0, (density - target_density) * pressure_multiplier) # Clamp to 0 so there aren't any attractive forces (attractive forces don't really play well and look odd)
