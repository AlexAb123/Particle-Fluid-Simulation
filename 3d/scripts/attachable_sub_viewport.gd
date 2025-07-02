@tool

extends SubViewport
class_name AttachableSubViewport

@export var camera: Camera3D:
	get():
		return camera
	set(value):
		camera = value
		RenderingServer.viewport_attach_camera(get_viewport_rid(), camera.get_camera_rid())
