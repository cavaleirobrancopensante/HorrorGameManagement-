class_name Door
extends Node3D
## A hinged door. This node is the hinge; the panel hangs off it along +X.

var is_open := false
var closed_yaw := 0.0
var open_yaw := 90.0
var panel: Interactable
var _tween: Tween


static func create(width: float, height: float, material: Material, closed: float, opened: float) -> Door:
	var door := Door.new()
	door.closed_yaw = closed
	door.open_yaw = opened
	door.rotation_degrees.y = closed
	door.panel = Interactable.new()
	door.panel.id = "door"
	door.panel.set_meta("door", door)
	door.panel.position = Vector3(width / 2.0, height / 2.0, 0.0)
	door.add_child(door.panel)
	var size := Vector3(width - 0.02, height, 0.05)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	door.panel.add_child(shape)
	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh.mesh = box_mesh
	mesh.material_override = material
	door.panel.add_child(mesh)
	for side in [-1.0, 1.0]:
		var knob := MeshInstance3D.new()
		var knob_mesh := BoxMesh.new()
		knob_mesh.size = Vector3(0.1, 0.03, 0.04)
		knob.mesh = knob_mesh
		knob.material_override = TextureFactory.plain(Color("#b4a26a"), 0.4)
		knob.position = Vector3(width / 2.0 - 0.12, 1.0 - height / 2.0, side * 0.05)
		door.panel.add_child(knob)
	return door


func prompt() -> String:
	return "Close the door" if is_open else "Open the door"


func toggle() -> void:
	is_open = not is_open
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "rotation_degrees:y", open_yaw if is_open else closed_yaw, 0.45)
	Sound.play("door", 0.1)
