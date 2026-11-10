class_name Fighter
extends Node
## Your weapons: the bat under the counter and the slingshot in your belt.
## Draw with R (or the Arm button), cycle bat, slingshot, nothing. While a
## weapon is out, use swings or shoots, except at doors, shutters and the
## like, which you still open and close.

## Things you still operate with a weapon in your hand.
const STILL_USE := ["door", "barricade", "shutters", "hatch", "first_aid", "bed", "computer", "church_exit", "church_street", "collect"]

var game: TrailerGame
var weapon := ""
var _cooldown := 0.0
var _rng := RandomNumberGenerator.new()


func setup(owner_game: TrailerGame) -> void:
	game = owner_game
	_rng.randomize()


func _process(delta: float) -> void:
	_cooldown -= delta


## Bat, slingshot, nothing.
func cycle() -> void:
	if game.stand.held != null:
		game.hud.toast("Put down what you are holding first.")
		return
	set_weapon(Combat.next(weapon))


func set_weapon(id: String) -> void:
	weapon = id
	game.player.arm.set_weapon(id)
	Sound.play("step", 0.1, -8.0)


func armed() -> bool:
	return weapon != ""


## Whether use should attack rather than operate what you look at. With a
## weapon out you work doors and shutters only standing right at them, so you
## can shoot through a window without closing it.
func attacks(target: Interactable) -> bool:
	if not armed():
		return false
	if target == null or not target.id in STILL_USE:
		return true
	return game.player.camera.global_position.distance_to(target.global_position) > 1.4


func text() -> String:
	match weapon:
		"bat":
			return "Bat"
		"slingshot":
			return "Slingshot (%d shot)" % Survival.stock(game.save, "shot")
	return ""


func attack() -> void:
	if _cooldown > 0.0 or not armed():
		return
	_cooldown = float(Combat.WEAPONS[weapon]["cooldown"])
	if weapon == "bat":
		Sound.play("swing", 0.1)
		game.player.arm.swing(_bat_hit)
	else:
		if not Survival.take_stock(game.save, "shot"):
			game.hud.toast("No shot left. Order more on the computer.")
			_cooldown = 0.3
			return
		Sound.play("sling", 0.08)
		game.player.arm.shoot(_sling_hit)


func _bat_hit() -> void:
	var camera: Camera3D = game.player.camera
	var forward := -camera.global_basis.z
	var reach := float(Combat.WEAPONS["bat"]["range"])
	var space := camera.get_world_3d().direct_space_state
	var hit_any := false
	for node in game.get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		var centre := enemy.global_position + Vector3(0.0, 0.0 if enemy.kind == "drone" else 1.1, 0.0)
		var to := centre - camera.global_position
		if to.length() > reach + 0.3 or forward.dot(to.normalized()) < 0.55:
			continue
		var query := PhysicsRayQueryParameters3D.create(camera.global_position, centre)
		query.collision_mask = 1
		query.exclude = [game.player.get_rid()]
		if not space.intersect_ray(query).is_empty():
			continue
		enemy.hit(Combat.damage("bat", game.character), camera.global_position)
		hit_any = true
	if hit_any:
		Sound.play("hit", 0.1)


func _sling_hit() -> void:
	var camera: Camera3D = game.player.camera
	var spread := deg_to_rad(Combat.aim_spread(game.character, Survival.need(game.save, "stress")))
	var direction := -camera.global_basis.z
	direction = direction.rotated(camera.global_basis.x, _rng.randf_range(-spread, spread))
	direction = direction.rotated(camera.global_basis.y, _rng.randf_range(-spread, spread))
	var from := camera.global_position
	var to := from + direction * float(Combat.WEAPONS["slingshot"]["range"])
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1 | Enemy.LAYER
	query.exclude = [game.player.get_rid()]
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
	var end: Vector3 = hit.get("position", to)
	_pebble(game.player.hand.global_position, end)
	var collider: Object = hit.get("collider")
	if collider is Enemy:
		(collider as Enemy).hit(Combat.damage("slingshot", game.character), from)
		Sound.play("hit", 0.1, -2.0)


## The shot in flight: a small grey pebble, quick.
func _pebble(from: Vector3, to: Vector3) -> void:
	var pebble := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.02
	sphere.height = 0.04
	pebble.mesh = sphere
	pebble.material_override = TextureFactory.plain(Color("#9a9ca0"), 0.3)
	game.world.add_child(pebble)
	pebble.global_position = from
	var tween := pebble.create_tween()
	tween.tween_property(pebble, "global_position", to, clampf(from.distance_to(to) / 45.0, 0.04, 0.5))
	tween.tween_callback(pebble.queue_free)
