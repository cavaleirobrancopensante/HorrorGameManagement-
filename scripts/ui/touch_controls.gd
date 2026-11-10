class_name TouchControls
extends Control
## Phone controls: a stick wherever the left thumb lands, drag anywhere on the
## right to look, and buttons for use, torch and pause. Every finger is tracked
## on its own, so you can walk, look and press at the same time.

signal use_pressed
signal light_pressed
signal pause_pressed
signal plan_pressed

const STICK_RADIUS := 90.0
const LOOK_SPEED := 0.0055

var player: Player
var use_ready := false
var light_on := false
var _stick_finger := -1
var _stick_origin := Vector2.ZERO
var _stick_knob := Vector2.ZERO
var _look_finger := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _buttons() -> Dictionary:
	return {
		"use": [Vector2(size.x - 140, size.y - 150), 74.0],
		"light": [Vector2(size.x - 290, size.y - 85), 50.0],
		"pause": [Vector2(size.x - 60, 52), 38.0],
		"plan": [Vector2(size.x - 60, 140), 38.0],
	}


func reset() -> void:
	_stick_finger = -1
	_look_finger = -1
	_stick_knob = Vector2.ZERO
	if player != null:
		player.move_input = Vector2.ZERO
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_press(touch.index, touch.position)
		else:
			if touch.index == _stick_finger:
				_stick_finger = -1
				_stick_knob = Vector2.ZERO
				player.move_input = Vector2.ZERO
			elif touch.index == _look_finger:
				_look_finger = -1
		queue_redraw()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _stick_finger:
			_stick_knob = (drag.position - _stick_origin).limit_length(STICK_RADIUS)
			player.move_input = _stick_knob / STICK_RADIUS
			queue_redraw()
		elif drag.index == _look_finger:
			player.look(drag.relative * LOOK_SPEED)


func _press(finger: int, at: Vector2) -> void:
	var buttons := _buttons()
	for id: String in buttons:
		var spot: Array = buttons[id]
		if at.distance_to(spot[0]) <= float(spot[1]) * 1.15:
			match id:
				"use":
					use_pressed.emit()
				"light":
					light_pressed.emit()
				"pause":
					pause_pressed.emit()
				"plan":
					plan_pressed.emit()
			return
	if at.x < size.x * 0.42 and _stick_finger == -1:
		_stick_finger = finger
		_stick_origin = at
		_stick_knob = Vector2.ZERO
	elif _look_finger == -1:
		_look_finger = finger


func _draw() -> void:
	var font := get_theme_default_font()
	var base := _stick_origin if _stick_finger != -1 else Vector2(170, size.y - 170)
	var alpha := 0.5 if _stick_finger != -1 else 0.2
	draw_arc(base, STICK_RADIUS, 0.0, TAU, 32, Color(UiKit.TALLOW, alpha), 3.0)
	draw_circle(base + _stick_knob, 34.0, Color(UiKit.TALLOW, alpha))

	var buttons := _buttons()
	var labels := {"use": "Use", "light": "Torch", "pause": "", "plan": "Day"}
	for id: String in buttons:
		var spot: Array = buttons[id]
		var center: Vector2 = spot[0]
		var radius: float = spot[1]
		var active := (id == "use" and use_ready) or (id == "light" and light_on)
		draw_circle(center, radius, Color(UiKit.VESTMENT, 0.75 if active else 0.45))
		draw_arc(center, radius, 0.0, TAU, 32, UiKit.SODIUM if active else Color(UiKit.TALLOW, 0.5), 3.0)
		if id == "pause":
			draw_rect(Rect2(center + Vector2(-10, -12), Vector2(7, 24)), UiKit.TALLOW)
			draw_rect(Rect2(center + Vector2(3, -12), Vector2(7, 24)), UiKit.TALLOW)
		else:
			draw_string(font, center + Vector2(-radius, 9), labels[id], HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, 26 if radius > 40.0 else 21, UiKit.TALLOW)
