class_name SecurityCamera
extends Node3D
## A camera the computer can watch. It renders only while the feed is open.

var title := ""
var viewport: SubViewport
var _camera: Camera3D


static func create(camera_title: String, at: Vector3, target: Vector3) -> SecurityCamera:
	var unit := SecurityCamera.new()
	unit.title = camera_title
	unit.transform = Transform3D(Basis.looking_at(target - at, Vector3.UP), at)

	var housing := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.12, 0.1, 0.24)
	housing.mesh = box
	housing.position.z = 0.08
	housing.material_override = TextureFactory.plain(Color("#2a2a2e"))
	unit.add_child(housing)
	var led := MeshInstance3D.new()
	var dot := BoxMesh.new()
	dot.size = Vector3(0.02, 0.02, 0.01)
	led.mesh = dot
	led.position = Vector3(0.04, 0.035, -0.045)
	led.material_override = TextureFactory.glow(Color("#ff2a35"))
	unit.add_child(led)

	unit.viewport = SubViewport.new()
	unit.viewport.size = Vector2i(320, 180)
	unit.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	unit.add_child(unit.viewport)
	unit._camera = Camera3D.new()
	unit._camera.fov = 72.0
	unit._camera.near = 0.12
	unit._camera.far = 70.0
	unit._camera.cull_mask = TrailerWorld.LAYER_WORLD | TrailerWorld.LAYER_BODY | TrailerWorld.LAYER_CCTV_ONLY | TrailerWorld.LAYER_MIRROR
	unit._camera.transform = unit.transform
	unit.viewport.add_child(unit._camera)
	return unit


func set_live(on: bool) -> void:
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
