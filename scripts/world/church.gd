class_name Church
extends RefCounted
## St. Brigid's, built far from the trailer in the same world. You walk there
## from the sign at the end of the church street; the walk itself is a fade.
## Nave along X from the door at ORIGIN.x to the apse 24 m on, aisle at Z 0.

const ORIGIN := Vector3(100.0, 0.0, 0.0)
const LENGTH := 24.0
const HALF_WIDTH := 5.0
const HEIGHT := 7.0
const SPAWN := Vector3(101.4, 0.05, 0.0)
const SPAWN_YAW := -PI / 2.0
## Where you come back to, on the street outside the trailer door.
const HOME_SPAWN := Vector3(4.85, -0.4, 5.6)
const HOME_YAW := 0.0
const WALK_MINUTES := 20.0

var world: TrailerWorld
var priest: Node3D
var informant: Node3D
var votive_flames: Array[Node3D] = []


static func contains(point: Vector3) -> bool:
	return point.x > ORIGIN.x - 1.0 and point.x < ORIGIN.x + LENGTH + 1.0 and absf(point.z) < HALF_WIDTH + 1.0


func build(into: TrailerWorld) -> void:
	world = into
	_shell()
	_pews()
	_sanctuary()
	_confessional()
	_side_things()
	_lights()


func _p(x: float, y: float, z: float) -> Vector3:
	return ORIGIN + Vector3(x, y, z)


func _shell() -> void:
	var stone := world._m("concrete")
	var floor_mat := world._m("floor_check")
	world._span(_p(0, -0.3, -HALF_WIDTH), _p(LENGTH, 0, HALF_WIDTH), floor_mat)
	world._span(_p(0, 0, -HALF_WIDTH - 0.3), _p(LENGTH, HEIGHT, -HALF_WIDTH), stone)
	world._span(_p(0, 0, HALF_WIDTH), _p(LENGTH, HEIGHT, HALF_WIDTH + 0.3), stone)
	world._span(_p(LENGTH, 0, -HALF_WIDTH), _p(LENGTH + 0.3, HEIGHT, HALF_WIDTH), stone)
	world._span(_p(-0.3, 0, -HALF_WIDTH), _p(0, HEIGHT, HALF_WIDTH), stone)
	world._span(_p(0, HEIGHT, -HALF_WIDTH), _p(LENGTH, HEIGHT + 0.3, HALF_WIDTH), world._m("wood"))
	var beam := world._c("#2a1c14")
	var x := 1.5
	while x < LENGTH:
		world._span(_p(x, HEIGHT - 0.35, -HALF_WIDTH), _p(x + 0.3, HEIGHT, HALF_WIDTH), beam, false)
		x += 3.0
	# Pillars between nave and side aisles.
	for px in [4.0, 8.0, 12.0, 16.0]:
		for pz in [-3.4, 3.4]:
			world._span(_p(px - 0.25, 0, pz - 0.25), _p(px + 0.25, HEIGHT, pz + 0.25), stone)
	# Stained glass between the pillars: three lancets each.
	var glass := ["#7a2430", "#2d4a7a", "#b08a3a", "#3f6a4a"]
	var i := 0
	for wx in [2.0, 6.0, 10.0, 14.0]:
		for side in [-1.0, 1.0]:
			var z: float = side * (HALF_WIDTH - 0.02)
			if wx == 10.0 and side < 0.0:
				continue  # The confessional stands here.
			world._span(_p(wx - 0.75, 2.8, z - 0.02), _p(wx + 0.75, 5.8, z + 0.02), world._c("#151217"), false)
			for lancet in 3:
				var lx: float = wx - 0.6 + lancet * 0.42
				var colour: String = glass[(i + lancet) % glass.size()]
				world._span(_p(lx, 3.0, z - 0.03), _p(lx + 0.34, 5.6, z + 0.03), world._g(colour), false)
			i += 1
	# Door, with the way home.
	var door := world._c("#4a2c1c")
	world._span(_p(0.0, 0, -1.0), _p(0.08, 2.9, -0.03), door, false)
	world._span(_p(0.0, 0, 0.03), _p(0.08, 2.9, 1.0), door, false)
	world._span(_p(0.0, 2.9, -1.1), _p(0.1, 3.05, 1.1), world._c("#2a1c14"), false)
	world._zone(_p(0.05, 0, -1.0), _p(0.4, 2.6, 1.0), "church_exit")


func _pews() -> void:
	var wood := world._m("wood")
	var dark := world._c("#3a2618")
	var x := 3.0
	while x < 15.5:
		for block in [[-3.0, -0.75], [0.75, 3.0]]:
			var z1: float = block[0]
			var z2: float = block[1]
			world._span(_p(x, 0.42, z1), _p(x + 0.45, 0.5, z2), wood)
			world._span(_p(x - 0.06, 0.5, z1), _p(x, 1.0, z2), wood, false)
			world._span(_p(x + 0.05, 0, z1), _p(x + 0.12, 0.42, z1 + 0.06), dark, false)
			world._span(_p(x + 0.05, 0, z2 - 0.06), _p(x + 0.12, 0.42, z2), dark, false)
			# Kneeler.
			world._span(_p(x + 0.7, 0.12, z1), _p(x + 0.85, 0.2, z2), dark, false)
		x += 1.5
	world._zone(_p(9.0, 0.0, 0.75), _p(13.5, 1.0, 3.0), "pew")
	world._zone(_p(9.0, 0.0, -3.0), _p(13.5, 1.0, -0.75), "pew")


func _sanctuary() -> void:
	var stone := world._m("concrete")
	var wood := world._m("wood")
	world._span(_p(18.0, 0, -HALF_WIDTH), _p(LENGTH, 0.3, HALF_WIDTH), stone)
	# Communion rail.
	world._span(_p(17.8, 0.85, -4.0), _p(18.0, 0.95, 4.0), wood)
	for rz in range(-4, 5):
		world._span(_p(17.86, 0, rz * 0.98 - 0.04), _p(17.94, 0.85, rz * 0.98 + 0.04), wood, false)
	world._invisible(_p(17.8, 0, -HALF_WIDTH), _p(18.0, 2.0, HALF_WIDTH))
	# Altar with its cloth and candles.
	world._span(_p(21.4, 0.3, -1.2), _p(22.4, 1.3, 1.2), stone)
	world._span(_p(21.35, 1.3, -1.3), _p(22.45, 1.33, 1.3), world._c("#e6e0d2"), false)
	world._span(_p(21.33, 0.9, -1.3), _p(21.36, 1.33, 1.3), world._c("#e6e0d2"), false)
	for cz in [-0.9, 0.9]:
		world._cyl(0.035, 0.4, _p(22.0, 1.53, cz), world._c("#efe6cf"))
		world._span(_p(21.98, 1.73, cz - 0.02), _p(22.02, 1.8, cz + 0.02), world._g("#ffcf7a"), false)
	# Tabernacle against the apse wall.
	world._span(_p(23.2, 0.3, -0.7), _p(24.0, 1.3, 0.7), stone)
	world._span(_p(23.45, 1.3, -0.35), _p(23.95, 2.0, 0.35), world._c("#b8963c"), false)
	world._span(_p(23.43, 1.4, -0.2), _p(23.45, 1.9, 0.2), world._c("#d7bd6a"), false)
	world._zone(_p(17.4, 0, -1.2), _p(17.8, 1.2, 1.2), "tabernacle")
	# Sanctuary lamp: the Lord is here.
	world._span(_p(20.6, 2.5, 1.85), _p(20.75, 2.7, 2.0), world._g("#e0303c"), false)
	world._span(_p(20.66, 2.7, 1.91), _p(20.69, HEIGHT, 1.94), world._c("#1c1a1f"), false)
	world._light(_p(20.67, 2.4, 1.92), "#e0303c", 0.8, 4.0)
	# Crucifix.
	var cross := world._c("#2a1c14")
	var body := world._c("#d9c8a8")
	world._span(_p(23.85, 2.4, -0.12), _p(23.97, 6.3, 0.12), cross, false)
	world._span(_p(23.85, 5.0, -1.2), _p(23.97, 5.25, 1.2), cross, false)
	world._span(_p(23.78, 3.7, -0.11), _p(23.85, 5.0, 0.11), body, false)
	world._span(_p(23.78, 4.95, -0.95), _p(23.85, 5.07, 0.95), body, false)
	world._span(_p(23.78, 5.08, -0.09), _p(23.85, 5.3, 0.09), body, false)
	world._span(_p(23.77, 3.85, -0.12), _p(23.84, 4.2, 0.12), world._c("#c8bfae"), false)


func _confessional() -> void:
	var wood := world._m("wood")
	var dark := world._c("#2a1c14")
	world._span(_p(9.0, 0, -HALF_WIDTH), _p(11.6, 2.5, -3.9), wood)
	world._span(_p(8.95, 2.5, -HALF_WIDTH), _p(11.65, 2.65, -3.85), dark, false)
	# The priest's curtain in the middle, the doors either side.
	world._span(_p(9.95, 0.1, -3.89), _p(10.65, 2.2, -3.86), world._c("#4a2a55"), false)
	for dx in [9.1, 10.75]:
		world._span(_p(dx, 0.05, -3.89), _p(dx + 0.75, 2.25, -3.87), dark, false)
		world._span(_p(dx + 0.22, 1.45, -3.9), _p(dx + 0.53, 1.75, -3.88), world._c("#0d0b0e"), false)
	world._zone(_p(9.0, 0, -3.88), _p(11.6, 2.2, -3.6), "confession")
	var sign_text := Label3D.new()
	sign_text.text = "Confessions"
	sign_text.font = UiKit.title_font()
	sign_text.font_size = 64
	sign_text.pixel_size = 0.004
	sign_text.modulate = Color("#d7bd6a")
	sign_text.position = _p(10.3, 2.85, -3.84)
	world.add_child(sign_text)

	priest = _person("#141216", true)
	priest.position = _p(8.4, 0, -3.95)
	priest.rotation.y = 0.0
	var talk := world._zone(Vector3(-0.3, 0.0, -0.3), Vector3(0.3, 1.8, 0.3), "priest", priest)
	talk.position.y = 0.9


func _side_things() -> void:
	var stone := world._m("concrete")
	# Holy water by the door.
	world._cyl(0.12, 0.95, _p(1.2, 0.475, 3.4), stone)
	world._cyl(0.3, 0.14, _p(1.2, 1.0, 3.4), stone, Vector3.ZERO, 0.22)
	world._span(_p(1.0, 1.07, 3.2), _p(1.4, 1.08, 3.6), world._g("#6f8fa0"), false)
	world._zone(_p(0.9, 0, 3.1), _p(1.5, 1.2, 3.7), "font")
	# Our Lady, and the votive stand at her feet.
	world._span(_p(16.6, 0, 3.9), _p(17.6, 0.9, 4.9), stone)
	world._cyl(0.28, 1.4, _p(17.1, 1.6, 4.4), world._c("#3d5a8a"), Vector3.ZERO, 0.16)
	world._cyl(0.2, 0.9, _p(17.1, 1.55, 4.4), world._c("#e6e0d2"), Vector3.ZERO, 0.12)
	world._span(_p(17.0, 2.3, 4.3), _p(17.2, 2.55, 4.5), world._c("#e3cdb0"), false)
	world._span(_p(16.95, 2.45, 4.25), _p(17.25, 2.62, 4.55), world._c("#3d5a8a"), false)
	world._span(_p(15.0, 0, 3.7), _p(16.4, 0.85, 4.6), world._c("#1c1a1f"))
	for row in 2:
		for col in 6:
			var at := _p(15.15 + col * 0.22, 0.9 + row * 0.1, 3.85 + row * 0.35)
			world._span(at - Vector3(0.03, 0.06, 0.03), at + Vector3(0.03, 0.04, 0.03), world._c("#b33a2e"), false)
			var flame := world._span(at + Vector3(-0.012, 0.04, -0.012), at + Vector3(0.012, 0.09, 0.012), world._g("#ffcf7a"), false)
			flame.visible = (row * 6 + col) % 3 == 0
			votive_flames.append(flame)
	world._zone(_p(14.95, 0, 3.6), _p(16.45, 1.1, 3.75), "votive")

	informant = _person("#55575c", false)
	informant.position = _p(1.6, 0, -4.2)
	informant.visible = false


func _lights() -> void:
	for lx in [4.0, 10.0, 16.0]:
		world._light(_p(lx, 5.8, 0.0), "#ffd9a0", 1.1, 10.0)
	world._light(_p(21.0, 4.0, 0.0), "#ffe2b0", 1.4, 8.0)
	world._light(_p(15.7, 1.4, 3.6), "#ffb560", 0.6, 3.0)


## A standing figure, drawn like the customers.
func _person(shirt: String, collar: bool) -> Node3D:
	var holder := Node3D.new()
	world.add_child(holder)
	var rng := RandomNumberGenerator.new()
	rng.seed = 41 if collar else 77
	var person := PlayerCharacter.new()
	person.randomize_appearance(rng)
	person.appearance["sex"] = "man"
	person.appearance["age"] = "old" if collar else "grown"
	person.appearance["facial"] = "none"
	person.appearance["hair"] = "short"
	person.appearance["hair_colour"] = "grey" if collar else "black"
	var canvas := SubViewport.new()
	canvas.size = Vector2i(80, 320)
	canvas.transparent_bg = true
	canvas.disable_3d = true
	canvas.render_target_update_mode = SubViewport.UPDATE_ONCE
	var portrait := CharacterPortrait.new()
	portrait.full_body = true
	portrait.apron = false
	portrait.collar = collar
	portrait.shirt_colour = Color(shirt)
	portrait.size = Vector2(80, 320)
	portrait.character = person
	canvas.add_child(portrait)
	holder.add_child(canvas)
	var sprite := Sprite3D.new()
	sprite.texture = canvas.get_texture()
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.shaded = true
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.pixel_size = Player.BODY_PIXEL_SIZE
	sprite.position.y = 320.0 * Player.BODY_PIXEL_SIZE / 2.0
	holder.add_child(sprite)
	return holder


## Lights one more votive candle.
func light_votive() -> void:
	for flame in votive_flames:
		if not flame.visible:
			flame.visible = true
			return
