class_name HorrorDirector
extends Node
## Stages the horror in the world. Horror (the rules) decides what comes; this
## decides how you see and hear it: a drone at the window, a man watching
## from under the lamp, someone at your bins seen only on the cameras, the
## power cut, enforcers at the door. Prudence can bring a warning first.

const LAMP := Vector3(8.3, TrailerWorld.GROUND, 10.4)
const ACROSS_STREET := Vector3(6.8, TrailerWorld.GROUND, 10.8)
const HOME_WINDOW := Vector3(8.3, 1.45, TrailerWorld.WIDTH + 0.9)
const ENTRANCE := Vector3(4.85, TrailerWorld.GROUND, 4.4)

var game: TrailerGame
var _minutes := 0.0
var _rng := RandomNumberGenerator.new()
## People who leave once you have looked straight at them for a moment:
## [node, seconds left, seconds looked at].
var _watchers: Array = []


func setup(owner_game: TrailerGame) -> void:
	game = owner_game
	_rng.randomize()


func tick(delta: float, busy: bool, in_church: bool) -> void:
	_update_watchers(delta)
	_update_fight()
	if busy:
		return
	_minutes += delta * Survival.MINUTES_PER_SECOND
	if _minutes < Horror.ROLL_MINUTES:
		return
	_minutes = 0.0
	if fighting() or in_church:
		return
	var gang := Combat.roll_gang(game.save, _rng)
	if gang > 0:
		_warn_then("Mrs. Duffy's grandson runs past the hatch: \"There's a gang coming up from the canal. Shut your door!\"", start_gang.bind(gang))
		return
	var hunt := Combat.roll_hunt(game.save, _rng)
	if hunt > 0:
		_warn_then("Your phone buzzes: a message from a parishioner. \"Drones over the market, heading your way.\"", start_hunt.bind(hunt))
		return
	var event := Horror.roll(game.save, _rng, context(in_church))
	if not event.is_empty():
		run(event)


## Prudence: sometimes a warning reaches you before trouble does, with a
## little time to get ready.
func _warn_then(warning: String, then: Callable, seconds := 25.0) -> bool:
	if _rng.randf() >= Virtue.warning_chance(game.save):
		then.call()
		return false
	game.hud.toast(warning)
	GameLog.add("info", "Warned in time: " + warning)
	get_tree().create_timer(seconds).timeout.connect(then)
	return true


# Fights -----------------------------------------------------------------------

var _fight := ""


func fighting() -> bool:
	return not _fight.is_empty()


func _spawn(kind: String, at: Vector3) -> Enemy:
	var enemy := Enemy.create(game, kind)
	game.world.add_child(enemy)
	enemy.global_position = at
	enemy.down.connect(_on_down)
	return enemy


## A gang comes up the street at night.
func start_gang(count: int) -> void:
	_fight = "gang"
	for kind: String in Combat.gang_members(count, _rng):
		_spawn(kind, Vector3(_rng.randf_range(-2.0, 11.0), TrailerWorld.GROUND, _rng.randf_range(11.0, 14.0)))
	Sound.play("tempt", 0.0, -10.0)
	game.hud.toast("Figures in hoods are coming up the street toward the trailer. Some are carrying something. Shut the door, or get ready.")


## Civic enforcement drones come for you.
func start_hunt(count: int) -> void:
	_fight = "hunt"
	for i in count:
		_spawn("drone", Vector3(_rng.randf_range(-4.0, 13.0), TrailerWorld.GROUND + 5.0, _rng.randf_range(10.0, 15.0)))
	Sound.play("siren", 0.0, -8.0)
	Sound.play("civic_drone", 0.0, 0.0)
	game.hud.toast("Civic Link: your account is flagged for irregular assembly. Enforcement drones dispatched. Cooperation is advised.")


## You chose to fight the burglar: he is in the room.
func burglar_fight() -> void:
	_fight = "burglar"
	_spawn("burglar", Vector3(8.3, 0.05, 2.75))
	game.hud.toast("You grab the bat from beside the bed.")


func _on_down(enemy: Enemy) -> void:
	var loot := Combat.loot(enemy.kind, _rng)
	if loot > 0:
		game.save["survival"]["money"] = Survival.money(game.save) + loot
		game.hud.toast("He goes down. %d credits fall out of his jacket." % loot)
	elif enemy.kind == "drone":
		game.hud.toast("The drone drops, sparking.")
	elif enemy.kind == "burglar":
		game.hud.toast("He scrambles back out through the window and is gone.")


func _update_fight() -> void:
	if _fight.is_empty():
		return
	var left := get_tree().get_nodes_in_group("enemies")
	for node in left:
		var enemy := node as Enemy
		if enemy.kind == "drone" and enemy.gave_up():
			enemy.remove_from_group("enemies")
			var tween := enemy.create_tween()
			tween.tween_property(enemy, "global_position:y", 30.0, 3.0)
			tween.tween_callback(enemy.queue_free)
	if not get_tree().get_nodes_in_group("enemies").is_empty():
		return
	match _fight:
		"gang":
			game.hud.toast("The last of them runs. The street is quiet again.")
			Survival.change_need(game.save, "stress", -10.0)
		"hunt":
			game.hud.toast("The sky is empty. Civic Link will remember this.")
			Horror.notice(game.save, 5.0)
		"burglar":
			game._after_night("You fought him off. He is gone, and so is your sleep.", true)
	_fight = ""


func context(in_church: bool) -> Dictionary:
	var customers := false
	for customer in game.stand.spots:
		if customer != null and is_instance_valid(customer) and customer.at_hatch:
			customers = true
	return {
		"in_church": in_church,
		"hatch_open": bool(game.save["world"]["hatch_open"]),
		"customers": customers,
		"shutters_closed": bool(game.save["world"]["shutters_closed"]),
	}


## Plays an event: its effect on you, then the scene.
func run(event: Dictionary) -> void:
	if event["id"] == "raid":
		var warned := _rng.randf() < Virtue.warning_chance(game.save)
		if warned:
			game.hud.toast("A soft knock at the back: a neighbour. \"Enforcers on the next street. Hide what you need to.\" You have a minute.")
			GameLog.add("info", "Warned in time: a raid is coming.")
			await get_tree().create_timer(30.0).timeout
		event = event.duplicate()
		event["warned"] = warned
	var text := Horror.apply(game.save, event, game.character.stat_value("nerve"), _rng)
	match event["id"]:
		"knock":
			Sound.play("knock")
			await get_tree().create_timer(2.6).timeout
			game.hud.toast(text)
		"camera_shape":
			Sound.play("beep")
			var man: PersonRig = People.place(game.world, People.role("informant", _rng), Vector3(1.6, TrailerWorld.GROUND, 6.2), PI * 0.8)
			man.hold_pose = "reach"
			man.set_layers(TrailerWorld.LAYER_CCTV_ONLY)
			get_tree().create_timer(90.0).timeout.connect(man.queue_free)
			game.hud.toast(text)
		"power_cut":
			Sound.play("buzz", 0.0, -4.0)
			game.world.blackout(true)
			game.hud.toast(text)
			await get_tree().create_timer(_rng.randf_range(40.0, 75.0)).timeout
			game.world.blackout(false)
			game.hud.toast("The power comes back, with a buzz from every light.")
		"watcher":
			var watcher: PersonRig = People.place(game.world, People.role("informant", _rng), LAMP, PI)
			_watchers.append([watcher, 120.0, 0.0])
			game.hud.toast(text)
		"drone":
			Sound.play("civic_drone", 0.05, -2.0)
			_drone(25.0)
			game.hud.toast(text)
		"tax", "feeds_seized":
			Sound.play("beep")
			game.hud.toast(text)
		"inspector":
			var inspector: Node3D = People.place(game.world, People.role("inspector", _rng), Vector3(1.75, TrailerWorld.GROUND, 3.95), 0.0)
			game.hud.toast(text)
			get_tree().create_timer(3.0).timeout.connect(game.world.set_hatch_open.bind(false, true))
			get_tree().create_timer(8.0).timeout.connect(inspector.queue_free)
		"informant":
			var spy: Node3D = People.place(game.world, People.role("informant", _rng), ACROSS_STREET, 0.0)
			get_tree().create_timer(180.0).timeout.connect(spy.queue_free)
			game.hud.toast(text)
		"raid":
			await _raid(text)
	_check_death()


func _check_death() -> void:
	if Survival.health(game.save) <= 0.0:
		game._die("They found you on the trailer floor in the morning.")


# Watchers ---------------------------------------------------------------------

## A watcher walks off once you have looked straight at him for a moment.
func _update_watchers(delta: float) -> void:
	var camera: Camera3D = game.player.camera
	for entry: Array in _watchers.duplicate():
		var shape: Node3D = entry[0]
		entry[1] = float(entry[1]) - delta
		if not is_instance_valid(shape) or float(entry[1]) <= 0.0:
			_watchers.erase(entry)
			continue
		var to_shape := (shape.global_position - camera.global_position).normalized()
		if -camera.global_basis.z.dot(to_shape) > 0.97:
			entry[2] = float(entry[2]) + delta
			if float(entry[2]) > 1.2:
				shape.queue_free()
				_watchers.erase(entry)


func _shake(seconds: float, strength: float) -> void:
	var camera: Camera3D = game.player.camera
	var tween := create_tween()
	var steps := int(seconds / 0.04)
	for i in steps:
		var fade := 1.0 - float(i) / steps
		tween.tween_property(camera, "h_offset", randf_range(-strength, strength) * fade, 0.04)
		tween.parallel().tween_property(camera, "v_offset", randf_range(-strength, strength) * fade, 0.04)
	tween.tween_property(camera, "h_offset", 0.0, 0.05)
	tween.parallel().tween_property(camera, "v_offset", 0.0, 0.05)


# The state --------------------------------------------------------------------

func _drone(seconds: float) -> void:
	var drone := Node3D.new()
	game.world.add_child(drone)
	drone.global_position = HOME_WINDOW
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
	var lens := MeshInstance3D.new()
	var eye := SphereMesh.new()
	eye.radius = 0.05
	eye.height = 0.1
	lens.mesh = eye
	lens.material_override = TextureFactory.glow(Color("#ff2a2a"))
	lens.position = Vector3(0.0, -0.06, -0.2)
	drone.add_child(lens)
	var light := OmniLight3D.new()
	light.light_color = Color("#ff2a2a")
	light.light_energy = 0.8
	light.omni_range = 2.0
	light.position = Vector3(0.0, -0.1, -0.3)
	drone.add_child(light)
	var tween := drone.create_tween().set_loops(int(seconds / 2.0))
	tween.tween_property(drone, "position:y", HOME_WINDOW.y + 0.12, 1.0).set_trans(Tween.TRANS_SINE)
	tween.tween_property(drone, "position:y", HOME_WINDOW.y - 0.12, 1.0).set_trans(Tween.TRANS_SINE)
	get_tree().create_timer(seconds).timeout.connect(drone.queue_free)


func _raid(text: String) -> void:
	game._set_busy(true)
	Sound.play("siren", 0.0, -2.0)
	# Red and blue through the door and the windows.
	var outside := OmniLight3D.new()
	outside.omni_range = 9.0
	outside.light_energy = 3.0
	game.world.add_child(outside)
	outside.global_position = ENTRANCE + Vector3(0.0, 2.0, 2.5)
	var inside := OmniLight3D.new()
	inside.omni_range = 6.0
	inside.light_energy = 1.6
	game.world.add_child(inside)
	inside.global_position = Vector3(5.6, 1.7, 2.6)
	var tween := outside.create_tween().set_loops(10)
	tween.tween_callback(func() -> void:
		outside.light_color = Color("#ff2030")
		inside.light_color = Color("#ff2030"))
	tween.tween_interval(0.3)
	tween.tween_callback(func() -> void:
		outside.light_color = Color("#2050ff")
		inside.light_color = Color("#2050ff"))
	tween.tween_interval(0.3)
	await get_tree().create_timer(1.2).timeout
	Sound.play("knock", 0.0, 4.0)
	_shake(0.3, 0.05)
	await get_tree().create_timer(1.6).timeout
	Sound.play("knock", 0.1, 6.0)
	_shake(0.3, 0.08)
	await get_tree().create_timer(1.4).timeout
	Sound.play("door", 0.0, 2.0)
	game.hud.flash(Color(0.4, 0.0, 0.0, 0.5))
	outside.queue_free()
	inside.queue_free()
	NoticeOverlay.show_notice(game, "Raid", text, func() -> void:
		game._set_busy(false)
		_check_death()
	)
