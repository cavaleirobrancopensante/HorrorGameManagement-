class_name FirstPersonArm
extends Node3D
## Your own right arm, seen in first person. It holds what you carry on its palm,
## reaches out when you use something, and brings food to your mouth.
## Only your own camera sees it: mirrors and security cameras show your whole body.

const REST := Vector3(0.27, -0.33, -0.1)
const REST_TURN := Vector3(10.0, 10.0, -4.0)
## Where the arm waits, out of sight, when your hand is empty.
const LOWERED := Vector3(0.3, -0.62, 0.02)
const REACH_POSE := Vector3(0.12, -0.2, -0.3)
const REACH_TURN := Vector3(18.0, 2.0, -8.0)
const MOUTH_POSE := Vector3(0.06, -0.18, 0.06)
const MOUTH_TURN := Vector3(38.0, 24.0, -10.0)

## Where held items sit, on the palm.
var palm: Node3D
## True while you carry something: the arm stays up.
var holding := false:
	set(value):
		holding = value
		if not _busy:
			_settle()

var _busy := false
## What the arm is doing right now: "", "reach" or "eat". The body sprite in
## mirrors and on the cameras copies it.
var action := ""
var _sway := Vector3.ZERO
var _tween: Tween
var _materials: Array[StandardMaterial3D] = []
## The weapon in your hand: "", "bat" or "slingshot".
var weapon := ""
var _weapon_model: Node3D

const SWING_UP := Vector3(0.32, -0.12, -0.05)
const SWING_UP_TURN := Vector3(30.0, -30.0, 50.0)
const SWING_DOWN := Vector3(-0.1, -0.35, -0.35)
const SWING_DOWN_TURN := Vector3(-40.0, 40.0, -30.0)
const AIM := Vector3(0.05, -0.2, -0.25)
const AIM_TURN := Vector3(4.0, 2.0, 0.0)


func _init() -> void:
	position = LOWERED
	rotation_degrees = REST_TURN
	visible = false
	var sleeve := _mat(Color("#4b4a55"))
	var cuff := _mat(Color("#3b3a44"))
	var skin := _mat(Color("#c79a6e"))
	_part(Vector3(0.1, 0.1, 0.32), Vector3(0.0, 0.0, -0.1), sleeve)
	_part(Vector3(0.106, 0.106, 0.035), Vector3(0.0, 0.0, -0.255), cuff)
	_part(Vector3(0.07, 0.06, 0.05), Vector3(0.0, 0.0, -0.29), skin)
	_part(Vector3(0.092, 0.03, 0.095), Vector3(0.0, 0.004, -0.34), skin)
	for i in 4:
		var finger := _part(Vector3(0.019, 0.022, 0.065), Vector3(-0.031 + i * 0.0205, 0.012, -0.41), skin)
		finger.rotation_degrees.x = 18.0 + i * 3.0
	var thumb := _part(Vector3(0.022, 0.024, 0.055), Vector3(-0.055, 0.012, -0.325), skin)
	thumb.rotation_degrees = Vector3(10.0, 38.0, 0.0)
	palm = Node3D.new()
	palm.position = Vector3(0.0, 0.02, -0.355)
	add_child(palm)


## Your skin tone, and the sleeve of the shirt under your apron.
func dress(skin_colour: Color, sleeve_colour: Color) -> void:
	_materials[2].albedo_color = skin_colour
	_materials[0].albedo_color = sleeve_colour
	_materials[1].albedo_color = sleeve_colour.darkened(0.2)


func _mat(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.9
	_materials.append(material)
	return material


func _part(size: Vector3, at: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = at
	mesh.material_override = material
	mesh.layers = TrailerWorld.LAYER_VIEWMODEL
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)
	return mesh


## The hand goes out to whatever you are using, then back.
func reach() -> void:
	action = "reach"
	_play([[REACH_POSE, REACH_TURN, 0.13], [_rest_pose(), REST_TURN, 0.2]], Callable())


## The hand brings what it holds to your mouth. `then` runs at the top.
func to_mouth(then: Callable) -> void:
	action = "eat"
	_play([[MOUTH_POSE, MOUTH_TURN, 0.22], [MOUTH_POSE, MOUTH_TURN, 0.12]], then, [REST, REST_TURN, 0.25])


func _rest_pose() -> Vector3:
	if weapon == "slingshot":
		return AIM
	return REST if holding or weapon != "" else LOWERED


## Takes a weapon in hand, or puts it away ("").
func set_weapon(id: String) -> void:
	weapon = id
	if _weapon_model != null:
		_weapon_model.queue_free()
		_weapon_model = null
	if id != "":
		_weapon_model = _bat() if id == "bat" else _slingshot()
		palm.add_child(_weapon_model)
	if _tween:
		_tween.kill()
	_busy = false
	_settle()


func swing(then: Callable) -> void:
	action = "swing"
	_play([[SWING_UP, SWING_UP_TURN, 0.12], [SWING_DOWN, SWING_DOWN_TURN, 0.1]], then, [REST, REST_TURN, 0.25])


func shoot(then: Callable) -> void:
	action = "shoot"
	_play([[AIM + Vector3(0.0, 0.0, 0.08), AIM_TURN, 0.12], [AIM - Vector3(0.0, 0.0, 0.04), AIM_TURN, 0.05]], then, [AIM, AIM_TURN, 0.2])


func _bat() -> Node3D:
	var bat := Node3D.new()
	var wood := _mat(Color("#8a5a32"))
	var grip := _mat(Color("#1e1b1a"))
	var handle := _piece(CylinderMesh.new(), 0.018, 0.018, 0.22, grip)
	handle.position = Vector3(0.0, 0.05, 0.0)
	bat.add_child(handle)
	var barrel := _piece(CylinderMesh.new(), 0.04, 0.022, 0.5, wood)
	barrel.position = Vector3(0.0, 0.41, 0.0)
	bat.add_child(barrel)
	bat.rotation_degrees = Vector3(-60.0, 0.0, 0.0)
	return bat


func _slingshot() -> Node3D:
	var sling := Node3D.new()
	var wood := _mat(Color("#6b4426"))
	var band := _mat(Color("#7a2a22"))
	var handle := _piece(CylinderMesh.new(), 0.014, 0.016, 0.12, wood)
	handle.position = Vector3(0.0, 0.0, 0.0)
	sling.add_child(handle)
	for side in [-1.0, 1.0]:
		var fork := _piece(CylinderMesh.new(), 0.011, 0.012, 0.09, wood)
		fork.position = Vector3(side * 0.03, 0.09, 0.0)
		fork.rotation_degrees.z = -side * 20.0
		sling.add_child(fork)
		var rubber := _piece(BoxMesh.new(), 0.006, 0.006, 0.09, band)
		rubber.position = Vector3(side * 0.025, 0.13, 0.045)
		rubber.rotation_degrees.x = 90.0
		sling.add_child(rubber)
	sling.position = Vector3(0.0, 0.03, -0.03)
	return sling


func _piece(mesh: PrimitiveMesh, a: float, b: float, length: float, material: StandardMaterial3D) -> MeshInstance3D:
	if mesh is CylinderMesh:
		(mesh as CylinderMesh).top_radius = a
		(mesh as CylinderMesh).bottom_radius = b
		(mesh as CylinderMesh).height = length
		(mesh as CylinderMesh).radial_segments = 8
	elif mesh is BoxMesh:
		(mesh as BoxMesh).size = Vector3(a, length, b)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.layers = TrailerWorld.LAYER_VIEWMODEL
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


func _play(steps: Array, then: Callable, after: Array = []) -> void:
	if _tween:
		_tween.kill()
	_busy = true
	visible = true
	if not holding and position.distance_to(LOWERED) < 0.01:
		position = LOWERED
	_tween = create_tween()
	for step: Array in steps:
		_tween.tween_property(self, "position", step[0], step[2]).set_trans(Tween.TRANS_SINE)
		_tween.parallel().tween_property(self, "rotation_degrees", step[1], step[2]).set_trans(Tween.TRANS_SINE)
	if then.is_valid():
		_tween.tween_callback(then)
	if not after.is_empty():
		_tween.tween_property(self, "position", _rest_pose() if not holding else after[0], after[2])
		_tween.parallel().tween_property(self, "rotation_degrees", after[1], after[2])
	_tween.tween_callback(func() -> void:
		_busy = false
		action = ""
		_settle()
	)


func _settle() -> void:
	if _tween and _tween.is_running() and _busy:
		return
	visible = holding or weapon != ""
	position = _rest_pose() + _sway
	rotation_degrees = AIM_TURN if weapon == "slingshot" else REST_TURN


## A little movement with each step while walking.
func sway(bob: float, amount: float) -> void:
	_sway = Vector3(sin(bob * 0.5) * 0.012, -absf(sin(bob)) * 0.014, 0.0) * amount
	if (holding or weapon != "") and not _busy:
		position = _rest_pose() + _sway


## The pose for the body sprite: "reach", "eat", "hold" or "rest".
func pose() -> String:
	if not action.is_empty():
		return action
	if weapon != "":
		return weapon
	return "hold" if holding else "rest"
