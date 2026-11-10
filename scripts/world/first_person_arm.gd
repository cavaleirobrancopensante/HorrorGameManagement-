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
	return REST if holding else LOWERED


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
	visible = holding
	position = (REST if holding else LOWERED) + _sway
	rotation_degrees = REST_TURN


## A little movement with each step while walking.
func sway(bob: float, amount: float) -> void:
	_sway = Vector3(sin(bob * 0.5) * 0.012, -absf(sin(bob)) * 0.014, 0.0) * amount
	if holding and not _busy:
		position = REST + _sway


## The pose for the body sprite: "reach", "eat", "hold" or "rest".
func pose() -> String:
	if not action.is_empty():
		return action
	return "hold" if holding else "rest"
