class_name PersonRig
extends Node3D
## A person from the people kit, animated in code. Faces -Z, feet at the
## origin.
##
## The models come in a T-pose with no animations, so the rig works out for
## itself, once per skeleton, which way each joint turns to lower an arm, swing
## a leg forward or bend an elbow: it tries small turns about each axis and
## keeps the one that moves the hand or foot the right way. Every outfit
## shares those answers, so one set of motions animates everyone.
##
## Each frame: legs and hips from walking (speed), arms from the held pose
## (hold_pose: rest, hold, reach, eat, pay, bat, pipe, pistol, slingshot, bag,
## hands_up) blended with a short action (act: swing, aim, bash, pay, eat,
## hurt). Falling is done by whoever owns the rig, by turning it.

## Metres per second at which the walk cycle runs at full stride.
const WALK_SPEED := 1.6

var skeleton: Skeleton3D
## Walking speed now, in metres per second. Set by the owner each frame.
var speed := 0.0
var hold_pose := "rest"
var _action := ""
var _action_time := 0.0
var _action_length := 0.0
var _phase := 0.0
var _breath := 0.0
var _bones := {}
var _rest := {}
## Calibrated turn axes, in each bone's local space: key -> Vector3.
var _axis := {}
## Shared by every rig with the same skeleton layout: sex -> {key: axis}.
static var _calibrations := {}
var sex := "man"


func setup(model_skeleton: Skeleton3D, model_sex: String) -> void:
	skeleton = model_skeleton
	sex = model_sex
	for name in ["Hips", "Abdomen", "Torso", "Chest", "Neck", "Head", "UpperArm.L", "LowerArm.L", "Hand.L", "UpperArm.R", "LowerArm.R", "Hand.R", "UpperLeg.L", "LowerLeg.L", "Foot.L", "UpperLeg.R", "LowerLeg.R", "Foot.R"]:
		var index := skeleton.find_bone(name)
		_bones[name] = index
		_rest[name] = skeleton.get_bone_pose_rotation(index)
	if _calibrations.has(sex):
		_axis = _calibrations[sex]
	else:
		_calibrate()
		_calibrations[sex] = _axis
	_apply(0.0)


func _world(bone: String) -> Vector3:
	return skeleton.global_transform * skeleton.get_bone_global_pose(_bones[bone]).origin


## In the rig's own frame: forward is -Z, up is +Y.
func _local(point: Vector3) -> Vector3:
	return global_transform.affine_inverse() * point


## Finds the axis of bone that best moves end along direction (rig frame).
func _find_axis(bone: String, end: String, direction: Vector3, angle := 0.35) -> Vector3:
	var index: int = _bones[bone]
	var base := skeleton.get_bone_pose_rotation(index)
	skeleton.force_update_all_bone_transforms()
	var start := _local(_world(end))
	var best := Vector3.RIGHT
	var best_gain := -INF
	for axis in [Vector3.RIGHT, Vector3.UP, Vector3.BACK, Vector3.LEFT, Vector3.DOWN, Vector3.FORWARD]:
		skeleton.set_bone_pose_rotation(index, base * Quaternion(axis, angle))
		skeleton.force_update_all_bone_transforms()
		var gain: float = (_local(_world(end)) - start).dot(direction)
		if gain > best_gain:
			best_gain = gain
			best = axis
	skeleton.set_bone_pose_rotation(index, base)
	skeleton.force_update_all_bone_transforms()
	return best


func _calibrate() -> void:
	# Arms down from the T-pose: the axis that drops the hand most, then how far.
	for side in ["L", "R"]:
		var upper: String = "UpperArm." + side
		_axis["down." + side] = _find_axis(upper, "Hand." + side, Vector3.DOWN)
		var index: int = _bones[upper]
		var best := 0.0
		var lowest := INF
		for step in range(30, 95, 5):
			skeleton.set_bone_pose_rotation(index, _rest[upper] * Quaternion(_axis["down." + side], deg_to_rad(step)))
			skeleton.force_update_all_bone_transforms()
			var y: float = _local(_world("Hand." + side)).y
			if y < lowest:
				lowest = y
				best = step
		_axis["down_angle." + side] = best
		skeleton.set_bone_pose_rotation(index, _rest[upper] * Quaternion(_axis["down." + side], deg_to_rad(best)))
		skeleton.force_update_all_bone_transforms()
		# With the arm down: swing forward, and bend the elbow forward.
		_axis["arm_fwd." + side] = _find_axis(upper, "Hand." + side, Vector3.FORWARD + Vector3.UP * 0.3)
		_axis["elbow." + side] = _find_axis("LowerArm." + side, "Hand." + side, Vector3.FORWARD + Vector3.UP)
		_axis["arm_out." + side] = _find_axis(upper, "Hand." + side, Vector3.RIGHT if side == "R" else Vector3.LEFT)
	for side in ["L", "R"]:
		_axis["leg_fwd." + side] = _find_axis("UpperLeg." + side, "Foot." + side, Vector3.FORWARD)
		_axis["knee." + side] = _find_axis("LowerLeg." + side, "Foot." + side, Vector3.BACK + Vector3.UP)
	_axis["lean"] = _find_axis("Torso", "Head", Vector3.FORWARD)
	_axis["twist"] = _find_axis("Torso", "UpperArm.R", Vector3.FORWARD)
	_axis["nod"] = _find_axis("Neck", "Head", Vector3.FORWARD)
	for name in _rest:
		skeleton.set_bone_pose_rotation(_bones[name], _rest[name])


func is_acting() -> bool:
	return _action != ""


## A short movement over the held pose.
func act(action: String, length := 0.5) -> void:
	_action = action
	_action_time = 0.0
	_action_length = length


func _process(delta: float) -> void:
	if skeleton == null:
		return
	_breath += delta
	if _action != "":
		_action_time += delta
		if _action_time >= _action_length:
			_action = ""
	var stride := clampf(speed / WALK_SPEED, 0.0, 1.4)
	_phase += delta * (2.0 + 4.5 * stride) * (1.0 if stride > 0.05 else 0.0)
	_apply(stride)


func _turn(bone: String, key: String, degrees: float) -> void:
	if not _axis.has(key):
		return
	var index: int = _bones[bone]
	skeleton.set_bone_pose_rotation(index, skeleton.get_bone_pose_rotation(index) * Quaternion(_axis[key], deg_to_rad(degrees)))


func _apply(stride: float) -> void:
	for name in _rest:
		skeleton.set_bone_pose_rotation(_bones[name], _rest[name])
	var swing := sin(_phase) * 28.0 * stride
	# Legs.
	_turn("UpperLeg.L", "leg_fwd.L", swing)
	_turn("UpperLeg.R", "leg_fwd.R", -swing)
	_turn("LowerLeg.L", "knee.L", maxf(0.0, -sin(_phase)) * 40.0 * stride)
	_turn("LowerLeg.R", "knee.R", maxf(0.0, sin(_phase)) * 40.0 * stride)
	# Breathing, and the bob of the walk.
	_turn("Chest", "lean", sin(_breath * 1.7) * 1.2)
	position.y = absf(sin(_phase)) * 0.03 * stride
	# Arms: down first, then the pose.
	for side in ["L", "R"]:
		_turn("UpperArm." + side, "down." + side, float(_axis.get("down_angle." + side, 70.0)))
	var arms := _arm_pose(hold_pose)
	if _action != "":
		var t := _action_time / maxf(_action_length, 0.01)
		var weight := sin(t * PI)
		var acting := _arm_pose(_action, t)
		for key in arms:
			arms[key] = lerpf(arms[key], acting.get(key, arms[key]), clampf(weight * 1.6, 0.0, 1.0)) if _action != "swing" else acting.get(key, arms[key])
		if _action == "hurt":
			_turn("Torso", "lean", -14.0 * weight)
			_turn("Neck", "nod", -10.0 * weight)
		if _action == "bash":
			_turn("Torso", "lean", 10.0 * weight)
	# Arms swing with the walk when they are free.
	if hold_pose == "rest" and _action == "":
		arms["fwd.L"] = arms["fwd.L"] - swing * 0.7
		arms["fwd.R"] = arms["fwd.R"] + swing * 0.7
	for side in ["L", "R"]:
		_turn("UpperArm." + side, "arm_fwd." + side, arms["fwd." + side])
		_turn("UpperArm." + side, "arm_out." + side, arms["out." + side])
		_turn("LowerArm." + side, "elbow." + side, arms["elbow." + side])


## Forward swing, outward lift and elbow bend for each arm, in degrees.
func _arm_pose(pose: String, t := 0.0) -> Dictionary:
	var arms := {"fwd.L": 0.0, "out.L": 4.0, "elbow.L": 8.0, "fwd.R": 0.0, "out.R": 4.0, "elbow.R": 8.0}
	match pose:
		"hold":
			arms["fwd.R"] = 35.0
			arms["elbow.R"] = 65.0
		"reach", "pay":
			arms["fwd.R"] = 75.0
			arms["elbow.R"] = 15.0
		"eat":
			arms["fwd.R"] = 55.0
			arms["elbow.R"] = 120.0
		"bag":
			arms["out.R"] = 8.0
		"bat", "pipe":
			arms["fwd.R"] = 25.0
			arms["elbow.R"] = 55.0
		"pistol":
			arms["fwd.R"] = 12.0
			arms["elbow.R"] = 20.0
		"slingshot", "aim":
			arms["fwd.R"] = 82.0
			arms["elbow.R"] = 4.0
			arms["fwd.L"] = 65.0
			arms["elbow.L"] = 30.0
		"swing":
			# Up over the shoulder, then down through the strike.
			var lift := 1.0 - t
			arms["fwd.R"] = lerpf(40.0, 150.0, lift) if t < 0.45 else lerpf(150.0, 20.0, (t - 0.45) / 0.55)
			arms["elbow.R"] = 40.0
		"bash":
			arms["fwd.R"] = 90.0
			arms["fwd.L"] = 90.0
			arms["elbow.R"] = 20.0
			arms["elbow.L"] = 20.0
		"hands_up":
			arms["fwd.R"] = 160.0
			arms["fwd.L"] = 160.0
		"hurt":
			arms["fwd.R"] = 30.0
			arms["fwd.L"] = 30.0
			arms["elbow.R"] = 60.0
			arms["elbow.L"] = 60.0
	return arms


## A bone to hang things on: the hands, the head, the hips, the chest.
func attach(bone: String, thing: Node3D) -> BoneAttachment3D:
	var attachment := BoneAttachment3D.new()
	attachment.bone_name = bone
	skeleton.add_child(attachment)
	# Props are made in metres in the rig's own frame (forward -Z, up +Y),
	# as the rig stands now; after that they follow the bone.
	var holder := Node3D.new()
	attachment.add_child(holder)
	skeleton.force_update_all_bone_transforms()
	var bone_world := skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(bone))
	var wanted := Transform3D(global_basis, bone_world.origin)
	holder.transform = bone_world.affine_inverse() * wanted
	holder.add_child(thing)
	return attachment


## Every mesh on one render layer: the world, or only the mirror and cameras.
func set_layers(layers: int) -> void:
	for node in find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).layers = layers
