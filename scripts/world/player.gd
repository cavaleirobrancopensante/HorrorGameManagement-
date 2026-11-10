class_name Player
extends CharacterBody3D
## First-person body. Movement comes from the keyboard or the touch stick, looking
## from the mouse or a finger. The body sprite is seen only in mirrors and on
## the security cameras.

signal focus_changed(target: Interactable)
signal stepped

const SPEED := 2.6
const EYE_HEIGHT := 1.55
const GRAVITY := 12.0
const REACH := 2.4
const BODY_PIXEL_SIZE := 0.0056

var camera: Camera3D
var flashlight: SpotLight3D
var body_sprite: Sprite3D
## Your arm, and the palm where held items sit.
var arm: FirstPersonArm
var hand: Node3D
var move_input := Vector2.ZERO
var controls_enabled := true
var focused: Interactable = null
var _pitch := 0.0
var _bob := 0.0
var _step := 0.0


func _init() -> void:
	floor_max_angle = deg_to_rad(46.0)
	floor_snap_length = 0.35
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = 1.75
	shape.shape = capsule
	shape.position.y = 0.875
	add_child(shape)

	camera = Camera3D.new()
	camera.position.y = EYE_HEIGHT
	camera.fov = 75.0
	camera.near = 0.05
	camera.far = 90.0
	camera.cull_mask = 0xFFFFF & ~(TrailerWorld.LAYER_BODY | TrailerWorld.LAYER_CCTV_ONLY)
	add_child(camera)

	arm = FirstPersonArm.new()
	camera.add_child(arm)
	hand = arm.palm

	flashlight = SpotLight3D.new()
	flashlight.spot_range = 14.0
	flashlight.spot_angle = 26.0
	flashlight.light_energy = 2.2
	flashlight.light_color = Color("#fff1d6")
	flashlight.position = Vector3(0.15, -0.15, 0.0)
	flashlight.visible = false
	camera.add_child(flashlight)

	body_sprite = Sprite3D.new()
	body_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	body_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	body_sprite.shaded = true
	body_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	body_sprite.pixel_size = BODY_PIXEL_SIZE
	body_sprite.layers = TrailerWorld.LAYER_BODY
	body_sprite.position.y = 320.0 * BODY_PIXEL_SIZE / 2.0
	add_child(body_sprite)


func look(amount: Vector2) -> void:
	rotate_y(-amount.x)
	_pitch = clampf(_pitch - amount.y, deg_to_rad(-85.0), deg_to_rad(85.0))
	camera.rotation.x = _pitch


func set_pitch(radians: float) -> void:
	_pitch = radians
	camera.rotation.x = radians


func _physics_process(delta: float) -> void:
	var input := Vector2.ZERO
	if controls_enabled:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		if move_input.length() > input.length():
			input = move_input
	var direction := global_basis * Vector3(input.x, 0.0, input.y)
	direction.y = 0.0
	direction = direction.limit_length(1.0)
	velocity.x = direction.x * SPEED
	velocity.z = direction.z * SPEED
	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()

	var speed := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and speed > 0.3:
		_bob += delta * 9.0
		_step += speed * delta
		if _step > 0.75:
			_step = 0.0
			stepped.emit()
	camera.position.y = EYE_HEIGHT + sin(_bob) * 0.025 * minf(speed / SPEED, 1.0)
	arm.sway(_bob, minf(speed / SPEED, 1.0))
	_update_focus()


func _update_focus() -> void:
	var target: Interactable = null
	if controls_enabled:
		var from := camera.global_position
		var query := PhysicsRayQueryParameters3D.create(from, from - camera.global_basis.z * REACH)
		query.exclude = [get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		var collider: Object = hit.get("collider")
		if collider is Interactable:
			target = collider
	if target != focused:
		focused = target
		focus_changed.emit(target)
