extends Camera3D
class_name MainCamera

@export var speed: float = 1000
@export var sensitivity: float = 0.002

@onready var viewports: Array[Node] = find_children("*", "SubViewport")
@onready var cameras: Array[Node] = find_children("*", "Camera3D")
@onready var parent_viewport: Viewport = get_viewport()
@onready var output_texture_rect: TextureRect = $OutputTextureRect
@onready var texture_rect1: TextureRect = $HorizontalBlur/TextureRect
@onready var texture_rect2: TextureRect = $VerticalBlur/TextureRect
@onready var normal_mesh: MeshInstance3D = $NormalViewport/NormalCamera/NormalMesh
@onready var post_processing_mesh: MeshInstance3D = $PostProcessing/PostProcessingCamera/PostProcessingMesh

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	parent_viewport.size_changed.connect(_update_viewports)
	_update_viewports()
	
	for camera: Camera3D in cameras:
		camera.fov = fov
		camera.near = near
		camera.far = far
		
	var normal_material = normal_mesh.material_override as ShaderMaterial
	normal_material.set_shader_parameter("camera_near", near)
	normal_material.set_shader_parameter("camera_far", far)
	
	var post_processing_material = post_processing_mesh.material_override as ShaderMaterial
	post_processing_material.set_shader_parameter("camera_near", near)
	post_processing_material.set_shader_parameter("camera_far", far)
	post_processing_material.set_shader_parameter("sun_world_pos", $"../Sun".global_position)
	
func _update_viewports() -> void:
	for viewport: SubViewport in viewports:
		viewport.size = parent_viewport.size
	output_texture_rect.size = parent_viewport.size
	texture_rect1.size = parent_viewport.size
	texture_rect2.size = parent_viewport.size
	
func _input(event):
	
	if event is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			rotation.y -= event.relative.x * sensitivity
			rotation.x = clamp(rotation.x - event.relative.y * sensitivity, -PI/2 + 0.001, PI/2 - 0.001)
		
	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			
func _process(delta):
	
	var direction = Vector3.ZERO
	var forward = Vector3(transform.basis.z.x, 0, transform.basis.z.z).normalized() # Remove y component so WASD doesn't change y value
	var right = Vector3(transform.basis.x.x, 0, transform.basis.x.z).normalized() # Remove y component so WASD doesn't change y value
	if Input.is_action_pressed("w"):
		direction -= forward
	if Input.is_action_pressed("s"):
		direction += forward
	if Input.is_action_pressed("a"):
		direction -= right
	if Input.is_action_pressed("d"):
		direction += right
	if Input.is_action_pressed("space"):
		direction += Vector3.UP
	if Input.is_action_pressed("c"):
		direction -= Vector3.UP
	if direction.length() > 0:
		global_position += direction.normalized() * speed * delta
		
	for camera: Camera3D in cameras:
		camera.global_transform = global_transform
