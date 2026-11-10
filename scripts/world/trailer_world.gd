class_name TrailerWorld
extends Node3D
## The trailer and the street around it, built in code so the layout is easy to
## change. X runs along the trailer: kitchen from 0, storage from 3.5, home from
## 6, bathroom from 9 to 11. Z runs across it, with the street side at 3.2.
## The trailer floor is at 0 and the street is lower, at GROUND.

const LENGTH := 11.0
const WIDTH := 3.2
const HEIGHT := 2.4
const GROUND := -0.45
const OUTER := 0.12
const ROOM_EDGES := [0.0, 3.5, 6.0, 9.0, 11.0]
const SPAWN := Vector3(8.6, 0.05, 1.5)
const SPAWN_YAW := PI / 2.0

## Render layers, as bit values.
const LAYER_WORLD := 1
const LAYER_BODY := 2
const LAYER_CCTV_ONLY := 4
const LAYER_MIRROR := 8
## Your own arm: seen only by your own eyes.
const LAYER_VIEWMODEL := 16
## Seen only in the mirror, never by your own eyes or the cameras.
const LAYER_REFLECTION := 32

const NIGHT_SKY := Color("#07050b")
const DAY_SKY := Color("#7d8088")
const NIGHT_AMBIENT := Color("#3b3350")
const DAY_AMBIENT := Color("#b4b3b8")
const NIGHT_FOG := Color("#120d19")
const DAY_FOG := Color("#6f7178")

var mirror: Mirror
## Places on the grill and counters where food can sit.
## Where food belongs: the grill, the serving counter and the prep board.
var surfaces: Array[Surface] = []
## Where the sauce bottles start.
const BOTTLE_HOMES := {"ketchup": Vector3(2.22, 0.95, 2.78), "mustard": Vector3(2.36, 0.95, 2.78), "mayo": Vector3(2.5, 0.95, 2.78)}
var cameras: Array[SecurityCamera] = []

var _environment: Environment
var _daylight := -1.0
var _interior_lights: Array[OmniLight3D] = []
var _lamp_meshes: Array[Node3D] = []
var _bathroom_light: OmniLight3D
var _griddle: MeshInstance3D
var _blacked_out := false
var _upgrades := {}
var _tv_screen: MeshInstance3D
var _tv_light: OmniLight3D
var _tv_wait := 0.0
## St. Brigid's, built out of sight of the street.
var church: Church
var _street_light: OmniLight3D
var _street_glow: Node3D
var _tower_light: OmniLight3D
var _tower_glow: Node3D
var _tower_timer := 0.0
var _shutter: Node3D
var _hatch_spill: OmniLight3D
var _candle_flame: Node3D
var _candle_light: OmniLight3D
var _crates: Node3D
var _figure: Sprite3D
var _flicker: Tween
var _rng := RandomNumberGenerator.new()


func build() -> void:
	_rng.seed = 11
	_build_environment()
	_build_shell()
	_build_kitchen()
	_build_storage()
	_build_home()
	_build_bathroom()
	_build_outside()
	_build_street()
	_build_cameras()
	church = Church.new()
	church.build(self)
	set_daylight(0.0)


# Building blocks --------------------------------------------------------------

func _m(kind: String) -> Material:
	return TextureFactory.surface(kind)


func _c(hex: String) -> Material:
	return TextureFactory.plain(Color(hex))


func _g(hex: String) -> Material:
	return TextureFactory.glow(Color(hex))


func _box(size: Vector3, center: Vector3, material: Material, collide := true, rot := Vector3.ZERO, parent: Node3D = null) -> Node3D:
	var holder: Node3D = parent if parent != null else self
	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh.mesh = box_mesh
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if not collide:
		mesh.position = center
		mesh.rotation_degrees = rot
		holder.add_child(mesh)
		return mesh
	var body := StaticBody3D.new()
	body.position = center
	body.rotation_degrees = rot
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.add_child(mesh)
	holder.add_child(body)
	return body


## A box between two corners.
func _span(a: Vector3, b: Vector3, material: Material, collide := true, parent: Node3D = null) -> Node3D:
	var low := Vector3(minf(a.x, b.x), minf(a.y, b.y), minf(a.z, b.z))
	var high := Vector3(maxf(a.x, b.x), maxf(a.y, b.y), maxf(a.z, b.z))
	return _box(high - low, (low + high) / 2.0, material, collide, Vector3.ZERO, parent)


func _cyl(radius: float, height: float, center: Vector3, material: Material, rot := Vector3.ZERO, top_radius := -1.0) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.bottom_radius = radius
	cylinder.top_radius = radius if top_radius < 0.0 else top_radius
	cylinder.height = height
	cylinder.radial_segments = 8
	cylinder.rings = 1
	mesh.mesh = cylinder
	mesh.material_override = material
	mesh.position = center
	mesh.rotation_degrees = rot
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)
	return mesh


## An invisible box the player can use. It also blocks walking.
func _surface(surface: Surface) -> void:
	add_child(surface)
	surfaces.append(surface)


## The food surface under a point, or null.
func surface_at(point: Vector3) -> Surface:
	for surface in surfaces:
		if surface.contains(point):
			return surface
	return null


func _zone(a: Vector3, b: Vector3, id: String, parent: Node3D = null) -> Interactable:
	var zone := Interactable.new()
	zone.id = id
	zone.position = (a + b) / 2.0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = (b - a).abs()
	shape.shape = box
	zone.add_child(shape)
	(parent if parent != null else self).add_child(zone)
	return zone


func _invisible(a: Vector3, b: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = (a + b) / 2.0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = (b - a).abs()
	shape.shape = box
	body.add_child(shape)
	add_child(body)


func _light(at: Vector3, hex: String, energy: float, reach: float, interior := true) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = at
	light.light_color = Color(hex)
	light.light_energy = energy
	light.omni_range = reach
	light.set_meta("base", energy)
	add_child(light)
	if interior:
		_interior_lights.append(light)
	return light


## Splits a wall from a to b around its openings. Each opening and each result
## is [from, to, bottom, top].
func _segments(a: float, b: float, openings: Array) -> Array:
	var inside := openings.filter(func(o: Array) -> bool: return o[0] >= a - 0.001 and o[1] <= b + 0.001)
	inside.sort_custom(func(p: Array, q: Array) -> bool: return p[0] < q[0])
	var result := []
	var cursor := a
	for o: Array in inside:
		if o[0] > cursor:
			result.append([cursor, o[0], 0.0, HEIGHT])
		if o[2] > 0.0:
			result.append([o[0], o[1], 0.0, o[2]])
		if o[3] < HEIGHT:
			result.append([o[0], o[1], o[3], HEIGHT])
		cursor = o[1]
	if cursor < b:
		result.append([cursor, b, 0.0, HEIGHT])
	return result


## One slab of wall. along_x walls run along X at z = plane; the others run
## along Z at x = plane. The slab goes from offset to offset + thickness in the
## outward direction.
func _slab(along_x: bool, plane: float, outward: float, seg: Array, thickness: float, offset: float, material: Material) -> void:
	var near := plane + outward * offset
	var far := plane + outward * (offset + thickness)
	if along_x:
		_span(Vector3(seg[0], seg[2], near), Vector3(seg[1], seg[3], far), material)
	else:
		_span(Vector3(near, seg[2], seg[0]), Vector3(far, seg[3], seg[1]), material)


## An outside wall: a panel on the inside and painted metal skin outside.
## spans are [from, to, inside material]. Long walls stretch their skin past the
## corners so the ends meet cleanly.
func _outer_wall(along_x: bool, plane: float, outward: float, spans: Array, openings: Array) -> void:
	var start: float = spans[0][0]
	var end: float = spans[-1][1]
	for span: Array in spans:
		for seg: Array in _segments(span[0], span[1], openings):
			_slab(along_x, plane, outward, seg, 0.06, 0.0, _m(span[2]))
			var skin: Array = seg.duplicate()
			if skin[2] <= 0.0:
				skin[2] = -0.3
			if skin[3] >= HEIGHT:
				skin[3] = HEIGHT + 0.06
			if along_x and is_equal_approx(skin[0], start):
				skin[0] -= OUTER
			if along_x and is_equal_approx(skin[1], end):
				skin[1] += OUTER
			_slab(along_x, plane, outward, skin, 0.06, 0.06, _m("skin"))
	for o: Array in openings:
		_frame(along_x, plane, plane + outward * OUTER, o)


## A wall between rooms, with a different surface on each side.
func _partition(along_x: bool, plane: float, a: float, b: float, openings: Array, low_side: String, high_side: String) -> void:
	for seg: Array in _segments(a, b, openings):
		_slab(along_x, plane, -1.0, seg, 0.04, 0.0, _m(low_side))
		_slab(along_x, plane, 1.0, seg, 0.04, 0.0, _m(high_side))
	for o: Array in openings:
		_frame(along_x, plane - 0.04, plane + 0.04, o)


## Trim around an opening, covering the wall's cut edges.
func _frame(along_x: bool, face_a: float, face_b: float, o: Array) -> void:
	var low := minf(face_a, face_b) - 0.015
	var high := maxf(face_a, face_b) + 0.015
	var trim := _c("#2e2420")
	var pieces := [
		[o[0] - 0.05, o[0], o[2], o[3]],
		[o[1], o[1] + 0.05, o[2], o[3]],
		[o[0] - 0.05, o[1] + 0.05, o[3], o[3] + 0.05],
	]
	if o[2] > 0.0:
		pieces.append([o[0] - 0.05, o[1] + 0.05, o[2] - 0.04, o[2]])
	for p: Array in pieces:
		if along_x:
			_span(Vector3(p[0], p[2], low), Vector3(p[1], p[3], high), trim, false)
		else:
			_span(Vector3(low, p[2], p[0]), Vector3(high, p[3], p[1]), trim, false)


func _lamp_mesh(node: Node3D) -> void:
	_lamp_meshes.append(node)


# Environment ------------------------------------------------------------------

func _build_environment() -> void:
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_COLOR
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_environment.fog_enabled = true
	_environment.fog_density = 0.03
	var holder := WorldEnvironment.new()
	holder.environment = _environment
	add_child(holder)


## Shows what you have bought: the street TV, the neon sign, the pro griddle.
func apply_upgrades(owned: Dictionary) -> void:
	for id: String in owned:
		if not owned[id] or _upgrades.has(id):
			continue
		_upgrades[id] = true
		match id:
			"tv":
				_span(Vector3(3.25, 1.45, WIDTH + 0.13), Vector3(4.05, 1.95, WIDTH + 0.2), _c("#141216"), false)
				_tv_screen = _span(Vector3(3.29, 1.49, WIDTH + 0.2), Vector3(4.01, 1.91, WIDTH + 0.205), _g("#6f9fd0"), false) as MeshInstance3D
				_span(Vector3(3.6, 1.95, WIDTH + 0.12), Vector3(3.7, 2.2, WIDTH + 0.16), _c("#2b2b30"), false)
				_tv_light = _light(Vector3(3.65, 1.7, WIDTH + 0.6), "#7fb0e0", 0.5, 2.5, false)
			"neon":
				var neon := Label3D.new()
				neon.text = "OPEN LATE"
				neon.font = UiKit.title_font()
				neon.font_size = 96
				neon.pixel_size = 0.004
				neon.modulate = Color("#ff5fa8")
				neon.outline_size = 12
				neon.outline_modulate = Color("#ff5fa8", 0.35)
				neon.position = Vector3(4.9, HEIGHT + 0.55, WIDTH + 0.13)
				add_child(neon)
				_light(Vector3(4.9, HEIGHT + 0.5, WIDTH + 0.8), "#ff5fa8", 0.9, 4.0, false)
			"grill":
				_griddle.material_override = TextureFactory.plain(Color("#5a5e63"), 0.35)


## Inside St. Brigid's the air is clear; outside the city haze closes in.
func set_in_church(inside: bool) -> void:
	_environment.fog_density = 0.008 if inside else 0.03


## 0 is night, 1 is a grey overcast day.
func set_daylight(amount: float) -> void:
	if is_equal_approx(amount, _daylight):
		return
	_daylight = amount
	_environment.background_color = NIGHT_SKY.lerp(DAY_SKY, amount)
	_environment.ambient_light_color = NIGHT_AMBIENT.lerp(DAY_AMBIENT, amount)
	_environment.ambient_light_energy = 0.04 if _blacked_out else lerpf(0.55, 1.0, amount)
	_environment.fog_light_color = NIGHT_FOG.lerp(DAY_FOG, amount)
	var lamps_on := amount < 0.6
	_street_light.visible = lamps_on
	_street_glow.visible = lamps_on


# The shell --------------------------------------------------------------------

func _build_shell() -> void:
	_span(Vector3(0.0, -0.06, 0.0), Vector3(3.5, 0.0, WIDTH), _m("floor_check"))
	_span(Vector3(3.5, -0.06, 0.0), Vector3(6.0, 0.0, WIDTH), _m("floor_lino"))
	_span(Vector3(6.0, -0.06, 0.0), Vector3(9.0, 0.0, WIDTH), _m("floor_planks"))
	_span(Vector3(9.0, -0.06, 1.8), Vector3(LENGTH, 0.0, WIDTH), _m("floor_planks"))
	_span(Vector3(9.0, -0.06, 0.0), Vector3(LENGTH, 0.0, 1.8), _m("floor_tiles"))
	_span(Vector3(4.4, -0.06, WIDTH), Vector3(5.3, 0.0, WIDTH + OUTER + 0.02), _m("floor_lino"))
	for i in 4:
		var a: float = ROOM_EDGES[i]
		var b: float = ROOM_EDGES[i + 1]
		_span(Vector3(a, HEIGHT, 0.0), Vector3(b, HEIGHT + 0.05, WIDTH), _m("ceiling"), false)
		var roof_a := a - (0.14 if i == 0 else 0.0)
		var roof_b := b + (0.14 if i == 3 else 0.0)
		_span(Vector3(roof_a, HEIGHT + 0.05, -0.14), Vector3(roof_b, HEIGHT + 0.2, WIDTH + 0.14), _m("roof"))

	var street_side := [[0.5, 3.0, 1.0, 1.9], [4.4, 5.3, 0.0, 2.0], [7.9, 8.7, 1.0, 1.75]]
	_outer_wall(true, WIDTH, 1.0, [[0.0, 3.5, "wall_kitchen"], [3.5, 6.0, "wall_panel"], [6.0, 9.0, "wallpaper"], [9.0, LENGTH, "wallpaper"]], street_side)
	_outer_wall(true, 0.0, -1.0, [[0.0, 3.5, "wall_kitchen"], [3.5, 6.0, "wall_panel"], [6.0, 9.0, "wallpaper"], [9.0, LENGTH, "wall_bath"]], [])
	_outer_wall(false, 0.0, -1.0, [[0.0, WIDTH, "wall_kitchen"]], [])
	_outer_wall(false, LENGTH, 1.0, [[0.0, 1.8, "wall_bath"], [1.8, WIDTH, "wallpaper"]], [])

	_partition(false, 3.5, 0.0, WIDTH, [[0.6, 2.6, 0.0, 2.1]], "wall_kitchen", "wall_panel")
	_partition(false, 6.0, 0.0, WIDTH, [[1.15, 2.0, 0.0, 2.0]], "wall_panel", "wallpaper")
	_partition(false, 9.0, 0.0, 1.8, [[0.95, 1.75, 0.0, 2.0]], "wallpaper", "wall_bath")
	_partition(true, 1.8, 8.96, LENGTH, [], "wall_bath", "wallpaper")

	var entrance := Door.create(0.86, 1.98, _m("skin"), 0.0, -100.0)
	entrance.position = Vector3(4.42, 0.0, WIDTH + 0.06)
	add_child(entrance)
	var home_door := Door.create(0.81, 1.98, _m("wood"), -90.0, 0.0)
	home_door.position = Vector3(6.0, 0.0, 1.17)
	add_child(home_door)
	var bath_door := Door.create(0.76, 1.98, _c("#d4d0c4"), 90.0, 180.0)
	bath_door.position = Vector3(9.0, 0.0, 1.73)
	add_child(bath_door)


# Kitchen ----------------------------------------------------------------------

func _build_kitchen() -> void:
	var steel := _m("steel")
	var dark := _m("steel_dark")
	# Serving counter under the hatch.
	_span(Vector3(0.3, 0.0, 2.62), Vector3(3.3, 0.9, WIDTH), steel)
	_span(Vector3(0.28, 0.9, 2.58), Vector3(3.32, 0.95, WIDTH), steel, false)
	for x in [1.05, 2.15, 2.55]:
		_span(Vector3(x - 0.01, 0.08, 2.605), Vector3(x + 0.01, 0.84, 2.62), dark, false)
	# Griddle with four places to cook.
	_span(Vector3(1.25, 0.95, 2.68), Vector3(2.05, 1.0, 3.12), dark, false)
	_griddle = _span(Vector3(1.28, 1.0, 2.71), Vector3(2.02, 1.006, 3.09), _c("#1b1a1c"), false) as MeshInstance3D
	_surface(Surface.create("grill", "grill", "grill", 1.28, 2.02, 2.71, 3.09, 1.006))
	# Fridge drawers for sausages and patties, under the griddle.
	for drawer: Array in [[1.27, 1.63, "take_sausage", "SAUSAGES"], [1.67, 2.03, "take_patty", "PATTIES"]]:
		_span(Vector3(drawer[0], 0.4, 2.6), Vector3(drawer[1], 0.85, 2.62), _m("steel"), false)
		_span(Vector3(drawer[0] + 0.08, 0.76, 2.585), Vector3(drawer[1] - 0.08, 0.79, 2.6), dark, false)
		var tag := Label3D.new()
		tag.text = drawer[3]
		tag.font = UiKit.body_font()
		tag.font_size = 32
		tag.pixel_size = 0.0011
		tag.modulate = Color("#2a2226")
		tag.outline_size = 0
		tag.shaded = true
		tag.position = Vector3((drawer[0] + drawer[1]) / 2.0, 0.62, 2.598)
		tag.rotation_degrees.y = 180.0
		add_child(tag)
		_zone(Vector3(drawer[0], 0.35, 2.5), Vector3(drawer[1], 0.88, 2.6), drawer[2])
	# Bread roll bin.
	_span(Vector3(0.4, 0.95, 2.72), Vector3(0.82, 1.1, 3.1), _m("wood_light"), false)
	for i in 3:
		_span(Vector3(0.45 + i * 0.12, 1.1, 2.82), Vector3(0.54 + i * 0.12, 1.15, 2.95), _c("#c48c4c"), false)
	_zone(Vector3(0.4, 0.95, 2.68), Vector3(0.82, 1.18, 3.12), "take_bun")
	# The serving counter either side of the grill; the sauces start on the right.
	_surface(Surface.create("serving", "serving counter", "prep", 0.84, 1.26, 2.6, 3.18, 0.95))
	_surface(Surface.create("serving", "serving counter", "prep", 2.06, 2.6, 2.6, 3.18, 0.95))
	# Till.
	_span(Vector3(2.6, 0.95, 2.72), Vector3(3.05, 1.1, 3.08), _c("#2a2a2e"), false)
	_box(Vector3(0.3, 0.13, 0.02), Vector3(2.82, 1.18, 2.84), _g("#3e8a63"), false, Vector3(-30.0, 0.0, 0.0))
	# Lever that opens and closes the hatch shutter.
	_span(Vector3(3.15, 1.25, WIDTH - 0.04), Vector3(3.3, 1.6, WIDTH - 0.01), _c("#2b2b30"), false)
	_box(Vector3(0.03, 0.18, 0.03), Vector3(3.22, 1.5, WIDTH - 0.07), _c("#a3302c"), false, Vector3(25.0, 0.0, 0.0))
	_zone(Vector3(3.1, 1.2, WIDTH - 0.15), Vector3(3.35, 1.65, WIDTH), "hatch")
	# Kitchen bin, by the grill where you need it, and labelled.
	_cyl(0.2, 0.7, Vector3(3.1, 0.35, 2.3), _c("#2f6b45"))
	_cyl(0.21, 0.04, Vector3(3.1, 0.72, 2.3), _c("#1f4a30"))
	_span(Vector3(3.06, 0.74, 2.12), Vector3(3.14, 0.76, 2.2), _c("#9aa3a0"), false)
	var bin_tag := Label3D.new()
	bin_tag.text = "BIN"
	bin_tag.font = UiKit.title_font()
	bin_tag.font_size = 64
	bin_tag.pixel_size = 0.0025
	bin_tag.modulate = Color("#e6e0d2")
	bin_tag.position = Vector3(2.89, 0.5, 2.3)
	bin_tag.rotation_degrees.y = -90.0
	add_child(bin_tag)
	_zone(Vector3(2.88, 0.0, 2.08), Vector3(3.32, 0.78, 2.52), "bin")

	# Prep counter, kettle and fryer along the back wall.
	_span(Vector3(0.3, 0.0, 0.0), Vector3(2.3, 0.9, 0.62), steel)
	_span(Vector3(0.28, 0.9, 0.0), Vector3(2.32, 0.95, 0.64), steel, false)
	_cyl(0.08, 0.2, Vector3(0.72, 1.05, 0.3), _c("#2b2b30"))
	_cyl(0.035, 0.08, Vector3(0.95, 0.99, 0.35), _c("#a8382f"))
	_cyl(0.035, 0.08, Vector3(1.05, 0.99, 0.25), _c("#d8d2c0"))
	_zone(Vector3(0.5, 0.9, 0.08), Vector3(1.15, 1.22, 0.58), "coffee")
	_span(Vector3(1.18, 0.95, 0.12), Vector3(2.08, 0.965, 0.52), _m("wood_light"), false)
	_surface(Surface.create("prep", "prep board", "prep", 1.18, 2.08, 0.12, 0.52, 0.965))
	_span(Vector3(1.4, 1.6, 0.0), Vector3(2.2, 1.63, 0.03), _c("#2b2b30"), false)
	for i in 4:
		var x := 1.5 + i * 0.18
		_span(Vector3(x, 1.38, 0.03), Vector3(x + 0.025, 1.6, 0.04), steel, false)
	_span(Vector3(0.3, 1.75, 0.0), Vector3(2.3, 1.78, 0.3), _m("wood"), false)
	for i in 6:
		var colour: String = ["#6d4a2b", "#a33b2a", "#c9b46a", "#4f6b3a", "#d8d0bc", "#7a2f2f"][i]
		_cyl(0.05, 0.16, Vector3(0.45 + i * 0.3, 1.86, 0.15), _c(colour))
	_span(Vector3(2.35, 0.0, 0.0), Vector3(2.95, 0.95, 0.62), steel)
	_span(Vector3(2.42, 0.95, 0.08), Vector3(2.88, 0.965, 0.54), _c("#3b2a12"), false)
	_span(Vector3(2.5, 1.0, 0.25), Vector3(2.62, 1.25, 0.27), dark, false)

	# Drinks cooler against the front wall.
	_span(Vector3(0.0, 0.0, 1.1), Vector3(0.55, 1.85, 1.9), _c("#a12a2b"), false)
	_span(Vector3(0.55, 0.15, 1.17), Vector3(0.56, 1.62, 1.83), _g("#8fc2d2"), false)
	for y in [0.5, 0.88, 1.26]:
		_span(Vector3(0.56, y, 1.17), Vector3(0.565, y + 0.02, 1.83), _c("#33363b"), false)
	_zone(Vector3(0.0, 0.0, 1.1), Vector3(0.6, 1.85, 1.9), "cooler")

	# Fluorescent tubes.
	_lamp_mesh(_span(Vector3(1.0, 2.36, 1.5), Vector3(1.8, 2.4, 1.7), _g("#e9f2dc"), false))
	_lamp_mesh(_span(Vector3(2.0, 2.36, 1.5), Vector3(2.8, 2.4, 1.7), _g("#e9f2dc"), false))
	_light(Vector3(1.9, 2.15, 1.6), "#eef2dd", 1.4, 3.6)


# Storage ----------------------------------------------------------------------

func _build_storage() -> void:
	var wood := _m("wood")
	for x in [3.62, 4.72, 5.82]:
		_span(Vector3(x, 0.0, 0.02), Vector3(x + 0.04, 1.85, 0.06), wood, false)
		_span(Vector3(x, 0.0, 0.43), Vector3(x + 0.04, 1.85, 0.47), wood, false)
	for y in [0.12, 0.67, 1.22, 1.77]:
		_span(Vector3(3.6, y, 0.0), Vector3(5.86, y + 0.03, 0.48), wood, false)
		if y > 1.7:
			continue
		var x := 3.68
		while x < 5.7:
			var w := _rng.randf_range(0.28, 0.5)
			if x + w > 5.8:
				break
			var h := _rng.randf_range(0.2, 0.45)
			_span(Vector3(x, y + 0.03, 0.05), Vector3(x + w, y + 0.03 + h, 0.05 + _rng.randf_range(0.32, 0.42)), _m("cardboard"), false)
			x += w + _rng.randf_range(0.02, 0.1)
	_zone(Vector3(3.6, 0.0, 0.0), Vector3(5.86, 1.85, 0.5), "shelves")

	# Fridge.
	var plastic := _m("plastic")
	_span(Vector3(5.35, 0.0, 2.58), Vector3(5.95, 1.8, 3.16), plastic, false)
	_span(Vector3(5.36, 1.19, 2.57), Vector3(5.94, 1.21, 2.58), _c("#55534d"), false)
	_span(Vector3(5.4, 0.7, 2.54), Vector3(5.43, 1.05, 2.57), _c("#3a3a3e"), false)
	_span(Vector3(5.4, 1.3, 2.54), Vector3(5.43, 1.6, 2.57), _c("#3a3a3e"), false)
	_zone(Vector3(5.35, 0.0, 2.54), Vector3(5.95, 1.8, 3.18), "fridge")
	# Chest freezer, mop bucket.
	_span(Vector3(3.6, 0.0, 2.55), Vector3(4.35, 0.85, 3.18), plastic)
	_span(Vector3(3.6, 0.7, 2.545), Vector3(4.35, 0.715, 2.55), _c("#55534d"), false)
	_cyl(0.16, 0.3, Vector3(3.8, 0.15, 2.25), _c("#c9a227"))
	_box(Vector3(0.03, 1.3, 0.03), Vector3(3.85, 0.75, 2.3), _m("wood_light"), false, Vector3(0.0, 0.0, -12.0))

	# Civic notice by the freezer.
	_span(Vector3(3.7, 1.15, WIDTH - 0.012), Vector3(4.25, 1.85, WIDTH - 0.002), _c("#c9c1a8"), false)
	var notice := Label3D.new()
	notice.text = "CIVIC NOTICE\n\nReport any\nsuspicious\nneighbour.\n\nYou are\nnot alone."
	notice.font = UiKit.body_font()
	notice.font_size = 40
	notice.pixel_size = 0.0011
	notice.modulate = Color("#2a2226")
	notice.outline_size = 0
	notice.shaded = true
	notice.position = Vector3(3.975, 1.5, WIDTH - 0.014)
	notice.rotation_degrees.y = 180.0
	add_child(notice)

	_lamp_mesh(_cyl(0.06, 0.12, Vector3(4.75, 2.32, 1.6), _g("#ffd9a0")))
	_light(Vector3(4.75, 2.15, 1.6), "#ffc98a", 1.0, 3.3)


# Home -------------------------------------------------------------------------

func _build_home() -> void:
	var wood := _m("wood")
	# Desk and computer.
	_span(Vector3(6.35, 0.72, 0.0), Vector3(7.65, 0.76, 0.62), wood, false)
	for corner in [Vector2(6.38, 0.03), Vector2(7.58, 0.03), Vector2(6.38, 0.55), Vector2(7.58, 0.55)]:
		_span(Vector3(corner.x, 0.0, corner.y), Vector3(corner.x + 0.04, 0.72, corner.y + 0.04), wood, false)
	_span(Vector3(6.75, 0.76, 0.06), Vector3(7.25, 1.2, 0.5), _c("#c9c0a8"), false)
	_span(Vector3(6.8, 0.83, 0.5), Vector3(7.2, 1.13, 0.515), _g("#3f9a80"), false)
	_span(Vector3(6.75, 0.76, 0.53), Vector3(7.25, 0.785, 0.64), _c("#bdb39b"), false)
	_zone(Vector3(6.35, 0.0, 0.0), Vector3(7.65, 1.2, 0.66), "computer")
	_light(Vector3(7.0, 1.0, 0.8), "#5fd1ae", 0.35, 1.6, false)
	var chair := _c("#3a2a22")
	_span(Vector3(6.78, 0.42, 0.8), Vector3(7.22, 0.47, 1.2), chair)
	_span(Vector3(6.78, 0.47, 1.16), Vector3(7.22, 0.95, 1.2), chair, false)
	for corner in [Vector2(6.79, 0.81), Vector2(7.18, 0.81), Vector2(6.79, 1.16), Vector2(7.18, 1.16)]:
		_span(Vector3(corner.x, 0.0, corner.y), Vector3(corner.x + 0.03, 0.42, corner.y + 0.03), chair, false)
	# Holy picture above the desk.
	_span(Vector3(6.6, 1.45, 0.0), Vector3(7.4, 1.95, 0.03), wood, false)
	_span(Vector3(6.66, 1.51, 0.03), Vector3(7.34, 1.89, 0.035), _c("#6d2a2d"), false)
	_span(Vector3(6.95, 1.62, 0.035), Vector3(7.05, 1.74, 0.04), _c("#d7bd6a"), false)

	# Wall calendar beside the door.
	_span(Vector3(6.04, 1.2, 0.3), Vector3(6.05, 1.85, 0.8), _c("#d9d1bb"), false)
	_span(Vector3(6.05, 1.62, 0.33), Vector3(6.055, 1.82, 0.77), _c("#6d2a2d"), false)
	var month := Label3D.new()
	month.text = "JANUARY 2050"
	month.font = UiKit.body_font()
	month.font_size = 36
	month.pixel_size = 0.0011
	month.modulate = Color("#efe0bf")
	month.outline_size = 0
	month.position = Vector3(6.058, 1.72, 0.55)
	month.rotation_degrees.y = 90.0
	add_child(month)
	for row in 5:
		for col in 7:
			_span(Vector3(6.05, 1.55 - row * 0.065, 0.35 + col * 0.06), Vector3(6.053, 1.5 - row * 0.065, 0.39 + col * 0.06), _c("#9c937d" if col > 0 else "#a3302c"), false)
	_zone(Vector3(6.04, 1.15, 0.25), Vector3(6.14, 1.9, 0.85), "calendar")

	# Bed under the window.
	_span(Vector3(7.3, 0.0, 2.3), Vector3(9.3, 0.3, WIDTH), wood, false)
	_span(Vector3(7.32, 0.3, 2.32), Vector3(9.28, 0.48, 3.18), _m("mattress"), false)
	_span(Vector3(7.3, 0.48, 2.28), Vector3(8.75, 0.53, WIDTH - 0.01), _m("fabric"), false)
	_span(Vector3(8.82, 0.48, 2.45), Vector3(9.2, 0.6, 3.05), _c("#d9d4c6"), false)
	_span(Vector3(9.26, 0.0, 2.3), Vector3(9.32, 0.95, WIDTH), wood, false)
	_zone(Vector3(7.3, 0.0, 2.3), Vector3(9.32, 0.62, WIDTH), "bed")
	# Window and curtains.
	var glass := MeshInstance3D.new()
	var pane := QuadMesh.new()
	pane.size = Vector2(0.8, 0.75)
	glass.mesh = pane
	var glass_material := StandardMaterial3D.new()
	glass_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_material.albedo_color = Color(0.12, 0.15, 0.22, 0.45)
	glass_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	glass_material.metallic_specular = 0.8
	glass_material.roughness = 0.1
	glass.material_override = glass_material
	glass.position = Vector3(8.3, 1.375, WIDTH + 0.06)
	add_child(glass)
	_span(Vector3(7.72, 1.88, WIDTH - 0.06), Vector3(8.88, 1.9, WIDTH - 0.04), _c("#2b2b30"), false)
	_span(Vector3(7.72, 0.95, WIDTH - 0.08), Vector3(7.95, 1.88, WIDTH - 0.05), _m("fabric"), false)
	_span(Vector3(8.65, 0.95, WIDTH - 0.08), Vector3(8.88, 1.88, WIDTH - 0.05), _m("fabric"), false)

	# Wardrobe and rug.
	_span(Vector3(6.04, 0.0, 2.4), Vector3(6.64, 1.9, WIDTH), wood)
	_span(Vector3(6.64, 0.05, 2.79), Vector3(6.645, 1.85, 2.81), _c("#1e1612"), false)
	_span(Vector3(6.8, 0.0, 1.0), Vector3(8.9, 0.006, 2.2), _m("rug"), false)

	# Home altar in the corner by the bathroom.
	_span(Vector3(10.55, 0.0, 2.15), Vector3(11.0, 0.8, 2.95), wood, false)
	_span(Vector3(10.52, 0.8, 2.12), Vector3(11.0, 0.82, 2.98), _c("#e8e2d4"), false)
	_span(Vector3(10.97, 1.2, 2.53), Vector3(10.995, 1.85, 2.57), wood, false)
	_span(Vector3(10.97, 1.62, 2.4), Vector3(10.995, 1.67, 2.7), wood, false)
	_span(Vector3(10.955, 1.32, 2.535), Vector3(10.97, 1.62, 2.565), _c("#d9cbb3"), false)
	_span(Vector3(10.955, 1.6, 2.43), Vector3(10.97, 1.635, 2.67), _c("#d9cbb3"), false)
	_cyl(0.045, 0.28, Vector3(10.8, 0.96, 2.75), _c("#4d6fa8"))
	_cyl(0.03, 0.06, Vector3(10.8, 1.13, 2.75), _c("#e3d6c2"))
	_cyl(0.025, 0.16, Vector3(10.75, 0.9, 2.35), _c("#ece6d5"))
	_candle_flame = _span(Vector3(10.74, 0.98, 2.34), Vector3(10.76, 1.02, 2.36), _g("#ffb347"), false)
	_candle_light = _light(Vector3(10.75, 1.1, 2.35), "#ff9a3c", 0.7, 2.4, false)
	_span(Vector3(10.15, 0.0, 2.3), Vector3(10.45, 0.12, 2.8), _m("fabric"), false)
	_zone(Vector3(10.5, 0.0, 2.1), Vector3(11.0, 1.9, 3.0), "altar")
	set_candle_lit(false)

	# Ceiling lamp.
	_cyl(0.18, 0.12, Vector3(7.9, 2.3, 1.6), _c("#cdbf9c"), Vector3.ZERO, 0.1)
	_lamp_mesh(_cyl(0.05, 0.06, Vector3(7.9, 2.22, 1.6), _g("#ffe2b0")))
	_light(Vector3(7.9, 2.1, 1.6), "#ffbf7a", 1.1, 3.2)


# Bathroom ---------------------------------------------------------------------

func _build_bathroom() -> void:
	var plastic := _m("plastic")
	_span(Vector3(10.25, 0.0, 0.12), Vector3(10.6, 0.4, 0.62), plastic)
	_span(Vector3(10.23, 0.4, 0.18), Vector3(10.62, 0.44, 0.66), _c("#ecebe4"), false)
	_span(Vector3(10.18, 0.4, 0.0), Vector3(10.67, 0.78, 0.2), plastic)
	# Sink and mirror.
	_span(Vector3(10.6, 0.0, 1.0), Vector3(11.0, 0.8, 1.55), plastic, false)
	_span(Vector3(10.56, 0.8, 0.98), Vector3(11.0, 0.86, 1.57), _c("#e6e6e0"), false)
	_span(Vector3(10.65, 0.861, 1.08), Vector3(10.92, 0.866, 1.47), _c("#8f989b"), false)
	_cyl(0.015, 0.14, Vector3(10.94, 0.93, 1.275), _m("steel"))
	_zone(Vector3(10.55, 0.0, 0.97), Vector3(11.0, 0.95, 1.58), "sink")
	mirror = Mirror.new()
	mirror.position = Vector3(LENGTH - 0.01, 1.6, 1.275)
	mirror.rotation_degrees.y = -90.0
	add_child(mirror)
	mirror.setup(0.5, 0.62)
	var frame := _m("steel")
	_span(Vector3(10.975, 1.26, 0.99), Vector3(11.0, 1.94, 1.02), frame, false)
	_span(Vector3(10.975, 1.26, 1.53), Vector3(11.0, 1.94, 1.56), frame, false)
	_span(Vector3(10.975, 1.26, 0.99), Vector3(11.0, 1.29, 1.56), frame, false)
	_span(Vector3(10.975, 1.91, 0.99), Vector3(11.0, 1.94, 1.56), frame, false)
	# Shower in the corner behind the door: a tray, a curtain on a rail, a head on the wall.
	_span(Vector3(9.04, 0.0, 0.04), Vector3(9.92, 0.07, 0.92), _c("#d8d6cf"), false)
	_span(Vector3(9.4, 0.071, 0.4), Vector3(9.56, 0.075, 0.56), _c("#5d6366"), false)
	_span(Vector3(9.92, 2.02, 0.04), Vector3(9.94, 2.04, 0.94), _m("steel"), false)
	_span(Vector3(9.04, 2.02, 0.92), Vector3(9.94, 2.04, 0.94), _m("steel"), false)
	var curtain := _c("#7d8a6b")
	_span(Vector3(9.91, 0.18, 0.04), Vector3(9.93, 2.02, 0.92), curtain, false)
	_span(Vector3(9.04, 0.18, 0.91), Vector3(9.42, 2.02, 0.93), curtain, false)
	for k in 8:
		_span(Vector3(9.905, 0.18, 0.08 + k * 0.11), Vector3(9.935, 2.02, 0.1 + k * 0.11), _c("#66735a"), false)
	_cyl(0.012, 0.6, Vector3(9.12, 1.75, 0.3), _m("steel"))
	_box(Vector3(0.025, 0.025, 0.22), Vector3(9.15, 2.04, 0.2), _m("steel"), false, Vector3(-20.0, 0.0, 0.0))
	_cyl(0.05, 0.03, Vector3(9.15, 2.0, 0.3), _m("steel"))
	_span(Vector3(9.04, 1.0, 0.6), Vector3(9.07, 1.12, 0.7), _m("steel"), false)
	_zone(Vector3(9.04, 0.0, 0.04), Vector3(9.9, 2.0, 0.9), "shower")

	# Towel and light.
	_span(Vector3(9.9, 1.0, 1.74), Vector3(10.3, 1.45, 1.76), _c("#3d5f7e"), false)
	_lamp_mesh(_span(Vector3(10.0, 2.36, 0.85), Vector3(10.5, 2.4, 0.95), _g("#dfeef5"), false))
	_bathroom_light = _light(Vector3(10.25, 2.15, 0.9), "#d6e6ef", 0.9, 2.4)


# Outside the trailer ----------------------------------------------------------

func _build_outside() -> void:
	var dark := _m("steel_dark")
	_span(Vector3(0.12, GROUND, 0.12), Vector3(LENGTH - 0.12, -0.06, WIDTH - 0.12), _m("skirt"))
	for x in [6.9, 7.65]:
		for z in [-0.03, WIDTH + 0.03]:
			_cyl(0.34, 0.24, Vector3(x, GROUND + 0.34, z), _m("rubber"), Vector3(90.0, 0.0, 0.0))
			_cyl(0.15, 0.25, Vector3(x, GROUND + 0.34, z), _m("steel"), Vector3(90.0, 0.0, 0.0))
		_span(Vector3(x - 0.42, -0.12, -0.2), Vector3(x + 0.42, -0.06, WIDTH + 0.2), dark, false)
	# Hitch, jack and gas bottles at the front.
	_span(Vector3(-1.5, -0.22, 1.5), Vector3(0.0, -0.1, 1.7), dark, false)
	_cyl(0.04, 0.3, Vector3(-1.2, GROUND + 0.15, 1.6), dark)
	_cyl(0.14, 0.6, Vector3(-0.3, GROUND + 0.3, 0.6), _c("#a3302c"))
	_cyl(0.14, 0.6, Vector3(-0.3, GROUND + 0.3, 0.95), _c("#a3302c"))

	# Ramp up to the door.
	var ramp_length := 1.38
	_box(Vector3(1.0, 0.06, ramp_length), Vector3(4.85, -0.255, WIDTH + 0.14 + 0.65), dark, true, Vector3(19.1, 0.0, 0.0))
	# Lamp over the door.
	_span(Vector3(5.45, 2.08, WIDTH + 0.12), Vector3(5.6, 2.22, WIDTH + 0.22), _c("#2b2b30"), false)
	_lamp_mesh(_span(Vector3(5.47, 2.06, WIDTH + 0.14), Vector3(5.58, 2.09, WIDTH + 0.21), _g("#ffd28a"), false))
	_light(Vector3(5.52, 1.95, WIDTH + 0.45), "#ffc77a", 0.7, 3.4)

	# Hatch: ledge, shutter, awning and sign.
	_span(Vector3(0.5, 0.97, WIDTH + OUTER), Vector3(3.0, 1.0, WIDTH + 0.35), _m("steel"), false)
	_shutter = Node3D.new()
	_shutter.position = Vector3(1.75, 1.93, WIDTH + OUTER + 0.02)
	add_child(_shutter)
	_box(Vector3(2.6, 0.97, 0.03), Vector3(0.0, -0.485, 0.015), _m("skin"), false, Vector3.ZERO, _shutter)
	_hatch_spill = _light(Vector3(1.75, 1.4, WIDTH + 0.8), "#ffd08a", 0.9, 3.6, false)
	for i in 9:
		var colour := "#8a2c33" if i % 2 == 0 else "#c7b995"
		var x := 0.55 + i * 0.3
		_box(Vector3(0.3, 0.025, 0.95), Vector3(x, 2.13, WIDTH + OUTER + 0.46), _c(colour), false, Vector3(14.0, 0.0, 0.0))
		_box(Vector3(0.3, 0.12, 0.02), Vector3(x, 1.96, WIDTH + OUTER + 0.93), _c(colour), false)
	_span(Vector3(0.4, HEIGHT + 0.2, WIDTH + 0.06), Vector3(3.1, HEIGHT + 0.65, WIDTH + 0.12), _c("#5a1f25"), false)
	var sign_text := Label3D.new()
	sign_text.text = "Daily Bread"
	sign_text.font = UiKit.title_font()
	sign_text.font_size = 120
	sign_text.pixel_size = 0.0028
	sign_text.modulate = Color("#efe0bf")
	sign_text.outline_size = 0
	sign_text.position = Vector3(1.75, HEIGHT + 0.42, WIDTH + 0.125)
	add_child(sign_text)

	# Bin.
	_cyl(0.3, 0.9, Vector3(-0.6, GROUND + 0.45, 4.3), _c("#26352b"))
	_span(Vector3(-0.9, GROUND, 4.0), Vector3(-0.3, GROUND + 0.9, 4.6), _c("#26352b"), true).visible = false

	_crates = Node3D.new()
	add_child(_crates)


# The street -------------------------------------------------------------------

func _build_street() -> void:
	var asphalt := _m("asphalt")
	var gx := -24.0
	while gx < 40.0:
		var gz := -16.0
		while gz < 32.0:
			_span(Vector3(gx, GROUND - 0.3, gz), Vector3(gx + 8.0, GROUND, gz + 8.0), asphalt)
			gz += 8.0
		gx += 8.0
	# Kerb and pavement across the street.
	_span(Vector3(-24.0, GROUND, 17.5), Vector3(40.0, GROUND + 0.12, 21.0), _m("concrete"), false)

	# Street lamp.
	var pole := _c("#1e1d22")
	_cyl(0.07, 5.2, Vector3(3.0, GROUND + 2.6, 9.0), pole)
	_span(Vector3(2.96, 4.65, 8.35), Vector3(3.04, 4.72, 9.0), pole, false)
	_span(Vector3(2.85, 4.55, 8.25), Vector3(3.15, 4.65, 8.6), pole, false)
	_street_glow = _span(Vector3(2.9, 4.53, 8.3), Vector3(3.1, 4.55, 8.55), _g("#ffb35c"), false)
	_street_light = _light(Vector3(3.0, 4.4, 8.42), "#ffa04a", 4.0, 14.0, false)
	_invisible(Vector3(2.9, GROUND, 8.9), Vector3(3.1, 5.0, 9.1))

	# Buildings across the street, with a gap where the church street runs.
	var x := -34.0
	while x < 48.0:
		var w := _rng.randf_range(6.0, 12.0)
		if x + w > -10.0 and x < 0.0:
			x = 0.0
			continue
		var h := _rng.randf_range(7.0, 18.0)
		_span(Vector3(x, GROUND, 21.0), Vector3(x + w - 0.4, GROUND + h, 30.0), _m("concrete_dark"), false)
		var wy := GROUND + 2.0
		while wy < GROUND + h - 1.5:
			var wx := x + 0.8
			while wx < x + w - 1.6:
				if _rng.randf() < 0.16:
					var lit := "#e8b46a" if _rng.randf() < 0.7 else "#9fc4d8"
					_span(Vector3(wx, wy, 20.96), Vector3(wx + 0.8, wy + 1.1, 21.0), _g(lit), false)
				wx += 2.2
			wy += 3.0
		x += w
	# Behind the trailer: a wall and dark blocks.
	_span(Vector3(-20.0, GROUND, -5.4), Vector3(36.0, GROUND + 3.0, -5.0), _m("concrete"))
	x = -30.0
	while x < 44.0:
		var w := _rng.randf_range(7.0, 14.0)
		_span(Vector3(x, GROUND, -18.0), Vector3(x + w - 0.5, GROUND + _rng.randf_range(9.0, 22.0), -8.0), _m("concrete_dark"), false)
		x += w
	# Side blocks.
	_span(Vector3(-26.0, GROUND, -5.0), Vector3(-14.0, GROUND + 12.0, 17.0), _m("concrete_dark"))
	_span(Vector3(26.0, GROUND, -5.0), Vector3(38.0, GROUND + 14.0, 17.0), _m("concrete_dark"))
	_invisible(Vector3(-14.0, GROUND, 17.0), Vector3(26.0, GROUND + 4.0, 17.4))

	# State watchtower.
	_cyl(0.15, 9.0, Vector3(16.0, GROUND + 4.5, 12.0), pole)
	_span(Vector3(15.2, GROUND + 9.0, 11.2), Vector3(16.8, GROUND + 10.2, 12.8), _c("#16141b"), false)
	_span(Vector3(15.3, GROUND + 9.4, 11.18), Vector3(16.7, GROUND + 9.8, 11.2), _g("#2c1a24"), false)
	_tower_glow = _span(Vector3(15.92, GROUND + 10.2, 11.92), Vector3(16.08, GROUND + 10.36, 12.08), _g("#f03a44"), false)
	_tower_light = _light(Vector3(16.0, GROUND + 10.5, 12.0), "#f03a44", 1.2, 7.0, false)
	_invisible(Vector3(15.85, GROUND, 11.85), Vector3(16.15, GROUND + 4.0, 12.15))

	# The church at the end of the side street.
	var stone := _m("concrete")
	_span(Vector3(-9.0, GROUND, 40.0), Vector3(-1.0, GROUND + 7.0, 54.0), stone, false)
	_span(Vector3(-6.5, GROUND, 37.5), Vector3(-3.5, GROUND + 15.0, 40.5), stone, false)
	_cyl(1.6, 6.0, Vector3(-5.0, GROUND + 18.0, 39.0), stone, Vector3.ZERO, 0.0)
	_span(Vector3(-5.06, GROUND + 21.0, 38.94), Vector3(-4.94, GROUND + 22.6, 39.06), _g("#d7bd6a"), false)
	_span(Vector3(-5.5, GROUND + 22.0, 38.94), Vector3(-4.5, GROUND + 22.12, 39.06), _g("#d7bd6a"), false)
	_span(Vector3(-5.4, GROUND + 9.0, 37.46), Vector3(-4.6, GROUND + 10.6, 37.5), _g("#c9894a"), false)
	_span(Vector3(-5.6, GROUND, 37.46), Vector3(-4.4, GROUND + 2.6, 37.5), _g("#6b4026"), false)

	# Sign at the end of the church street: the way to St. Brigid's.
	_cyl(0.05, 2.4, Vector3(-4.6, GROUND + 1.2, 16.3), pole)
	_span(Vector3(-5.3, GROUND + 1.9, 16.26), Vector3(-3.9, GROUND + 2.3, 16.3), _c("#2b3a4a"), false)
	var arrow := Label3D.new()
	arrow.text = "St. Brigid's  >"
	arrow.font = UiKit.title_font()
	arrow.font_size = 64
	arrow.pixel_size = 0.0035
	arrow.modulate = Color("#e6e0d2")
	arrow.position = Vector3(-4.6, GROUND + 2.1, 16.25)
	arrow.rotation.y = PI
	add_child(arrow)
	_zone(Vector3(-5.4, GROUND, 16.0), Vector3(-3.8, GROUND + 2.4, 16.6), "church_street")

	# Something that only the cameras see.
	_figure = Sprite3D.new()
	_figure.texture = _figure_texture()
	_figure.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_figure.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_figure.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_figure.pixel_size = 0.023
	_figure.layers = LAYER_CCTV_ONLY
	_figure.position = Vector3(6.8, GROUND + 1.15, 10.8)
	_figure.visible = false
	add_child(_figure)


func _figure_texture() -> ImageTexture:
	var image := Image.create(24, 100, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var black := Color(0.02, 0.01, 0.03)
	image.fill_rect(Rect2i(9, 2, 6, 10), black)
	image.fill_rect(Rect2i(11, 12, 2, 3), black)
	image.fill_rect(Rect2i(7, 15, 10, 48), black)
	image.fill_rect(Rect2i(4, 17, 3, 62), black)
	image.fill_rect(Rect2i(17, 17, 3, 62), black)
	image.fill_rect(Rect2i(8, 62, 3, 38), black)
	image.fill_rect(Rect2i(13, 62, 3, 38), black)
	image.set_pixel(10, 6, Color("#d8d0c0"))
	image.set_pixel(13, 6, Color("#d8d0c0"))
	return ImageTexture.create_from_image(image)


func _build_cameras() -> void:
	var setups := [
		["Hatch", Vector3(3.2, 3.4, 8.75), Vector3(1.75, 0.4, WIDTH)],
		["Kitchen", Vector3(3.35, 2.3, 0.15), Vector3(1.0, 0.7, 2.4)],
		["Door", Vector3(5.75, 2.25, WIDTH + 0.22), Vector3(5.6, GROUND + 0.5, 6.4)],
		["Street", Vector3(0.05, 2.8, WIDTH + 0.22), Vector3(6.0, 0.2, 13.0)],
	]
	for setup: Array in setups:
		var unit := SecurityCamera.create(setup[0], setup[1], setup[2])
		add_child(unit)
		cameras.append(unit)


# Changing state ---------------------------------------------------------------

func set_hatch_open(open: bool, animate: bool) -> void:
	var angle := -80.0 if open else 0.0
	_hatch_spill.visible = open
	if animate:
		create_tween().tween_property(_shutter, "rotation_degrees:x", angle, 0.6)
	else:
		_shutter.rotation_degrees.x = angle


func set_candle_lit(lit: bool) -> void:
	_candle_flame.visible = lit
	_candle_light.visible = lit


func set_figure_visible(on: bool) -> void:
	_figure.visible = on


## Shows up to four boxes outside the door for the waiting deliveries.
func show_crates(count: int) -> void:
	for child in _crates.get_children():
		child.queue_free()
	if count <= 0:
		return
	for i in mini(count, 4):
		var at := Vector3(6.25 + (i % 2) * 0.6, GROUND + 0.275 + int(i / 2.0) * 0.55, 4.65)
		_box(Vector3(0.55, 0.55, 0.55), at, _m("cardboard"), false, Vector3(0.0, _rng.randf_range(-8.0, 8.0), 0.0), _crates)
	_zone(Vector3(5.95, GROUND, 4.35), Vector3(7.15, GROUND + 1.15, 4.95), "delivery", _crates)


## The power dips: every light inside stutters and goes out for a moment.
func flicker() -> void:
	if _flicker and _flicker.is_running():
		return
	_flicker = create_tween()
	for step: Array in [[0.25, 0.07], [1.0, 0.05], [0.0, 0.1], [0.7, 0.06], [0.0, 0.6], [1.0, 0.0]]:
		_flicker.tween_callback(_set_power.bind(step[0]))
		_flicker.tween_interval(step[1])
	Sound.play("buzz", 0.1, -8.0)


## The power dies completely, or comes back.
func blackout(on: bool) -> void:
	_blacked_out = on
	_set_power(0.0 if on else 1.0)
	if on:
		_environment.ambient_light_energy = 0.04


func _set_power(level: float) -> void:
	for light in _interior_lights:
		light.light_energy = float(light.get_meta("base")) * level
	for lamp in _lamp_meshes:
		lamp.visible = level > 0.3


func _process(delta: float) -> void:
	if _tv_screen != null:
		_tv_wait -= delta
		if _tv_wait <= 0.0:
			_tv_wait = randf_range(0.6, 2.5)
			var channel := Color.from_hsv(randf(), 0.35, randf_range(0.5, 0.9))
			_tv_screen.material_override = TextureFactory.glow(channel)
			_tv_light.light_color = channel
	_tower_timer += delta
	if _tower_timer >= 1.4:
		_tower_timer = 0.0
		_tower_light.visible = not _tower_light.visible
		_tower_glow.visible = _tower_light.visible
	# The bathroom tube is failing.
	if _bathroom_light != null and (_flicker == null or not _flicker.is_running()):
		var base := float(_bathroom_light.get_meta("base"))
		_bathroom_light.light_energy = base * (0.35 if _rng.randf() < 0.02 else 1.0)
