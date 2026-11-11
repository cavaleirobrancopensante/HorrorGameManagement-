class_name TextureFactory
extends RefCounted
## Small pixel textures made in code, for a PS1 look without image files.
## Materials tile in world space, so any box can use any surface.

static var _cache := {}


static func surface(kind: String) -> StandardMaterial3D:
	if _cache.has(kind):
		return _cache[kind]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind)
	var image: Image
	var metres := 1.0
	var specular := 0.12
	var roughness := 1.0
	match kind:
		"floor_check":
			image = _checker(Color("#a9a083"), Color("#36333c"), 4, 32, rng)
		"floor_lino":
			image = _speckled(Color("#55625a"), 0.12, 32, rng)
		"floor_planks":
			image = _planks(Color("#6b4a32"), 4, 64, rng)
			metres = 1.4
		"floor_tiles":
			image = _tiles(Color("#bfc3bc"), Color("#6a6e69"), 4, 32, rng)
			metres = 0.8
		"wall_kitchen":
			image = _tiles(Color("#cdc6b1"), Color("#8a846f"), 4, 32, rng)
			metres = 0.6
		"wall_panel":
			image = _panel(Color("#968b70"), 64, rng)
			metres = 1.2
		"wallpaper":
			image = _wallpaper(Color("#58624b"), Color("#4b5441"), 32, rng)
			metres = 0.8
		"wall_bath":
			image = _tiles(Color("#8fa9a3"), Color("#5c6e6a"), 4, 32, rng)
			metres = 0.6
		"ceiling":
			image = _ceiling(Color("#878173"), 64, rng)
			metres = 1.2
		"skin":
			image = _ribbed(Color("#6b7975"), 32, rng)
		"roof":
			image = _speckled(Color("#4b5250"), 0.15, 32, rng)
		"steel":
			image = _brushed(Color("#9ba1a3"), 32, rng)
			specular = 0.5
			roughness = 0.55
		"steel_dark":
			image = _brushed(Color("#43474a"), 32, rng)
			specular = 0.4
			roughness = 0.6
		"wood":
			image = _planks(Color("#5a3a27"), 2, 32, rng)
			metres = 0.7
		"wood_light":
			image = _planks(Color("#8b6a47"), 2, 32, rng)
			metres = 0.7
		"fabric":
			image = _plaid(Color("#6c2a30"), Color("#3f181d"), 32, rng)
			metres = 0.5
		"rug":
			image = _plaid(Color("#4e3a5c"), Color("#7a5a3a"), 32, rng)
			metres = 0.6
		"mattress":
			image = _stripes(Color("#c9c4b4"), Color("#7d8aa0"), 32, rng)
			metres = 0.5
		"cardboard":
			image = _cardboard(Color("#8b6942"), 32, rng)
			metres = 0.55
		"plastic":
			image = _speckled(Color("#d6d0bf"), 0.05, 16, rng)
		"asphalt":
			image = _asphalt(Color("#3a383d"), 32, rng)
			metres = 2.0
		"concrete":
			image = _speckled(Color("#4f4c4a"), 0.16, 32, rng)
			metres = 2.0
		"concrete_dark":
			image = _speckled(Color("#25222b"), 0.2, 32, rng)
			metres = 3.0
		"rubber":
			image = _speckled(Color("#161518"), 0.2, 16, rng)
		"skirt":
			image = _speckled(Color("#1c1a20"), 0.2, 16, rng)
		_:
			image = _speckled(Color.MAGENTA, 0.1, 8, rng)
	image = _refine(image, rng, kind)
	var relief := image.duplicate() as Image
	relief.bump_map_to_normal_map(RELIEF.get(kind, 1.5))
	relief.generate_mipmaps()
	image.generate_mipmaps()
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(image)
	material.normal_enabled = true
	material.normal_texture = ImageTexture.create_from_image(relief)
	material.normal_scale = 0.7
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS if _retro() else BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3.ONE / metres
	material.roughness = roughness
	material.metallic_specular = specular
	_cache[kind] = material
	return material


## How much each surface's pattern stands out in relief.
const RELIEF := {"wall_kitchen": 3.0, "wall_bath": 3.0, "floor_tiles": 3.0, "skin": 4.0, "floor_planks": 2.5, "wood": 2.5, "wood_light": 2.5, "asphalt": 2.0, "concrete": 2.0, "ceiling": 2.0, "plastic": 0.4, "steel": 0.8, "steel_dark": 0.8}


static func _retro() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or not tree.root.has_node("Settings"):
		return false
	return int(tree.root.get_node("Settings").get("pixel_scale")) >= 3


## Four times the pixels, with fine grain and blotches of grime, so surfaces
## stay crisp up close instead of turning to blocks.
static func _refine(image: Image, rng: RandomNumberGenerator, kind: String) -> Image:
	var size := clampi(image.get_width() * 4, 64, 256)
	# Noise-like surfaces smooth out; patterned ones keep their crisp lines.
	var smooth := kind in ["asphalt", "concrete", "concrete_dark", "roof", "floor_lino", "rubber", "skirt", "plastic"]
	image.resize(size, size, Image.INTERPOLATE_CUBIC if smooth else Image.INTERPOLATE_NEAREST)
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.035
	noise.fractal_octaves = 3
	var grime := noise.get_seamless_image(size, size)
	var clean := kind in ["plastic", "steel", "steel_dark", "mattress"]
	var depth := 0.06 if clean else 0.15
	for y in size:
		for x in size:
			var colour := image.get_pixel(x, y)
			var blotch := grime.get_pixel(x, y).r
			var grain := 1.0 + (rng.randf() - 0.5) * 0.08
			var dirt := 1.0 - maxf(0.0, blotch - 0.45) * depth * 2.0
			image.set_pixel(x, y, Color(colour.r * grain * dirt, colour.g * grain * dirt, colour.b * grain * dirt))
	return image


static func plain(color: Color, roughness := 1.0) -> StandardMaterial3D:
	var key := "plain_%s_%.2f" % [color.to_html(), roughness]
	if _cache.has(key):
		return _cache[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic_specular = 0.15
	_cache[key] = material
	return material


## Lit from within: screens, bulbs, lit windows, flames.
static func glow(color: Color) -> StandardMaterial3D:
	var key := "glow_%s" % color.to_html()
	if _cache.has(key):
		return _cache[key]
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	_cache[key] = material
	return material


# Generators -------------------------------------------------------------------

static func _shade(color: Color, factor: float) -> Color:
	return Color(color.r * factor, color.g * factor, color.b * factor)


static func _jitter(rng: RandomNumberGenerator, amount: float) -> float:
	return 1.0 + (rng.randf() - 0.5) * amount * 2.0


static func _blank(size: int) -> Image:
	return Image.create(size, size, false, Image.FORMAT_RGB8)


static func _speckled(base: Color, amount: float, size: int, rng: RandomNumberGenerator) -> Image:
	var image := _blank(size)
	for y in size:
		for x in size:
			image.set_pixel(x, y, _shade(base, _jitter(rng, amount)))
	return image


static func _checker(a: Color, b: Color, cells: int, size: int, rng: RandomNumberGenerator) -> Image:
	var image := _blank(size)
	var cell := size / cells
	for y in size:
		for x in size:
			var color := a if (x / cell + y / cell) % 2 == 0 else b
			image.set_pixel(x, y, _shade(color, _jitter(rng, 0.07)))
	_stain(image, 4, 0.82, rng)
	return image


static func _tiles(tile: Color, grout: Color, cells: int, size: int, rng: RandomNumberGenerator) -> Image:
	var image := _blank(size)
	var cell := size / cells
	var tones: Array[float] = []
	for i in cells * cells:
		tones.append(rng.randf_range(0.93, 1.06))
	for y in size:
		for x in size:
			if x % cell == 0 or y % cell == 0:
				image.set_pixel(x, y, _shade(grout, _jitter(rng, 0.1)))
			else:
				var tone: float = tones[(y / cell) * cells + x / cell]
				image.set_pixel(x, y, _shade(tile, tone * _jitter(rng, 0.03)))
	_stain(image, 3, 0.86, rng)
	return image


static func _planks(base: Color, rows: int, size: int, rng: RandomNumberGenerator) -> Image:
	var image := _blank(size)
	var height := size / rows
	var tones: Array[float] = []
	var seams: Array[int] = []
	var phases: Array[float] = []
	for r in rows:
		tones.append(rng.randf_range(0.8, 1.1))
		seams.append(rng.randi_range(0, size - 1))
		phases.append(rng.randf() * 10.0)
	for y in size:
		var row := y / height
		for x in size:
			var factor: float = tones[row] * (0.93 + 0.07 * sin(x * 0.35 + phases[row] + y * 0.9)) * _jitter(rng, 0.04)
			if y % height == 0 or x == seams[row]:
				factor *= 0.55
			image.set_pixel(x, y, _shade(base, factor))
	return image


static func _ribbed(base: Color, size: int, rng: RandomNumberGenerator) -> Image:
	var image := _blank(size)
	for y in size:
		for x in size:
			var factor := 1.0
			if x % 8 == 0:
				factor = 0.68
			elif x % 8 == 1:
				factor = 1.16
			image.set_pixel(x, y, _shade(base, factor * _jitter(rng, 0.05)))
	var rust := Color("#6b3b28")
	for streak in 5:
		var column := rng.randi_range(0, size - 1)
		var top := rng.randi_range(0, size / 2)
		var length := rng.randi_range(6, size / 2)
		for y in range(top, mini(top + length, size)):
			var amount := 0.7 * (1.0 - float(y - top) / length)
			image.set_pixel(column, y, image.get_pixel(column, y).lerp(rust, amount))
	return image


static func _brushed(base: Color, size: int, rng: RandomNumberGenerator) -> Image:
	var image := _blank(size)
	for y in size:
		var row := _jitter(rng, 0.06)
		for x in size:
			image.set_pixel(x, y, _shade(base, row * _jitter(rng, 0.03)))
	return image


static func _panel(base: Color, size: int, rng: RandomNumberGenerator) -> Image:
	var image := _blank(size)
	for y in size:
		for x in size:
			var factor := (0.95 + 0.05 * sin(y * 0.5 + x * 0.1)) * _jitter(rng, 0.04)
			if x % 16 == 0:
				factor *= 0.6
			elif x % 16 == 15:
				factor *= 1.08
			image.set_pixel(x, y, _shade(base, factor))
	_stain(image, 4, 0.8, rng)
	return image


static func _wallpaper(base: Color, stripe: Color, size: int, rng: RandomNumberGenerator) -> Image:
	var image := _blank(size)
	for y in size:
		for x in size:
			var color := stripe if (x / 4) % 2 == 0 else base
			if x % 8 == 6 and y % 8 == 3:
				color = color.lightened(0.25)
			image.set_pixel(x, y, _shade(color, _jitter(rng, 0.04)))
	_stain(image, 3, 0.8, rng)
	return image


static func _ceiling(base: Color, size: int, rng: RandomNumberGenerator) -> Image:
	var image := _blank(size)
	for y in size:
		for x in size:
			var factor := _jitter(rng, 0.05)
			if x % 32 == 0 or y % 32 == 0:
				factor *= 0.7
			image.set_pixel(x, y, _shade(base, factor))
	_stain(image, 2, 0.78, rng)
	return image


static func _plaid(a: Color, b: Color, size: int, rng: RandomNumberGenerator) -> Image:
	var image := _blank(size)
	for y in size:
		for x in size:
			var color := a
			if x % 8 < 2 or y % 8 < 2:
				color = a.lerp(b, 0.7)
			if x % 8 < 2 and y % 8 < 2:
				color = b
			image.set_pixel(x, y, _shade(color, _jitter(rng, 0.06)))
	return image


static func _stripes(base: Color, line: Color, size: int, rng: RandomNumberGenerator) -> Image:
	var image := _blank(size)
	for y in size:
		for x in size:
			var color := line if x % 8 == 0 else base
			image.set_pixel(x, y, _shade(color, _jitter(rng, 0.04)))
	return image


static func _cardboard(base: Color, size: int, rng: RandomNumberGenerator) -> Image:
	var image := _speckled(base, 0.08, size, rng)
	var tape := Color("#b39a72")
	for y in range(size / 2 - 3, size / 2 + 3):
		for x in size:
			image.set_pixel(x, y, _shade(tape, _jitter(rng, 0.04)))
	return image


static func _asphalt(base: Color, size: int, rng: RandomNumberGenerator) -> Image:
	var image := _blank(size)
	for y in size:
		for x in size:
			var factor := _jitter(rng, 0.3)
			if rng.randf() < 0.025:
				factor = 1.7
			image.set_pixel(x, y, _shade(base, factor))
	return image


## Darkens a few soft blobs: damp, grease, age.
static func _stain(image: Image, count: int, depth: float, rng: RandomNumberGenerator) -> void:
	var size := image.get_width()
	for i in count:
		var center := Vector2(rng.randi_range(0, size - 1), rng.randi_range(0, size - 1))
		var radius := rng.randf_range(2.0, size / 6.0)
		for y in size:
			for x in size:
				var distance := center.distance_to(Vector2(x, y))
				if distance < radius:
					var amount := (1.0 - distance / radius) * (1.0 - depth)
					image.set_pixel(x, y, _shade(image.get_pixel(x, y), 1.0 - amount))
