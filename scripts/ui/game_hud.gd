class_name GameHud
extends Control
## Needs, clock, money, what you are looking at, and short messages.

const ROWS := [
	["health", "Health"],
	["hunger", "Hunger"],
	["thirst", "Thirst"],
	["tiredness", "Tiredness"],
	["stress", "Stress"],
]
const TOAST_SECONDS := 4.5

var save: Dictionary
var touch_mode := false
## Covers the screen for sleep and death.
var fade: ColorRect
var _prompt := ""
var _toast := ""
var _toast_time := 0.0
var _hint := ""
var _holding := ""
var _can_eat := false
## The next step, shown the first few times you do something.
var _step := ""
## A tooltip by the crosshair: what you are looking at, when you hold still.
var _tip_title := ""
var _tip_text := ""
var _tip_alpha := 0.0
## Order bubbles over customers: [screen point, text, colour, mood].
var bubbles: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func refresh() -> void:
	queue_redraw()


func set_prompt(text: String) -> void:
	_prompt = text


## Shows a tooltip beside the crosshair, or hides it with "".
func set_tip(title: String, text: String) -> void:
	if title == _tip_title and text == _tip_text:
		return
	_tip_title = title
	_tip_text = text
	_tip_alpha = 0.0
	queue_redraw()


func set_step(text: String) -> void:
	_step = text


func set_holding(text: String, can_eat: bool) -> void:
	_holding = text
	_can_eat = can_eat


func toast(text: String) -> void:
	_toast = text
	_toast_time = TOAST_SECONDS


## A quick wash of colour over the screen that fades: a blow, a scare.
func flash(colour: Color) -> void:
	fade.color = colour
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 0.0, 0.6)


func show_hint(text: String) -> void:
	_hint = text


func _process(delta: float) -> void:
	if _toast_time > 0.0:
		_toast_time -= delta


func _draw() -> void:
	if save.is_empty():
		return
	var font := get_theme_default_font()
	var panel := Rect2(14, 14, 300, 18 + ROWS.size() * 28)
	draw_rect(panel, Color(UiKit.COMPLINE, 0.72))
	for i in ROWS.size():
		var id: String = ROWS[i][0]
		var y := 24.0 + i * 28.0
		_text(font, Vector2(26, y + 17), ROWS[i][1], 20, UiKit.TALLOW)
		var fill: float
		var colour: Color
		if id == "health":
			fill = Survival.health(save) / Survival.max_health(save)
			colour = UiKit.SANCTUARY if fill > 0.3 else Color("#ff4a55")
		else:
			var value := Survival.need(save, id)
			fill = value / float(GameData.NEED_MAX)
			colour = UiKit.LITURGICAL_GOLD
			if value > 60.0:
				colour = UiKit.SODIUM
			if value > 85.0:
				colour = Color("#ff4a55")
		var bar := Rect2(140, y + 6, 160, 10)
		draw_rect(bar, Color(UiKit.VESTMENT_LIGHT, 0.6))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(fill, 0.0, 1.0), bar.size.y)), colour)

	var right := size.x - (110.0 if touch_mode else 20.0)
	var now := Survival.now(save)
	_text(font, Vector2(right - 340, 40), Survival.date_text(now), 26, UiKit.TALLOW, 340)
	_text(font, Vector2(right - 340, 68), "%s, %s" % [Survival.shift_name(now), Survival.clock_text(now)], 22, UiKit.TALLOW, 340)
	_text(font, Vector2(right - 340, 96), "%d credits" % Survival.money(save), 22, UiKit.LITURGICAL_GOLD, 340)

	for bubble: Array in bubbles:
		_bubble(font, bubble[0], bubble[1], bubble[2], float(bubble[3]) if bubble.size() > 3 else -1.0)

	var center := size / 2.0
	if _prompt.is_empty():
		draw_rect(Rect2(center - Vector2(2, 2), Vector2(4, 4)), Color(UiKit.TALLOW, 0.6))
	else:
		draw_arc(center, 8.0, 0.0, TAU, 16, UiKit.SODIUM, 2.0)
		var prompt_y := size.y - (230.0 if touch_mode else 120.0)
		var hint := "" if touch_mode else "E  "
		_text(font, Vector2(0, prompt_y), hint + _prompt, 28, UiKit.TALLOW, size.x, HORIZONTAL_ALIGNMENT_CENTER)

	if not _holding.is_empty():
		var eat := ""
		if _can_eat:
			eat = "   (Eat button)" if touch_mode else "   (Q to eat)"
		var holding_y := size.y - (190.0 if touch_mode else 80.0)
		_text(font, Vector2(0, holding_y), _holding + eat, 22, UiKit.LITURGICAL_GOLD, size.x, HORIZONTAL_ALIGNMENT_CENTER)
	if not _step.is_empty():
		var step_y := size.y - (270.0 if touch_mode else 160.0)
		_text(font, Vector2(0, step_y), _step, 24, Color("#a8d8b4"), size.x, HORIZONTAL_ALIGNMENT_CENTER)
	if not _tip_title.is_empty():
		_draw_tip(font, center)
	if _toast_time > 0.0:
		var alpha := clampf(_toast_time, 0.0, 1.0)
		_text(font, Vector2(0, 150), _toast, 26, Color(UiKit.TALLOW, alpha), size.x, HORIZONTAL_ALIGNMENT_CENTER)
	if not _hint.is_empty():
		_text(font, Vector2(0, size.y - 40), _hint, 22, UiKit.ASH, size.x, HORIZONTAL_ALIGNMENT_CENTER)


## A small panel to the lower right of the crosshair, fading in.
func _draw_tip(font: Font, center: Vector2) -> void:
	_tip_alpha = minf(_tip_alpha + get_process_delta_time() * 5.0, 1.0)
	var width := 380.0
	var lines := _wrap(font, _tip_text, 20, width - 28.0)
	var height := 50.0 + lines.size() * 24.0
	var at := center + Vector2(34.0, 26.0)
	at.x = minf(at.x, size.x - width - 12.0)
	at.y = minf(at.y, size.y - height - 12.0)
	draw_rect(Rect2(at, Vector2(width, height)), Color(UiKit.COMPLINE, 0.9 * _tip_alpha))
	draw_rect(Rect2(at, Vector2(width, height)), Color(UiKit.LITURGICAL_GOLD, 0.7 * _tip_alpha), false, 2.0)
	_text(font, at + Vector2(14, 30), _tip_title, 24, Color(UiKit.LITURGICAL_GOLD, _tip_alpha))
	for i in lines.size():
		_text(font, at + Vector2(14, 56 + i * 24), lines[i], 20, Color(UiKit.TALLOW, _tip_alpha))
	if _tip_alpha < 1.0:
		queue_redraw()


## Breaks text into lines that fit a width.
func _wrap(font: Font, text: String, font_size: int, width: float) -> PackedStringArray:
	var lines: PackedStringArray = []
	for paragraph in text.split("\n"):
		var line := ""
		for word in paragraph.split(" "):
			var trial := word if line.is_empty() else line + " " + word
			if font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width and not line.is_empty():
				lines.append(line)
				line = word
			else:
				line = trial
		lines.append(line)
	return lines


func _bubble(font: Font, anchor: Vector2, text: String, colour: Color, mood := -1.0) -> void:
	var lines := text.split("\n")
	var width := 0.0
	for line in lines:
		width = maxf(width, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x)
	var face_room := 36.0 if mood >= 0.0 else 0.0
	var bar_room := 10.0 if mood >= 0.0 else 0.0
	var box := Rect2(anchor - Vector2((width + face_room) / 2.0 + 10.0, lines.size() * 24.0 + 18.0 + bar_room), Vector2(width + face_room + 20.0, lines.size() * 24.0 + 10.0 + bar_room))
	draw_rect(box, Color(UiKit.COMPLINE, 0.85))
	draw_rect(box, Color(colour, 0.8), false, 2.0)
	if mood >= 0.0:
		_face(box.position + Vector2(box.size.x - 22.0, 22.0), mood, colour)
		var bar := Rect2(box.position + Vector2(8.0, box.size.y - 12.0), Vector2(box.size.x - 16.0, 5.0))
		draw_rect(bar, Color(UiKit.VESTMENT_LIGHT, 0.7))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(mood / 100.0, 0.0, 1.0), bar.size.y)), colour)
	var tail := PackedVector2Array([anchor + Vector2(-7, -8), anchor + Vector2(7, -8), anchor])
	draw_colored_polygon(tail, Color(colour, 0.8))
	for i in lines.size():
		draw_string(font, Vector2(box.position.x + 10.0, box.position.y + 24.0 + i * 24.0), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, colour if i == lines.size() - 1 else UiKit.TALLOW)


## A smiling, flat or angry face for a customer's mood.
func _face(center: Vector2, mood: float, colour: Color) -> void:
	draw_circle(center, 12.0, Color(colour, 0.9))
	var ink := UiKit.COMPLINE
	draw_rect(Rect2(center + Vector2(-6, -5), Vector2(3, 4)), ink)
	draw_rect(Rect2(center + Vector2(3, -5), Vector2(3, 4)), ink)
	match StandRules.face(mood):
		"happy":
			draw_arc(center + Vector2(0, 1), 6.0, 0.3, PI - 0.3, 8, ink, 2.0)
		"neutral":
			draw_line(center + Vector2(-5, 5), center + Vector2(5, 5), ink, 2.0)
		_:
			draw_arc(center + Vector2(0, 10), 6.0, PI + 0.4, TAU - 0.4, 8, ink, 2.0)
			draw_line(center + Vector2(-7, -8), center + Vector2(-2, -6), ink, 2.0)
			draw_line(center + Vector2(7, -8), center + Vector2(2, -6), ink, 2.0)


func _text(font: Font, at: Vector2, text: String, font_size: int, colour: Color, width := -1.0, align := HORIZONTAL_ALIGNMENT_RIGHT) -> void:
	if width < 0.0:
		align = HORIZONTAL_ALIGNMENT_LEFT
	draw_string_outline(font, at, text, align, width, font_size, 6, Color(0, 0, 0, colour.a * 0.85))
	draw_string(font, at, text, align, width, font_size, colour)
