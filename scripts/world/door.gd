class_name Door
extends Node3D
## A hinged door. This node is the hinge; the panel hangs off it along +X.

var is_open := false
var closed_yaw := 0.0
var open_yaw := 90.0
var panel: Interactable
## How much bashing it takes before it gives. Mended when you close it.
var health := 100.0
## Planks across the inside: the door takes far more before it gives.
var barricaded := false
const BARRICADE := 200.0
var _planks: Node3D
var _tween: Tween
var _thump := 0.0


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
	if barricaded and not is_open:
		return "The door is barricaded"
	return "Close the door" if is_open else "Open the door"


## Nails planks across the door, or takes them down. planks: built by the world.
func set_barricade(on: bool, planks: Node3D = null) -> void:
	if planks != null:
		_planks = planks
	barricaded = on
	if on:
		health = 100.0 + BARRICADE
	else:
		health = minf(health, 100.0)
	if _planks != null:
		_planks.visible = on


func toggle() -> void:
	if barricaded and not is_open:
		return
	is_open = not is_open
	if not is_open:
		health = 100.0
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "rotation_degrees:y", open_yaw if is_open else closed_yaw, 0.45)
	Sound.play("door", 0.1)


## Someone on the other side is breaking it down.
func bash(amount: float) -> void:
	if is_open:
		return
	health -= amount
	if barricaded and health <= 100.0:
		set_barricade(false)
		Sound.play("hit", 0.0, 2.0)
	_thump -= amount
	if _thump <= 0.0:
		_thump = 9.0
		Sound.play("knock", 0.15, 2.0)
		var shake := create_tween()
		shake.tween_property(self, "rotation_degrees:y", closed_yaw - 3.0, 0.05)
		shake.tween_property(self, "rotation_degrees:y", closed_yaw, 0.08)
	if health <= 0.0:
		health = 0.0
		Sound.play("door", 0.0, 4.0)
		toggle()
