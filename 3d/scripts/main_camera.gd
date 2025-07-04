extends Camera3D
class_name MainCamera

@export var speed: float = 1000
@export var sensitivity: float = 0.002

@onready var viewports: Array[Node] = find_children("*", "SubViewport")
@onready var cameras: Array[Node] = find_children("*", "Camera3D")
@onready var parent_viewport: Viewport = get_viewport()
@onready var output_texture_rect: TextureRect = $OutputTextureRect
@onready var texture_rect1: TextureRect = $PostProcessing1/TextureRect
@onready var texture_rect2: TextureRect = $PostProcessing2/TextureRect

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	parent_viewport.size_changed.connect(_update_viewports)
	_update_viewports()

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
			rotation.x = clamp(rotation.x - event.relative.y * sensitivity, -PI/2, PI/2)
		
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
