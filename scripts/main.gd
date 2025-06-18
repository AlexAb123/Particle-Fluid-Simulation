extends Node2D

@export var particle_count: int = 225
@export var smoothing_radius: int = 100
@export var particle_mass: float = 1
@export var pressure_multiplier: float = 500
@export var target_density: float = 3
@export var gravity: float = 1
@export_range(0, 1) var elasticity: float = 0.95

var positions: Array[Vector2] = []
var velocities: Array[Vector2] = []
var densities: Array[float] = []
var pressures: Array[float] = []
var pressure_forces: Array[Vector2] = []

func _ready():
	for i in range(particle_count):
		positions.append(Vector2(randf() * get_viewport_rect().size.x, randf() * get_viewport_rect().size.y))
		velocities.append(Vector2(0,0))
		densities.append(0.0)
		pressures.append(0.0)
		pressure_forces.append(Vector2(0,0))

func _process(delta: float) -> void:
	_update_densities(positions)
	_update_pressures(densities)
	_update_pressure_forces(positions, densities, pressures)
	_update_velocities(pressure_forces, delta)
	_update_positions(velocities, delta)
	queue_redraw()
	
func _draw():
	for i in range(particle_count):
		var pos = positions[i]

		draw_circle(pos, 3, Color.CYAN)
		
	draw_circle(Vector2(get_viewport_rect().size.x/2, get_viewport_rect().size.y/2), smoothing_radius, Color.BLACK, false)

func _get_spatial_key(pos: Vector2) -> Vector2:
	return Vector2(floor(pos.x), floor(pos.y))

func _update_velocities(pressure_forces: Array[Vector2], delta: float) -> void:
	for i in range(particle_count):
		velocities[i] += pressure_forces[i] / particle_mass * delta
		velocities[i] += Vector2(0, gravity) * delta

func _update_positions(velocities: Array[Vector2], delta: float):
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

func _update_densities(positions: Array[Vector2]) -> void:
	for i in range(particle_count):
		densities[i] = _calculate_density_at(i, positions)
		
func _update_pressures(densities: Array[float]) -> void:
	for i in range(particle_count):
		pressures[i] = _density_to_pressure(densities[i])

func _calculate_density_at(particle_index: int, positions: Array[Vector2]) -> float:
	var density = 0.0
	var pos: Vector2 = positions[particle_index]
	for i in range(particle_count):
		var distance = pos.distance_to(positions[i])
		if distance > smoothing_radius: # If other particle is outside of smoothing radius, it won't have any influence on this particle
			continue
		var influence = _smoothing_function(distance)
		density += influence * particle_mass
	return density
	
func _update_pressure_forces(positions: Array[Vector2], densities: Array[float], pressures: Array[float]):
	for i in range(particle_count):
		pressure_forces[i] = _calculate_pressure_force_at(i, positions, densities, pressures)
	
func _calculate_pressure_force_at(particle_index: int, positions: Array[Vector2], densities: Array[float], pressures: Array[float]) -> Vector2:
	
	var pos: Vector2 = positions[particle_index]
	var pressure: float = pressures[particle_index]
	var pressure_force: Vector2 = Vector2.ZERO
	
	for i in range(particle_count):
		
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


func _smoothing_function(dst: float) -> float:
	return max(0, pow(smoothing_radius - dst, 3)) / (PI * pow(smoothing_radius, 5) / 10) # Divide by this to normalize (integral will always be 1) because the total contribution of a single particle to the density should NOT depend on the smoothing radius
func _smoothing_function_derivative(dst: float) -> float:
	return 0 if dst > smoothing_radius else -3 * pow(smoothing_radius - dst, 2) / (PI * pow(smoothing_radius, 5) / 10) # Divide by this to normalize (integral will always be 1) because the total contribution of a single particle to the density should NOT depend on the smoothing radius
	
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
