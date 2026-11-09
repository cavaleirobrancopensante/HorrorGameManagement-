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


func toast(text: String) -> void:
	_toast = text
	_toast_time = TOAST_SECONDS


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

	var center := size / 2.0
	if _prompt.is_empty():
		draw_rect(Rect2(center - Vector2(2, 2), Vector2(4, 4)), Color(UiKit.TALLOW, 0.6))
	else:
		draw_arc(center, 8.0, 0.0, TAU, 16, UiKit.SODIUM, 2.0)
		var prompt_y := size.y - (230.0 if touch_mode else 120.0)
		var hint := "" if touch_mode else "E  "
		_text(font, Vector2(0, prompt_y), hint + _prompt, 28, UiKit.TALLOW, size.x, HORIZONTAL_ALIGNMENT_CENTER)

	if _toast_time > 0.0:
		var alpha := clampf(_toast_time, 0.0, 1.0)
		_text(font, Vector2(0, 150), _toast, 26, Color(UiKit.TALLOW, alpha), size.x, HORIZONTAL_ALIGNMENT_CENTER)
	if not _hint.is_empty():
		_text(font, Vector2(0, size.y - 40), _hint, 22, UiKit.ASH, size.x, HORIZONTAL_ALIGNMENT_CENTER)


func _text(font: Font, at: Vector2, text: String, font_size: int, colour: Color, width := -1.0, align := HORIZONTAL_ALIGNMENT_RIGHT) -> void:
	if width < 0.0:
		align = HORIZONTAL_ALIGNMENT_LEFT
	draw_string_outline(font, at, text, align, width, font_size, 6, Color(0, 0, 0, colour.a * 0.85))
	draw_string(font, at, text, align, width, font_size, colour)
