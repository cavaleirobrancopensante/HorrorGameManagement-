class_name JumpscareFace
extends Control
## A face, right in front of yours, for half a second. Drawn in big pixels so
## it matches the low-resolution world.

const GRID := Vector2i(32, 40)

var _jitter := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	_jitter = Vector2(randf_range(-6, 6), randf_range(-6, 6))
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.0, 0.02, 0.92))
	var cell := floorf(size.y * 1.05 / GRID.y)
	var origin := (size - Vector2(GRID) * cell) / 2.0 + _jitter
	var skin := Color("#b9b2a6")
	var shade := Color("#7d766c")
	var hole := Color("#050304")
	var eye := Color("#ff3a24")
	# Long skull of a face.
	for y in range(3, 37):
		var half := 11 - absi(y - 16) / 3
		if y > 28:
			half = 11 - (y - 28)
		for x in range(16 - half, 16 + half):
			_cell(origin, cell, x, y, skin if x > 13 - y / 6 else shade)
	# Hollow eyes, with a point of light far inside.
	for eye_x in [9, 19]:
		for y in range(11, 18):
			for x in range(eye_x, eye_x + 5):
				_cell(origin, cell, x, y, hole)
		_cell(origin, cell, eye_x + 2, 14, eye)
	# Nose slits.
	_cell(origin, cell, 15, 20, hole)
	_cell(origin, cell, 17, 20, hole)
	# A mouth stretched too wide, full of teeth.
	for y in range(24, 32):
		for x in range(7 + (y - 24) / 3, 25 - (y - 24) / 3):
			_cell(origin, cell, x, y, hole)
	for x in range(8, 24, 2):
		_cell(origin, cell, x, 24, Color("#d8d0b8"))
		_cell(origin, cell, x + 1, 31 - (x % 4) / 2, Color("#d8d0b8"))


func _cell(origin: Vector2, cell: float, x: int, y: int, colour: Color) -> void:
	draw_rect(Rect2(origin + Vector2(x, y) * cell, Vector2(cell, cell)), colour)
