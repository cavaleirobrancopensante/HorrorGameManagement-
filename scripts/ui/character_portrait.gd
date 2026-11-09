class_name CharacterPortrait
extends Control
## Live pixel portrait built from the character's appearance. No image files,
## so every combination works and it follows every change at once.

const COLUMNS := 40
const ROWS := 48
## Head to feet, for mirrors and cameras.
const FULL_ROWS := 160
const CENTER := 20

## Draws the whole body on a clear background instead of a framed portrait.
var full_body := false

var character: PlayerCharacter:
	set(value):
		character = value
		queue_redraw()

var _cell := 5.0
var _origin := Vector2.ZERO


func _r(x: int, y: int, w: int, h: int, color: Color) -> void:
	draw_rect(Rect2(_origin + Vector2(x, y) * _cell, Vector2(w, h) * _cell), color)


func _draw() -> void:
	if character == null:
		return
	var rows := FULL_ROWS if full_body else ROWS
	_cell = floorf(minf(size.x / COLUMNS, size.y / rows))
	_origin = ((size - Vector2(COLUMNS, rows) * _cell) / 2.0).floor()
	var look: Dictionary = character.appearance
	var skin := Color(GameData.SKIN_TONES.get(look["skin"], "#c79a6e"))
	var hair := Color(GameData.HAIR_COLOURS.get(look["hair_colour"], "#1c1719"))
	var woman: bool = look["sex"] == "woman"
	var heavy: bool = look["build"] == "heavy"
	var half_widths := _head_shape(woman, look["build"])

	if not full_body:
		_draw_background()
	if look["hair"] == "long":
		_r(CENTER - 11, 11, 22, 29, hair.darkened(0.3))
	if full_body:
		_draw_lower_body(look, skin, woman)
	_draw_body(look, skin, woman)
	_draw_head(half_widths, skin)
	_draw_face(look, skin, woman)
	_draw_facial_hair(look["facial"], hair, heavy)
	_draw_mark(look["mark"], skin)
	_draw_hair(look["hair"], hair, half_widths)
	_draw_age(look["age"], skin, look["hair"] == "bald")


func _head_shape(woman: bool, build: String) -> Array:
	var rows := [5, 6, 7, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 7, 7, 6, 6, 5, 4]
	if woman:
		rows = [5, 6, 7, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 7, 7, 7, 6, 5, 4, 3, 2]
	if build == "heavy":
		for i in range(8, rows.size()):
			rows[i] += 1
	elif build == "lean":
		for i in range(10, rows.size()):
			rows[i] = maxi(rows[i] - 1, 2)
	return rows


func _draw_background() -> void:
	_r(0, 0, COLUMNS, ROWS, Color("#120c1a"))
	for i in 7:
		var inset := i * 2
		_r(inset + 2, inset + 2, COLUMNS - inset * 2 - 4, ROWS - inset, Color(0.42, 0.24, 0.3, 0.09))


func _draw_body(look: Dictionary, skin: Color, woman: bool) -> void:
	var half := {"lean": 13, "average": 15, "heavy": 18}.get(look["build"], 15) as int
	if woman:
		half -= 2
	var shirt := Color("#4b4a55")
	var apron := Color(GameData.APRON_COLOURS.get(look["apron"], "#b9b3a4"))
	_r(CENTER - 4, 31, 8, 8, skin.darkened(0.28))
	_r(CENTER - half + 2, 38, half * 2 - 4, 2, shirt)
	_r(CENTER - half, 40, half * 2, 8, shirt)
	_r(CENTER + half - 5, 40, 5, 8, shirt.darkened(0.3))
	_r(CENTER - 9, 42, 18, 6, apron)
	_r(CENTER + 4, 42, 5, 6, apron.darkened(0.25))
	_r(CENTER - 8, 38, 3, 4, apron.darkened(0.1))
	_r(CENTER + 5, 38, 3, 4, apron.darkened(0.25))


func _draw_lower_body(look: Dictionary, skin: Color, woman: bool) -> void:
	var half := {"lean": 13, "average": 15, "heavy": 18}.get(look["build"], 15) as int
	if woman:
		half -= 2
	var waist := half - 2
	var shirt := Color("#4b4a55")
	var trousers := Color("#2b2833")
	var shoes := Color("#141216")
	var apron := Color(GameData.APRON_COLOURS.get(look["apron"], "#b9b3a4"))
	_r(CENTER - waist + 1, 96, waist - 2, 54, trousers)
	_r(CENTER + 1, 96, waist - 2, 54, trousers.darkened(0.25))
	_r(CENTER - waist, 150, waist, 8, shoes)
	_r(CENTER + 1, 150, waist, 8, shoes)
	_r(CENTER - half, 40, half * 2, 30, shirt)
	_r(CENTER - waist, 70, waist * 2, 28, shirt)
	_r(CENTER + half - 5, 40, 5, 30, shirt.darkened(0.3))
	_r(CENTER + waist - 5, 70, 5, 28, shirt.darkened(0.3))
	_r(CENTER - half, 44, 4, 46, shirt.darkened(0.12))
	_r(CENTER + half - 4, 44, 4, 46, shirt.darkened(0.4))
	_r(CENTER - half, 90, 4, 7, skin)
	_r(CENTER + half - 4, 90, 4, 7, skin.darkened(0.3))
	_r(CENTER - 9, 42, 18, 70, apron)
	_r(CENTER + 4, 42, 5, 70, apron.darkened(0.25))
	_r(CENTER - waist, 76, waist * 2, 1, apron.darkened(0.35))


func _draw_head(half_widths: Array, skin: Color) -> void:
	for i in half_widths.size():
		var half: int = half_widths[i]
		var y := 12 + i
		_r(CENTER - half, y, half * 2, 1, skin)
		_r(CENTER + half - 4, y, 4, 1, skin.darkened(0.3))
		_r(CENTER - half, y, 1, 1, skin.lightened(0.12))
	_r(CENTER - 10, 21, 2, 5, skin.darkened(0.12))
	_r(CENTER + 8, 21, 2, 5, skin.darkened(0.4))


func _draw_face(look: Dictionary, skin: Color, woman: bool) -> void:
	var eye := Color(GameData.EYE_COLOURS.get(look["eyes"], "#442a18"))
	var white := Color("#d9d2c5")
	var brow := Color(GameData.HAIR_COLOURS.get(look["hair_colour"], "#1c1719")).darkened(0.15)
	for eye_x in [CENTER - 6, CENTER + 2]:
		_r(eye_x, 22, 4, 2, white)
		_r(eye_x + 1, 22, 2, 2, eye)
		_r(eye_x + 1, 22, 1, 1, Color.BLACK)
		_r(eye_x, 20, 4, 1 if woman else 2, brow)
		if woman:
			_r(eye_x, 21, 4, 1, Color("#1a1216"))
	_r(CENTER - 1, 23, 2, 5, skin.darkened(0.2))
	_r(CENTER - 2, 27, 4, 1, skin.darkened(0.32))
	if woman:
		_r(CENTER - 3, 30, 6, 1, Color("#7c3236"))
		_r(CENTER - 2, 31, 4, 1, Color("#96474a"))
	else:
		_r(CENTER - 3, 30, 6, 1, skin.darkened(0.5))


func _draw_facial_hair(facial: String, hair: Color, heavy: bool) -> void:
	var extra := 1 if heavy else 0
	match facial:
		"stubble":
			for y in range(28, 34):
				for x in range(CENTER - 6 - extra, CENTER + 6 + extra):
					if (x + y) % 2 == 0:
						_r(x, y, 1, 1, Color(hair, 0.6))
		"moustache":
			_r(CENTER - 4, 28, 8, 2, hair)
			_r(CENTER - 5, 29, 2, 2, hair)
			_r(CENTER + 3, 29, 2, 2, hair)
		"beard":
			_r(CENTER - 7 - extra, 26, 3, 7, hair)
			_r(CENTER + 4 + extra, 26, 3, 7, hair.darkened(0.25))
			_r(CENTER - 6 - extra, 28, 12 + extra * 2, 8, hair)
			_r(CENTER - 4, 36, 8, 2, hair)
			_r(CENTER + 2, 28, 4 + extra, 8, hair.darkened(0.25))
			_r(CENTER - 3, 30, 6, 1, Color("#3f2526"))


func _draw_mark(mark: String, skin: Color) -> void:
	match mark:
		"scar":
			for i in 7:
				_r(CENTER + 2 + i / 2, 18 + i * 2, 1, 2, Color("#c98f8a"))
		"mole":
			_r(CENTER - 6, 27, 1, 1, skin.darkened(0.7))
		"tired":
			_r(CENTER - 6, 24, 4, 1, skin.darkened(0.42))
			_r(CENTER + 2, 24, 4, 1, skin.darkened(0.42))


func _draw_hair(style: String, hair: Color, half_widths: Array) -> void:
	var dark := hair.darkened(0.3)
	match style:
		"short":
			_cap(hair, dark, half_widths, 5)
			_r(CENTER - 9, 16, 2, 6, hair)
			_r(CENTER + 7, 16, 2, 6, dark)
		"messy":
			_cap(hair, dark, half_widths, 6)
			var tufts := [[-9, 3], [-5, 5], [-1, 3], [3, 6], [7, 3]]
			for tuft: Array in tufts:
				_r(CENTER + tuft[0], 12 - tuft[1], 3, tuft[1] + 1, hair)
			_r(CENTER - 7, 18, 3, 2, hair)
			_r(CENTER + 1, 18, 3, 2, dark)
		"long":
			_cap(hair, dark, half_widths, 6)
			_r(CENTER - 11, 13, 4, 26, hair)
			_r(CENTER + 7, 13, 4, 26, dark)
		"tied":
			_cap(hair, dark, half_widths, 5)
			_r(CENTER - 3, 5, 6, 1, hair)
			_r(CENTER - 4, 6, 8, 4, hair)
			_r(CENTER + 1, 6, 3, 4, dark)
			_r(CENTER - 2, 10, 4, 1, dark)
		"curly":
			_cap(hair, dark, half_widths, 5)
			for x in range(-11, 11, 4):
				_r(CENTER + x, 8 + absi(x + 1) / 3, 4, 5, hair if x < 3 else dark)
			for y in range(13, 25, 4):
				_r(CENTER - 11, y, 4, 4, hair)
				_r(CENTER + 7, y, 4, 4, dark)


func _cap(hair: Color, dark: Color, half_widths: Array, depth: int) -> void:
	_r(CENTER - 6, 10, 12, 2, hair)
	for i in depth:
		var half: int = half_widths[i] + 1
		_r(CENTER - half, 12 + i, half * 2, 1, hair)
		_r(CENTER + half - 5, 12 + i, 5, 1, dark)


func _draw_age(age: String, skin: Color, bald: bool) -> void:
	if age != "old":
		return
	var line := skin.darkened(0.42)
	_r(CENTER - 8, 25, 2, 1, line)
	_r(CENTER + 6, 25, 2, 1, line)
	_r(CENTER - 5, 28, 1, 3, line)
	_r(CENTER + 4, 28, 1, 3, line)
	if bald:
		_r(CENTER - 5, 17, 10, 1, line)
	_r(CENTER - 5, 24, 3, 1, line)
	_r(CENTER + 2, 24, 3, 1, line)
