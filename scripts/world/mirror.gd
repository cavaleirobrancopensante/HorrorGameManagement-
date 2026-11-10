class_name Mirror
extends Node3D
## A working mirror. A second camera sits at the viewer's eye reflected through
## the glass and looks back through the mirror's frame; its picture is shown
## flipped on the glass. The glass faces this node's +Z.

const PIXELS_PER_METRE := 260.0
const ACTIVE_DISTANCE := 2.4

var viewer: Camera3D
var width := 0.5
var height := 0.62
var _viewport: SubViewport
var _camera: Camera3D


func setup(glass_width: float, glass_height: float) -> void:
	width = glass_width
	height = glass_height
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(int(width * PIXELS_PER_METRE), int(height * PIXELS_PER_METRE))
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_FRUSTUM
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_camera.cull_mask = TrailerWorld.LAYER_WORLD | TrailerWorld.LAYER_BODY | TrailerWorld.LAYER_REFLECTION
	_viewport.add_child(_camera)

	var glass := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(width, height)
	glass.mesh = quad
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = _viewport.get_texture()
	material.albedo_color = Color(0.84, 0.88, 0.9)
	material.uv1_scale = Vector3(-1.0, 1.0, 1.0)
	material.uv1_offset = Vector3(1.0, 0.0, 0.0)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	glass.material_override = material
	glass.layers = TrailerWorld.LAYER_MIRROR
	add_child(glass)


func _process(_delta: float) -> void:
	if viewer == null or _camera == null:
		return
	var normal := global_basis.z.normalized()
	var center := global_position
	var eye := viewer.global_position
	var distance := (eye - center).dot(normal)
	var active := distance > 0.05 and eye.distance_to(center) < ACTIVE_DISTANCE
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
	if not active:
		return
	var reflected := eye - 2.0 * distance * normal
	var look := Basis.looking_at(normal, Vector3.UP)
	_camera.global_transform = Transform3D(look, reflected)
	var local := look.inverse() * (center - reflected)
	# The near plane sits exactly on the glass, so nothing behind the wall shows.
	_camera.set_frustum(height, Vector2(local.x, local.y), distance, 30.0)
