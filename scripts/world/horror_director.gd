class_name HorrorDirector
extends Node
## Stages the horror in the world. Horror (the rules) decides what comes; this
## decides how you see and hear it: shapes only the mirror shows, shapes only
## the cameras catch, the lights dying, a face in your face, a drone at the
## window, enforcers at the door.

const MIRROR := Vector3(10.99, 1.6, 1.275)
const LAMP := Vector3(8.3, TrailerWorld.GROUND, 10.4)
const ACROSS_STREET := Vector3(6.8, TrailerWorld.GROUND, 10.8)
const HOME_WINDOW := Vector3(8.3, 1.45, TrailerWorld.WIDTH + 0.9)
const ENTRANCE := Vector3(4.85, TrailerWorld.GROUND, 4.4)

var game: TrailerGame
var _minutes := 0.0
var _rng := RandomNumberGenerator.new()
## Shapes that vanish once you have looked straight at them for a moment:
## [node, seconds left, seconds looked at].
var _watchers: Array = []
var _shadow_texture: ImageTexture


func setup(owner_game: TrailerGame) -> void:
	game = owner_game
	_rng.randomize()
	_shadow_texture = _make_shadow()


func tick(delta: float, busy: bool, in_church: bool) -> void:
	_update_watchers(delta)
	if busy:
		return
	_minutes += delta * Survival.MINUTES_PER_SECOND
	if _minutes < Horror.ROLL_MINUTES:
		return
	_minutes = 0.0
	var event := Horror.roll(game.save, _rng, context(in_church))
	if not event.is_empty():
		run(event)


func context(in_church: bool) -> Dictionary:
	var customers := false
	for customer in game.stand.spots:
		if customer != null and is_instance_valid(customer) and customer.at_hatch:
			customers = true
	var at := game.player.global_position
	return {
		"in_church": in_church,
		"near_mirror": at.x > 9.0 and at.distance_to(Vector3(MIRROR.x, at.y, MIRROR.z)) < 2.2,
		"hatch_open": bool(game.save["world"]["hatch_open"]),
		"customers": customers,
	}


## Plays an event: its effect on you, then the scene.
func run(event: Dictionary) -> void:
	var text := Horror.apply(game.save, event)
	match event["id"]:
		"whisper", "smile":
			Sound.play("tempt", 0.08, -4.0)
			game.hud.toast(text)
		"knock":
			Sound.play("knock")
			await get_tree().create_timer(2.6).timeout
			game.hud.toast(text)
		"camera_shape":
			Sound.play("beep")
			_shape(Vector3(1.6, TrailerWorld.GROUND, 6.2), TrailerWorld.LAYER_CCTV_ONLY, 90.0)
			game.hud.toast(text)
		"lights_out":
			await _lights_out(text)
		"mirror":
			await _mirror(text)
		"watcher":
			var shape := _shape(LAMP, TrailerWorld.LAYER_WORLD, 120.0)
			_watchers.append([shape, 120.0, 0.0])
			game.hud.toast(text)
		"jumpscare":
			_jumpscare()
		"shove":
			Sound.play("scare", 0.05, -6.0)
			_shake(0.5, 0.12)
			game.hud.flash(Color(0.5, 0.0, 0.0, 0.6))
			game.hud.toast(text)
		"drone":
			Sound.play("civic_drone", 0.05, -2.0)
			_drone(25.0)
			game.hud.toast(text)
		"tax", "feeds_seized":
			Sound.play("beep")
			game.hud.toast(text)
		"inspector":
			var inspector: Node3D = game.world.church._person("#4a4d52", false)
			inspector.position = Vector3(1.75, TrailerWorld.GROUND, 3.95)
			game.hud.toast(text)
			get_tree().create_timer(3.0).timeout.connect(game.world.set_hatch_open.bind(false, true))
			get_tree().create_timer(8.0).timeout.connect(inspector.queue_free)
		"informant":
			var man: Node3D = game.world.church._person("#55575c", false)
			man.position = ACROSS_STREET
			get_tree().create_timer(180.0).timeout.connect(man.queue_free)
			game.hud.toast(text)
		"raid":
			await _raid(text)
	_check_death()


func _check_death() -> void:
	if Survival.health(game.save) <= 0.0:
		game._die("They found you on the trailer floor in the morning.")


# Shapes -----------------------------------------------------------------------

## A tall black shape with two points of light for eyes.
func _make_shadow() -> ImageTexture:
	var image := Image.create(24, 104, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var black := Color(0.015, 0.008, 0.02)
	image.fill_rect(Rect2i(8, 0, 8, 12), black)
	image.fill_rect(Rect2i(10, 12, 4, 3), black)
	image.fill_rect(Rect2i(6, 15, 12, 50), black)
	image.fill_rect(Rect2i(2, 17, 4, 66), black)
	image.fill_rect(Rect2i(18, 17, 4, 66), black)
	image.fill_rect(Rect2i(7, 65, 4, 39), black)
	image.fill_rect(Rect2i(13, 65, 4, 39), black)
	image.set_pixel(10, 5, Color(1.0, 0.25, 0.15))
	image.set_pixel(13, 5, Color(1.0, 0.25, 0.15))
	return ImageTexture.create_from_image(image)


func _shape(at: Vector3, layers: int, seconds: float) -> Sprite3D:
	var shape := Sprite3D.new()
	shape.texture = _shadow_texture
	shape.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	shape.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	shape.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	shape.shaded = false
	shape.pixel_size = 0.019
	shape.layers = layers
	game.world.add_child(shape)
	shape.global_position = at + Vector3(0.0, 104.0 * 0.019 / 2.0, 0.0)
	get_tree().create_timer(seconds).timeout.connect(func() -> void:
		if is_instance_valid(shape):
			shape.queue_free()
	)
	return shape


## Watchers go when you look straight at them.
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


func _lights_out(text: String) -> void:
	Sound.play("buzz", 0.0, -4.0)
	game.world.blackout(true)
	var camera: Camera3D = game.player.camera
	var ahead := -camera.global_basis.z
	ahead.y = 0.0
	var at := game.player.global_position + ahead.normalized() * 1.9
	at.x = clampf(at.x, 0.4, 10.6)
	at.z = clampf(at.z, 0.3, 2.9)
	var shape := _shape(Vector3(at.x, 0.0, at.z), TrailerWorld.LAYER_WORLD, 2.4)
	await get_tree().create_timer(2.4).timeout
	if is_instance_valid(shape):
		shape.queue_free()
	game.world.blackout(false)
	game.hud.toast(text)


func _mirror(text: String) -> void:
	var camera: Camera3D = game.player.camera
	var behind := camera.global_basis.z
	behind.y = 0.0
	# Behind you and a little to one side, so it shows over your shoulder.
	var at := game.player.global_position + behind.normalized() * 0.8 + camera.global_basis.x * 0.32
	_shape(Vector3(at.x, 0.0, at.z), TrailerWorld.LAYER_REFLECTION, 1.8)
	Sound.play("tempt", 0.0, -8.0)
	await get_tree().create_timer(1.8).timeout
	game.hud.toast(text)


func _jumpscare() -> void:
	Sound.play("scare")
	_shake(0.6, 0.16)
	var face := JumpscareFace.new()
	game.hud.add_child(face)
	face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await get_tree().create_timer(0.55).timeout
	face.queue_free()
	game.world.flicker()


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
