class_name Surface
extends Interactable
## A food surface: the grill, the serving counter, the prep board. You can put
## things down anywhere, but these are where food belongs. They get dirty with
## use and show it; food set down on a filthy one is refused. Wipe them with
## cleaning spray.

const DIRTY := 0.6
## Pick-up boxes and surfaces sit on their own physics layer, so the player
## walks through them but still looks at them.
const PICK_LAYER := 2

## "grill" or "prep".
var kind := "prep"
var label := ""
## Shared by the parts of one counter, and the key in the save.
var key := ""
var top := 0.0
var low := Vector2.ZERO
var high := Vector2.ZERO
var _stains: Node3D
var _shown := -1


static func create(new_key: String, new_label: String, new_kind: String, x0: float, x1: float, z0: float, z1: float, surface_top: float) -> Surface:
	var surface := Surface.new()
	surface.id = "surface"
	surface.key = new_key
	surface.label = new_label
	surface.kind = new_kind
	surface.top = surface_top
	surface.low = Vector2(x0, z0)
	surface.high = Vector2(x1, z1)
	surface.collision_layer = PICK_LAYER
	surface.position = Vector3((x0 + x1) / 2.0, surface_top + 0.004, (z0 + z1) / 2.0)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(x1 - x0, 0.02, z1 - z0)
	shape.shape = box
	surface.add_child(shape)
	surface._stains = Node3D.new()
	surface.add_child(surface._stains)
	return surface


## Where an item lands when put down at point: on top, inside the edges.
func landing(point: Vector3) -> Vector3:
	return Vector3(clampf(point.x, low.x + 0.06, high.x - 0.06), top, clampf(point.z, low.y + 0.05, high.y - 0.05))


func contains(point: Vector3) -> bool:
	return point.x >= low.x and point.x <= high.x and point.z >= low.y and point.z <= high.y and absf(point.y - top) < 0.08


## Grease spots that grow with the dirt.
func show_dirt(dirt: float) -> void:
	var count := clampi(floori(dirt * 6.0), 0, 6)
	if count == _shown:
		return
	_shown = count
	for child in _stains.get_children():
		child.queue_free()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key) + int(low.x * 100.0)
	var colour := Color("#3a2a14", 0.85) if kind == "prep" else Color("#0a0806")
	for i in 6:
		var size := Vector2(rng.randf_range(0.05, 0.12), rng.randf_range(0.04, 0.09))
		var spot := Vector3(rng.randf_range(low.x + 0.05, high.x - 0.05), top + 0.002, rng.randf_range(low.y + 0.04, high.y - 0.04))
		if i >= count:
			continue
		var mesh := MeshInstance3D.new()
		var shape := BoxMesh.new()
		shape.size = Vector3(size.x, 0.002, size.y)
		mesh.mesh = shape
		mesh.material_override = TextureFactory.plain(colour, 0.9)
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_stains.add_child(mesh)
		mesh.global_position = spot
