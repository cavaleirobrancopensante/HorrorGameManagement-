class_name Enemy
extends CharacterBody3D
## Someone, or something, that wants to hurt you.
##
## Thugs walk to the trailer door, bash it until it gives, and come in after
## you. Inside they follow the corridor line through the doorways. A burglar
## is a thug already inside. Drones fly: they hover at whatever opening is
## open (the hatch, the window, the door) and zap you through it, and come in
## if the door is open. Closed shutters and a shut hatch keep them out.

signal down(enemy: Enemy)

## Physics layer for enemies, apart from the world (1) and pick boxes (2).
const LAYER := 4
## The corridor line through every doorway inside the trailer.
const CORRIDOR_Z := 1.5
const DOOR_OUTSIDE := Vector3(4.85, TrailerWorld.GROUND, 4.4)
const DOOR_INSIDE := Vector3(4.85, 0.0, 2.4)

var kind := "thug"
var stats: Dictionary
var health := 60.0
var game: TrailerGame
var figure: Node3D
var is_down := false
var _cooldown := 1.0
var _hover := 0.0
var _gave_up := 0.0
var _stuck := 0.0


static func create(owner_game: TrailerGame, enemy_kind: String) -> Enemy:
	var enemy := Enemy.new()
	enemy.game = owner_game
	enemy.kind = enemy_kind
	enemy.stats = Combat.ENEMIES[enemy_kind]
	enemy.health = enemy.stats["health"]
	enemy.collision_layer = LAYER
	enemy.collision_mask = 1
	var shape := CollisionShape3D.new()
	if enemy_kind == "drone":
		enemy.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
		var box := BoxShape3D.new()
		box.size = Vector3(0.5, 0.18, 0.5)
		shape.shape = box
		enemy.figure = _drone_body()
	else:
		enemy.floor_max_angle = deg_to_rad(46.0)
		enemy.floor_snap_length = 0.35
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.28
		capsule.height = 1.7
		shape.shape = capsule
		shape.position.y = 0.85
		var shirt: String = "#1c1d22" if enemy_kind == "burglar" else ("#4a2a22" if enemy_kind == "shooter" else ["#2a2d36", "#3b2a26", "#26332b"].pick_random())
		enemy.figure = owner_game.world.church._person(shirt, false)
		enemy.figure.get_parent().remove_child(enemy.figure)
	enemy.add_child(shape)
	enemy.add_child(enemy.figure)
	enemy.add_to_group("enemies")
	return enemy


static func _drone_body() -> Node3D:
	var drone := Node3D.new()
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.45, 0.1, 0.45)
	body.mesh = box
	body.material_override = TextureFactory.plain(Color("#2a2c31"), 0.4)
	drone.add_child(body)
	for corner in [Vector3(-0.28, 0.06, -0.28), Vector3(0.28, 0.06, -0.28), Vector3(-0.28, 0.06, 0.28), Vector3(0.28, 0.06, 0.28)]:
		var rotor := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = 0.13
		disc.bottom_radius = 0.13
		disc.height = 0.01
		rotor.mesh = disc
		rotor.material_override = TextureFactory.plain(Color("#55585f"), 0.5)
		rotor.position = corner
		drone.add_child(rotor)
	var eye := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.05
	sphere.height = 0.1
	eye.mesh = sphere
	eye.material_override = TextureFactory.glow(Color("#ff2a2a"))
	eye.position = Vector3(0.0, -0.06, -0.2)
	drone.add_child(eye)
	var light := OmniLight3D.new()
	light.light_color = Color("#ff2a2a")
	light.light_energy = 0.7
	light.omni_range = 2.2
	light.position = Vector3(0.0, -0.1, -0.3)
	drone.add_child(light)
	return drone


static func inside(point: Vector3) -> bool:
	return point.x > 0.0 and point.x < TrailerWorld.LENGTH and point.z > 0.0 and point.z < TrailerWorld.WIDTH and point.y > -0.2


func _physics_process(delta: float) -> void:
	if is_down or game == null or game.save.is_empty():
		return
	_cooldown -= delta
	var target := _target()
	if kind == "drone":
		_fly(target, delta)
	else:
		_walk(target, delta)
	_try_attack()


## Where to go next, given where you are and where the player is.
func _target() -> Vector3:
	var me := global_position
	var you := game.player.global_position
	var you_in := inside(you)
	var me_in := inside(me)
	if kind == "drone" and not me_in and you_in:
		return _opening_for(you)
	if kind == "shooter" and not me_in and you_in:
		if _sees_player():
			return me
		var opening := _opening_for(you, false)
		if opening != Vector3.INF:
			return Vector3(opening.x, TrailerWorld.GROUND, opening.z + 3.0)
	if not me_in and you_in:
		# To the door; once lined up with it and it is open, straight in.
		var lined_up := absf(me.x - DOOR_OUTSIDE.x) < 0.35 and me.z < DOOR_OUTSIDE.z + 0.3
		if lined_up and game.world.entrance.is_open:
			return DOOR_INSIDE
		return DOOR_OUTSIDE
	if me_in and not you_in:
		if me.z < DOOR_INSIDE.z - 0.3:
			return DOOR_INSIDE
		return DOOR_OUTSIDE
	if me_in and you_in and not _clear_to(you):
		# Along the corridor line, through the doorways.
		if absf(me.z - CORRIDOR_Z) > 0.25:
			return Vector3(me.x, me.y, CORRIDOR_Z)
		return Vector3(you.x, me.y, CORRIDOR_Z)
	return you


## The nearest open way in or way to see in: hatch, window or door. With
## everything shut, a drone rams the nearest of the window shutter and the
## door; a shooter (flying false) gets Vector3.INF and comes to the door.
func _opening_for(you: Vector3, flying := true) -> Vector3:
	var world := game.world
	var options: Array = []
	if bool(game.save["world"]["hatch_open"]):
		options.append(Vector3(1.75, TrailerWorld.GROUND + 1.85, TrailerWorld.WIDTH + 0.9))
	if not bool(game.save["world"]["shutters_closed"]):
		options.append(Vector3(8.3, TrailerWorld.GROUND + 1.85, TrailerWorld.WIDTH + 0.9))
	if world.entrance.is_open:
		options.append(Vector3(4.85, TrailerWorld.GROUND + 1.8, TrailerWorld.WIDTH + 0.9))
	if options.is_empty():
		if not flying:
			return Vector3.INF
		# Everything shut: break in through the shutter or the door.
		var window := Vector3(8.3, TrailerWorld.GROUND + 1.85, TrailerWorld.WIDTH + 0.35)
		var door := Vector3(4.85, TrailerWorld.GROUND + 1.8, TrailerWorld.WIDTH + 0.35)
		var ram := window if global_position.distance_to(window) < global_position.distance_to(door) else door
		if global_position.distance_to(ram) < 0.5:
			_ram(ram == window)
		return ram
	options.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.distance_to(you) < b.distance_to(you))
	if world.entrance.is_open and options[0].x == 4.85 and global_position.distance_to(options[0]) < 0.6:
		return DOOR_INSIDE + Vector3(0.0, 1.5, 0.0)
	return options[0]


func gave_up() -> bool:
	return _gave_up > 60.0


func _ram(window: bool) -> void:
	var amount := get_physics_process_delta_time() * 9.0
	if window:
		game.world.bash_shutter(amount, game)
	else:
		game.world.entrance.bash(amount)


func _sees_player() -> bool:
	var camera := game.player.camera.global_position
	if _eye().distance_to(camera) > float(stats["reach"]):
		return false
	var query := PhysicsRayQueryParameters3D.create(_eye(), camera)
	query.collision_mask = 1
	query.exclude = [get_rid(), game.player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _clear_to(point: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3(0.0, 1.2, 0.0), point + Vector3(0.0, 1.2, 0.0))
	query.collision_mask = 1
	query.exclude = [get_rid()]
	return space.intersect_ray(query).is_empty()


func _walk(target: Vector3, delta: float) -> void:
	var flat := Vector3(target.x - global_position.x, 0.0, target.z - global_position.z)
	var speed: float = stats["speed"]
	# Bash the door if it is in the way.
	var door: Door = game.world.entrance
	if not inside(global_position) and not door.is_open and global_position.distance_to(DOOR_OUTSIDE) < 0.9 and inside(game.player.global_position):
		flat = Vector3.ZERO
		door.bash(delta * 7.0)
	if target == global_position:
		flat = Vector3.ZERO
		look_at(Vector3(game.player.global_position.x, global_position.y, game.player.global_position.z), Vector3.UP)
	if flat.length() > 0.9 or (flat.length() > 0.1 and target != game.player.global_position):
		velocity.x = flat.normalized().x * speed
		velocity.z = flat.normalized().z * speed
		look_at(Vector3(target.x, global_position.y, target.z), Vector3.UP)
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)
	if not is_on_floor():
		velocity.y -= 12.0 * delta
	else:
		velocity.y = maxf(velocity.y, 0.0)
	# Inside doors are not locked: open any closed one you walk into.
	for inner in game.world.inner_doors:
		if not inner.is_open and inner.panel.global_position.distance_to(global_position + Vector3(0.0, 1.0, 0.0)) < 1.0:
			inner.toggle()
	var before := global_position
	move_and_slide()
	# Over a lip or a step: a little hop when walking gets nowhere.
	var wanted := Vector2(velocity.x, velocity.z).length()
	var moved := Vector2(global_position.x - before.x, global_position.z - before.z).length()
	if is_on_floor() and wanted > 0.5 and moved < wanted * delta * 0.25:
		_stuck += delta
		if _stuck > 0.25:
			_stuck = 0.0
			velocity.y = 3.2
	else:
		_stuck = 0.0


func _fly(target: Vector3, delta: float) -> void:
	_hover += delta
	var you := game.player.global_position
	var goal := target
	if goal == you:
		goal = you + Vector3(0.0, 1.9, 0.0) - (you - global_position).normalized() * 1.6
	goal.y += sin(_hover * 2.0) * 0.12
	var to := goal - global_position
	velocity = to.normalized() * minf(float(stats["speed"]), to.length() * 3.0)
	move_and_slide()
	look_at(Vector3(you.x, global_position.y, you.z), Vector3.UP)


func _eye() -> Vector3:
	return global_position + Vector3(0.0, 0.0 if kind == "drone" else 1.5, 0.0)


func _try_attack() -> void:
	if _cooldown > 0.0:
		return
	var camera := game.player.camera.global_position
	if _eye().distance_to(camera) > float(stats["reach"]) + (0.3 if kind == "drone" else 0.6):
		return
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(_eye(), camera)
	query.collision_mask = 1
	query.exclude = [get_rid(), game.player.get_rid()]
	if not space.intersect_ray(query).is_empty():
		return
	_cooldown = float(stats["cooldown"])
	if kind == "drone":
		Sound.play("zap", 0.1)
		_spark_line(camera, Color("#8fd0ff"))
		game.hurt(float(stats["damage"]), "A Civic enforcement drone. The report called it a cardiac event.")
	elif kind == "shooter":
		Sound.play("bang", 0.1)
		_spark_line(camera, Color("#ffd27a"))
		game.hurt(float(stats["damage"]), "Shot through your own window.")
	else:
		Sound.play("hit", 0.15)
		game.hurt(float(stats["damage"]), "They beat you to death in your own trailer.")


func _spark_line(to: Vector3, colour: Color) -> void:
	var line := MeshInstance3D.new()
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, TextureFactory.glow(colour))
	mesh.surface_add_vertex(_eye())
	mesh.surface_add_vertex(to + Vector3(0.0, -0.3, 0.0))
	mesh.surface_end()
	line.mesh = mesh
	game.world.add_child(line)
	get_tree().create_timer(0.12).timeout.connect(line.queue_free)


## A hit from you. from: where it came from, for the knock back.
func hit(amount: float, from: Vector3) -> void:
	if is_down:
		return
	health -= amount
	_flash()
	var push := (global_position - from)
	push.y = 0.0
	velocity += push.normalized() * (2.5 if kind == "drone" else 3.5)
	_cooldown = maxf(_cooldown, 0.35)
	if health <= 0.0:
		_go_down()


func _flash() -> void:
	for node in figure.find_children("*", "Sprite3D", true, false):
		var sprite := node as Sprite3D
		sprite.modulate = Color(1.0, 0.35, 0.35)
		get_tree().create_timer(0.12).timeout.connect(func() -> void:
			if is_instance_valid(sprite):
				sprite.modulate = Color.WHITE)
	for node in figure.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var before := mesh.material_override
		mesh.material_override = TextureFactory.glow(Color("#ff5a40"))
		get_tree().create_timer(0.12).timeout.connect(func() -> void:
			if is_instance_valid(mesh):
				mesh.material_override = before)


## Down: a thug falls and crawls off; a drone drops and dies.
func _go_down() -> void:
	is_down = true
	collision_layer = 0
	remove_from_group("enemies")
	var tween := create_tween()
	if kind == "drone":
		Sound.play("hit", 0.1, -4.0)
		var floor_y := 0.1 if inside(global_position) else TrailerWorld.GROUND + 0.1
		tween.tween_property(self, "global_position:y", floor_y, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_interval(4.0)
	else:
		tween.tween_property(figure, "rotation_degrees:x", -85.0, 0.35)
		tween.parallel().tween_property(figure, "position:y", 0.15, 0.35)
		tween.tween_interval(3.0)
		tween.tween_property(figure, "scale", Vector3(1.0, 0.01, 1.0), 0.6)
	tween.tween_callback(queue_free)
	down.emit(self)
