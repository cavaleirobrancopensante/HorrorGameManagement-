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
## The priest at the altar during Mass.
var celebrant: PersonRig
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
	# The high altar, against the east wall as of old: three steps up to the
	# footpace, the altar itself with its frontal and cloths, the gradines
	# behind with six tall candles, the tabernacle in the middle, and the
	# reredos rising behind it all to the crucifix. The priest stands on the
	# footpace facing it, with the people.
	var cream := world._c("#ddd3bf")
	var gold := world._c("#b8963c")
	var bright_gold := world._c("#d7bd6a")
	var linen := world._c("#ece6d8")
	var carpet := world._c("#6a1e26")
	world._span(_p(20.6, 0.3, -2.6), _p(LENGTH, 0.45, 2.6), stone)
	world._span(_p(21.0, 0.45, -2.4), _p(LENGTH, 0.6, 2.4), stone)
	world._span(_p(21.4, 0.6, -2.2), _p(LENGTH, 0.75, 2.2), stone)
	world._span(_p(21.45, 0.75, -1.6), _p(22.88, 0.76, 1.6), carpet, false)
	# The altar: stone, clothed in white, with a green frontal.
	world._span(_p(22.9, 0.75, -1.5), _p(23.7, 1.75, 1.5), cream)
	world._span(_p(22.86, 0.78, -1.46), _p(22.89, 1.6, 1.46), world._c("#2f5a3a"), false)
	world._span(_p(22.855, 0.78, -1.46), _p(22.865, 0.84, 1.46), gold, false)
	world._span(_p(22.855, 1.54, -1.46), _p(22.865, 1.6, 1.46), gold, false)
	for fz in [-1.46, -0.5, 0.44, 1.4]:
		world._span(_p(22.855, 0.84, fz), _p(22.865, 1.54, fz + 0.06), gold, false)
	world._span(_p(22.85, 1.0, -0.04), _p(22.86, 1.4, 0.04), bright_gold, false)
	world._span(_p(22.85, 1.16, -0.14), _p(22.86, 1.23, 0.14), bright_gold, false)
	world._span(_p(22.86, 1.6, -1.52), _p(23.72, 1.76, 1.52), linen, false)
	world._span(_p(22.86, 1.36, -1.53), _p(23.72, 1.76, -1.51), linen, false)
	world._span(_p(22.86, 1.36, 1.51), _p(23.72, 1.76, 1.53), linen, false)
	# Gradines, two steps up behind the altar.
	world._span(_p(23.7, 0.75, -1.5), _p(LENGTH, 1.92, 1.5), cream)
	world._span(_p(23.84, 1.92, -1.5), _p(LENGTH, 2.09, 1.5), cream)
	world._span(_p(23.695, 1.86, -1.5), _p(23.705, 1.9, 1.5), gold, false)
	world._span(_p(23.835, 2.03, -1.5), _p(23.845, 2.07, 1.5), gold, false)
	# Six tall candles, three either side of the tabernacle.
	for cz in [-1.3, -0.95, -0.6, 0.6, 0.95, 1.3]:
		var tall: float = 0.62 - absf(cz) * 0.12
		world._cyl(0.07, 0.05, _p(23.92, 2.115, cz), gold)
		world._cyl(0.022, tall * 0.55, _p(23.92, 2.14 + tall * 0.275, cz), gold)
		world._cyl(0.026, tall * 0.45, _p(23.92, 2.14 + tall * 0.55 + tall * 0.225, cz), world._c("#efe6cf"))
		world._span(_p(23.905, 2.14 + tall + 0.0, cz - 0.012), _p(23.935, 2.14 + tall + 0.07, cz + 0.012), world._g("#ffcf7a"), false)
	# The tabernacle in the middle, veiled, with its golden door.
	world._span(_p(23.2, 1.76, -0.34), _p(23.95, 2.5, 0.34), gold)
	world._span(_p(23.19, 1.8, -0.36), _p(23.22, 2.46, -0.2), world._c("#f2ede0"), false)
	world._span(_p(23.19, 1.8, 0.2), _p(23.22, 2.46, 0.36), world._c("#f2ede0"), false)
	world._span(_p(23.18, 1.9, -0.17), _p(23.2, 2.34, 0.17), bright_gold, false)
	world._span(_p(23.17, 2.05, -0.015), _p(23.18, 2.25, 0.015), world._c("#7a5a1a"), false)
	world._span(_p(23.17, 2.13, -0.07), _p(23.18, 2.16, 0.07), world._c("#7a5a1a"), false)
	world._cyl(0.3, 0.3, _p(23.57, 2.65, 0.0), gold, Vector3.ZERO, 0.05)
	world._span(_p(23.56, 2.8, -0.01), _p(23.58, 3.0, 0.01), bright_gold, false)
	world._span(_p(23.56, 2.92, -0.05), _p(23.58, 2.94, 0.05), bright_gold, false)
	# Altar cards and the missal on its stand, on the Epistle side.
	world._span(_p(23.3, 1.76, -0.16), _p(23.32, 1.98, 0.16), world._c("#e9e1c8"), false)
	for side in [-1.0, 1.0]:
		world._span(_p(23.3, 1.76, side * 1.05 - 0.09), _p(23.32, 1.92, side * 1.05 + 0.09), world._c("#e9e1c8"), false)
	world._span(_p(23.05, 1.76, 0.7), _p(23.4, 1.84, 1.05), gold, false)
	world._span(_p(23.02, 1.84, 0.68), _p(23.42, 1.89, 1.07), world._c("#6a1e26"), false)
	# The reredos: carved stone against the wall, with gilt arches.
	world._span(_p(23.95, 2.09, -2.4), _p(LENGTH, 6.2, 2.4), cream, false)
	for nz in [-1.6, 0.0, 1.6]:
		var half := 0.5 if nz == 0.0 else 0.38
		var top := 6.0 if nz == 0.0 else 5.3
		world._span(_p(23.93, 3.05, nz - half), _p(23.95, top, nz - half + 0.06), gold, false)
		world._span(_p(23.93, 3.05, nz + half - 0.06), _p(23.95, top, nz + half), gold, false)
		world._span(_p(23.93, top - 0.06, nz - half), _p(23.95, top, nz + half), gold, false)
		world._span(_p(23.935, 3.05, nz - half + 0.06), _p(23.945, top - 0.06, nz + half - 0.06), world._c("#7d2a32") if nz == 0.0 else world._c("#2d3f62"), false)
	world._span(_p(23.93, 2.95, -2.4), _p(23.95, 3.05, 2.4), gold, false)
	world._span(_p(23.93, 6.1, -2.4), _p(23.95, 6.2, 2.4), gold, false)
	# Statues in the side niches.
	for nz in [-1.6, 1.6]:
		world._cyl(0.16, 1.2, _p(23.78, 3.75, nz), world._c("#e8e0d0"), Vector3.ZERO, 0.11)
		world._span(_p(23.72, 4.35, nz - 0.08), _p(23.86, 4.55, nz + 0.08), world._c("#e3cdb0"), false)
	world._zone(_p(17.4, 0, -1.2), _p(17.8, 1.2, 1.2), "tabernacle")
	# Sanctuary lamp: the Lord is here.
	world._span(_p(20.6, 2.5, 1.85), _p(20.75, 2.7, 2.0), world._g("#e0303c"), false)
	world._span(_p(20.66, 2.7, 1.91), _p(20.69, HEIGHT, 1.94), world._c("#1c1a1f"), false)
	world._light(_p(20.67, 2.4, 1.92), "#e0303c", 0.8, 4.0)
	# The crucifix in the great middle arch, above the tabernacle.
	var cross := world._c("#2a1c14")
	var body := world._c("#d9c8a8")
	world._span(_p(23.82, 3.15, -0.08), _p(23.92, 5.85, 0.08), cross, false)
	world._span(_p(23.82, 5.0, -0.42), _p(23.92, 5.14, 0.42), cross, false)
	world._span(_p(23.76, 4.0, -0.07), _p(23.82, 5.0, 0.07), body, false)
	world._span(_p(23.76, 4.96, -0.36), _p(23.82, 5.04, 0.36), body, false)
	world._span(_p(23.76, 5.05, -0.06), _p(23.82, 5.22, 0.06), body, false)
	world._span(_p(23.75, 4.1, -0.08), _p(23.81, 4.35, 0.08), world._c("#c8bfae"), false)

	# The priest who says Mass, on the footpace facing the altar, his back to
	# the people. He is only there during Mass.
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	# He stands on a footing at the footpace's height: the rig's own height
	# is its walking bob, so it is kept at zero inside this.
	var footpace := Node3D.new()
	footpace.position = _p(22.45, 0.75, 0.0)
	world.add_child(footpace)
	celebrant = People.place(footpace, People.role("celebrant", rng), footpace.position, -PI / 2.0)
	celebrant.visible = false


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

	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	priest = People.place(world, People.role("priest", rng), _p(8.4, 0, -3.95), PI / 2.0)
	var talk := world._zone(Vector3(-0.3, 0.0, -0.3), Vector3(0.3, 1.8, 0.3), "priest", priest)
	talk.position.y = 0.9


func _side_things() -> void:
	var stone := world._m("concrete")
	# Holy water by the door.
	world._cyl(0.12, 0.95, _p(1.2, 0.475, 3.4), stone)
	world._cyl(0.3, 0.14, _p(1.2, 1.0, 3.4), stone, Vector3.ZERO, 0.22)
	world._span(_p(1.0, 1.07, 3.2), _p(1.4, 1.08, 3.6), world._g("#6f8fa0"), false)
	world._zone(_p(0.9, 0, 3.1), _p(1.5, 1.2, 3.7), "font")
	# The poor box by the door, for the parish and its poor.
	world._span(_p(2.2, 0, 3.75), _p(2.6, 1.05, 4.15), world._m("wood"))
	world._span(_p(2.18, 1.05, 3.73), _p(2.62, 1.12, 4.17), world._c("#6b5a3a"), false)
	world._span(_p(2.3, 1.12, 3.9), _p(2.5, 1.125, 3.98), world._c("#141214"), false)
	world._zone(_p(2.1, 0, 3.6), _p(2.7, 1.3, 4.2), "poor_box")
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

	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	informant = People.place(world, People.role("informant", rng), _p(1.6, 0, -4.2), -PI / 2.0)
	informant.visible = false


func _lights() -> void:
	for lx in [4.0, 10.0, 16.0]:
		world._light(_p(lx, 5.8, 0.0), "#ffd9a0", 1.1, 10.0)
	world._light(_p(21.0, 4.0, 0.0), "#ffe2b0", 1.4, 8.0)
	world._light(_p(23.2, 2.9, 0.0), "#ffcf7a", 0.9, 4.5)
	world._light(_p(15.7, 1.4, 3.6), "#ffb560", 0.6, 3.0)


## The Mass at the altar: "" (no Mass), "altar" (the priest at the altar)
## or "elevation" (the priest raising the Host over his head).
func set_mass(stage: String) -> void:
	celebrant.visible = not stage.is_empty()
	celebrant.hold_pose = "elevate" if stage == "elevation" else "rest"
	var host := celebrant.find_child("Host", true, false)
	if host != null:
		host.visible = stage == "elevation"


## Lights one more votive candle.
func light_votive() -> void:
	for flame in votive_flames:
		if not flame.visible:
			flame.visible = true
			return
