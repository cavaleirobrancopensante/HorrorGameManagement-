class_name MenuBackdrop
extends Control
## The main menu scene, drawn in chunky pixels: a food trailer at night, a state
## watchtower, a far church. Now and then the light fails, and something has moved.

const ROWS := 180
const HORIZON := 132

var _cell := 4.0
var _columns := 320
var _light := 1.0
var _tower_on := true
var _tower_timer := 0.0
var _figure_spot := -1  # -1 means nothing is standing there.
var _flicker_queue: Array = []
var _flicker_timer := 0.0
var _next_flicker := 7.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rng.randomize()
	resized.connect(queue_redraw)


func _process(delta: float) -> void:
	_tower_timer += delta
	if _tower_timer >= 1.4:
		_tower_timer = 0.0
		_tower_on = not _tower_on
		queue_redraw()
	if _flicker_queue.is_empty():
		_next_flicker -= delta
		if _next_flicker <= 0.0:
			_begin_flicker()
		return
	_flicker_timer -= delta
	if _flicker_timer <= 0.0:
		_step_flicker()


func _begin_flicker() -> void:
	_next_flicker = _rng.randf_range(9.0, 22.0)
	_flicker_queue = [[0.25, 0.07], [1.0, 0.05], [0.0, 0.1], [0.7, 0.05], [0.0, 0.55], [1.0, 0.0]]
	_step_flicker()


func _step_flicker() -> void:
	var step: Array = _flicker_queue.pop_front()
	_light = step[0]
	_flicker_timer = step[1]
	if _light == 0.0 and _flicker_queue.size() == 1:
		# In the long dark, whatever is out there changes place.
		if _figure_spot >= 0:
			_figure_spot = -1 if _rng.randf() < 0.6 else mini(_figure_spot + 1, 2)
		elif _rng.randf() < 0.55:
			_figure_spot = 0
	queue_redraw()


func _r(x: float, y: float, w: float, h: float, color: Color) -> void:
	draw_rect(Rect2(x * _cell, y * _cell, ceilf(w * _cell), ceilf(h * _cell)), color)


func _draw() -> void:
	_cell = size.y / float(ROWS)
	_columns = int(ceilf(size.x / _cell))
	var trailer_x := int(_columns * 0.52)
	_draw_sky()
	_draw_city()
	_draw_church(maxi(_columns - 34, trailer_x + 130))
	_draw_tower(int(_columns * 0.43))
	_draw_ground()
	_draw_light_on_ground(trailer_x)
	_draw_trailer(trailer_x)
	_draw_figure(trailer_x)


func _draw_sky() -> void:
	var top := Color("#120c1b")
	var low := Color("#4a2a3e")
	for band in range(0, HORIZON, 6):
		var t := pow(float(band) / HORIZON, 2.4)
		_r(0, band, _columns, 6, top.lerp(low, t))
	var stars := RandomNumberGenerator.new()
	stars.seed = 40
	for i in 70:
		_r(stars.randi_range(0, _columns), stars.randi_range(0, 70), 1, 1, Color(0.8, 0.75, 0.85, stars.randf_range(0.15, 0.55)))


func _draw_city() -> void:
	var blocks := RandomNumberGenerator.new()
	blocks.seed = 7
	var x := 0
	while x < _columns:
		var w := blocks.randi_range(10, 24)
		var h := blocks.randi_range(14, 52)
		_r(x, HORIZON - h, w, h, Color("#1b1425"))
		for wx in range(x + 2, x + w - 2, 4):
			for wy in range(HORIZON - h + 3, HORIZON - 2, 5):
				if blocks.randf() < 0.1:
					_r(wx, wy, 2, 2, Color("#6c7c86"))
		x += w


func _draw_church(x: int) -> void:
	var stone := Color("#0f0a16")
	_r(x - 34, HORIZON - 10, 96, 10, stone)
	_r(x - 16, HORIZON - 34, 46, 26, stone)
	_r(x - 4, HORIZON - 72, 16, 40, stone)
	for i in 6:
		_r(x - 4 + i, HORIZON - 72 - i * 2 - 2, 16 - i * 2, 2, stone)
	_r(x + 3, HORIZON - 96, 2, 14, Color("#d7bd6a"))
	_r(x - 1, HORIZON - 92, 10, 2, Color("#d7bd6a"))
	_r(x + 2, HORIZON - 58, 4, 9, Color("#b1683a"))
	_r(x - 10, HORIZON - 28, 3, 9, Color("#6d3d3a"))
	_r(x + 22, HORIZON - 28, 3, 9, Color("#6d3d3a"))


func _draw_tower(x: int) -> void:
	var steel := Color("#0d0913")
	_r(x, HORIZON - 104, 3, 104, steel)
	_r(x - 7, HORIZON - 112, 17, 9, steel)
	_r(x - 12, HORIZON - 108, 5, 2, steel)
	_r(x + 10, HORIZON - 108, 5, 2, steel)
	_r(x - 1, HORIZON - 60, 5, 2, steel)
	if _tower_on:
		_r(x, HORIZON - 109, 3, 3, Color("#f03a44"))
		_r(x - 3, HORIZON - 111, 9, 7, Color(0.94, 0.2, 0.26, 0.18))
	else:
		_r(x, HORIZON - 109, 3, 3, Color("#471a22"))


func _draw_ground() -> void:
	for band in range(HORIZON, ROWS, 6):
		var t := float(band - HORIZON) / (ROWS - HORIZON)
		_r(0, band, _columns, 6, Color("#17121f").lerp(Color("#0d0a13"), t))
	var cracks := RandomNumberGenerator.new()
	cracks.seed = 19
	for i in 40:
		_r(cracks.randi_range(0, _columns), cracks.randi_range(HORIZON + 2, ROWS - 1), cracks.randi_range(3, 14), 1, Color("#221b2c"))


func _draw_light_on_ground(x: int) -> void:
	if _light <= 0.0:
		return
	for row in 26:
		var spread := 12 + row * 3
		var alpha := (0.42 - row * 0.015) * _light
		_r(x + 46 - spread, 150 + row, spread * 2 + 20, 1, Color(0.94, 0.62, 0.22, alpha))


func _draw_figure(trailer_x: int) -> void:
	if _figure_spot < 0:
		return
	# Far by the tower, then beside the trailer, then right in front of it.
	var spots := [[trailer_x - 44, 140, 30], [trailer_x - 14, 152, 46], [trailer_x + 22, 170, 70]]
	var spot: Array = spots[_figure_spot]
	var x: int = spot[0]
	var feet: int = spot[1]
	var height: int = spot[2]
	var black := Color("#050308")
	var width := maxi(int(height / 7.0), 4)
	_r(x, feet - height, width, height, black)
	_r(x - 2, feet - height + height / 6, 2, int(height * 0.62), black)
	_r(x + width, feet - height + height / 6, 2, int(height * 0.62), black)
	_r(x + 1, feet - height - width + 1, width - 2, width, black)
	_r(x + 1, feet - height - width + 3, 1, 1, Color("#cfc8bb"))
	_r(x + width - 2, feet - height - width + 3, 1, 1, Color("#cfc8bb"))


func _draw_trailer(x: int) -> void:
	var body := Color("#5f6c6b")
	var body_dark := Color("#39424a")
	var rust := Color("#5d3a2c")
	var y := 92
	var w := 112
	var h := 58
	# Wheels and hitch come first so the body sits over them.
	_r(x + 22, y + h, 18, 8, Color("#09070d"))
	_r(x + 27, y + h + 2, 8, 4, Color("#2e2a33"))
	_r(x + 72, y + h, 18, 8, Color("#09070d"))
	_r(x + 77, y + h + 2, 8, 4, Color("#2e2a33"))
	_r(x - 22, y + h - 6, 24, 3, Color("#1f1b26"))
	_r(x - 22, y + h - 6, 3, 14, Color("#1f1b26"))
	# Rounded caravan body.
	_r(x + 4, y - 2, w - 8, 2, body)
	_r(x + 1, y, w - 2, 2, body)
	_r(x, y + 2, w, h - 2, body)
	_r(x, y + h - 14, w, 14, body_dark)
	_r(x, y + 28, w, 2, Color("#8b8f83"))
	# Rust streaks.
	var streaks := RandomNumberGenerator.new()
	streaks.seed = 3
	for i in 12:
		_r(x + streaks.randi_range(2, w - 4), y + streaks.randi_range(2, 20), 1, streaks.randi_range(3, 12), rust)
	# Home end: a small curtained window.
	_r(x + 8, y + 10, 16, 14, Color("#161420"))
	_r(x + 8, y + 10, 16, 3, Color("#4b3060"))
	_r(x + 15, y + 10, 2, 14, Color("#2b1b3a"))
	# Serving hatch.
	var dark_hatch := Color("#14111a")
	var lit := Color("#f4b45a")
	_r(x + 34, y + 8, 66, 28, dark_hatch.lerp(lit, _light))
	if _light > 0.0:
		_r(x + 34, y + 30, 66, 6, Color("#c17f35").lerp(dark_hatch, 1.0 - _light))
		_r(x + 46, y + 11, 9, 12, Color("#7a4a22"))
		_r(x + 76, y + 13, 14, 3, Color("#7a4a22"))
		_r(x + 80, y + 16, 2, 8, Color("#7a4a22"))
		_r(x + 78, y + 19, 6, 2, Color("#7a4a22"))
	# The cook stands in the light, or is simply gone when it fails.
	if _light > 0.5:
		_r(x + 60, y + 14, 10, 22, Color("#3a2a24"))
		_r(x + 62, y + 9, 6, 6, Color("#3a2a24"))
	_r(x + 30, y + 36, 74, 3, Color("#8b8f83"))
	# Striped awning.
	for i in 9:
		var stripe := Color("#8a2c33") if i % 2 == 0 else Color("#c7b995")
		_r(x + 30 + i * 8, y - 2, 8, 10, stripe.darkened(0.25 + (1.0 - _light) * 0.45))
		_r(x + 30 + i * 8, y + 8, 8, 2, stripe.darkened(0.55))
