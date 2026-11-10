class_name TouchControls
extends Control
## Phone controls: a stick wherever the left thumb lands, drag anywhere on the
## right to look, and buttons for use, torch and pause. Every finger is tracked
## on its own, so you can walk, look and press at the same time.
##
## If a finger's release is ever lost, a new finger on the left still takes the
## stick and a new finger on the right still takes the look. The look follows
## each finger's own last position.

signal use_pressed
signal light_pressed
signal pause_pressed
signal plan_pressed
signal hand_pressed
signal arm_pressed
## What the Arm button says: the weapon in hand, or "Arm".
var arm_label := "Arm"

const STICK_RADIUS := 90.0
const LOOK_SPEED := 0.0055

var player: Player
var use_ready := false
var light_on := false
var hand_ready := false
var _stick_finger := -1
var _stick_origin := Vector2.ZERO
var _stick_knob := Vector2.ZERO
var _look_finger := -1
var _look_last := Vector2.ZERO
## In the browser the fingers are read straight from the page: Godot's web
## build mixes up which finger lifted when several are down. Each frame the
## page's own list of touches (every finger keeps its identity) is compared
## with the last frame's.
var _web := false
var _web_fingers := {}

const WEB_SETUP := """
(function () {
	if (window.__dailyBreadTouches) return;
	window.__dailyBreadTouches = {};
	function read(e) {
		var now = {};
		for (var i = 0; i < e.touches.length; i++) {
			var t = e.touches[i];
			now[t.identifier] = [t.clientX, t.clientY];
		}
		window.__dailyBreadTouches = now;
	}
	['touchstart', 'touchmove', 'touchend', 'touchcancel'].forEach(function (name) {
		window.addEventListener(name, read, {passive: true, capture: true});
	});
})();
"""
const WEB_READ := "JSON.stringify({w: window.innerWidth, h: window.innerHeight, t: window.__dailyBreadTouches || {}})"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_web = OS.has_feature("web")
	if _web:
		JavaScriptBridge.eval(WEB_SETUP, true)


func _process(_delta: float) -> void:
	if not _web or not visible or not is_processing_input():
		return
	var data: Variant = JSON.parse_string(str(JavaScriptBridge.eval(WEB_READ, true)))
	if not (data is Dictionary) or float(data.get("w", 0)) <= 0.0:
		return
	var scale := size / Vector2(float(data["w"]), float(data["h"]))
	var seen := {}
	var touches: Dictionary = data["t"]
	for id: String in touches:
		var point: Array = touches[id]
		var finger := 1000 + int(id)
		var at := Vector2(float(point[0]), float(point[1])) * scale
		seen[finger] = at
		if _web_fingers.has(finger):
			_move(finger, at)
		else:
			_press(finger, at)
	for finger: int in _web_fingers:
		if not seen.has(finger):
			_release(finger)
	_web_fingers = seen
	queue_redraw()


func _buttons() -> Dictionary:
	return {
		"use": [Vector2(size.x - 140, size.y - 150), 74.0],
		"light": [Vector2(size.x - 290, size.y - 85), 50.0],
		"pause": [Vector2(size.x - 60, 52), 38.0],
		"plan": [Vector2(size.x - 60, 140), 38.0],
		"hand": [Vector2(size.x - 285, size.y - 205), 50.0],
		"arm": [Vector2(size.x - 140, size.y - 305), 50.0],
	}


func reset() -> void:
	_web_fingers.clear()
	_stick_finger = -1
	_look_finger = -1
	_stick_knob = Vector2.ZERO
	if player != null:
		player.move_input = Vector2.ZERO
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible or _web:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_press(touch.index, touch.position)
		else:
			_release(touch.index)
		queue_redraw()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		_move(drag.index, drag.position)


func _release(finger: int) -> void:
	if finger == _stick_finger:
		_stick_finger = -1
		_stick_knob = Vector2.ZERO
		player.move_input = Vector2.ZERO
	elif finger == _look_finger:
		_look_finger = -1


func _move(finger: int, at: Vector2) -> void:
	if finger == _stick_finger:
		_stick_knob = (at - _stick_origin).limit_length(STICK_RADIUS)
		player.move_input = _stick_knob / STICK_RADIUS
		queue_redraw()
	elif finger == _look_finger:
		player.look((at - _look_last) * LOOK_SPEED)
		_look_last = at


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
				"hand":
					hand_pressed.emit()
				"arm":
					arm_pressed.emit()
					queue_redraw()
			return
	if at.x < size.x * 0.42:
		if finger == _look_finger:
			_look_finger = -1
		_stick_finger = finger
		_stick_origin = at
		_stick_knob = Vector2.ZERO
		player.move_input = Vector2.ZERO
	else:
		if finger == _stick_finger:
			_stick_finger = -1
			_stick_knob = Vector2.ZERO
			player.move_input = Vector2.ZERO
		_look_finger = finger
		_look_last = at


func _draw() -> void:
	var font := get_theme_default_font()
	var base := _stick_origin if _stick_finger != -1 else Vector2(170, size.y - 170)
	var alpha := 0.5 if _stick_finger != -1 else 0.2
	draw_arc(base, STICK_RADIUS, 0.0, TAU, 32, Color(UiKit.TALLOW, alpha), 3.0)
	draw_circle(base + _stick_knob, 34.0, Color(UiKit.TALLOW, alpha))

	var buttons := _buttons()
	var labels := {"use": "Use", "light": "Torch", "pause": "", "plan": "Day", "hand": "Eat", "arm": arm_label}
	for id: String in buttons:
		var spot: Array = buttons[id]
		var center: Vector2 = spot[0]
		var radius: float = spot[1]
		var active := (id == "use" and use_ready) or (id == "light" and light_on) or (id == "hand" and hand_ready) or (id == "arm" and arm_label != "Arm")
		draw_circle(center, radius, Color(UiKit.VESTMENT, 0.75 if active else 0.45))
		draw_arc(center, radius, 0.0, TAU, 32, UiKit.SODIUM if active else Color(UiKit.TALLOW, 0.5), 3.0)
		if id == "pause":
			draw_rect(Rect2(center + Vector2(-10, -12), Vector2(7, 24)), UiKit.TALLOW)
			draw_rect(Rect2(center + Vector2(3, -12), Vector2(7, 24)), UiKit.TALLOW)
		else:
			draw_string(font, center + Vector2(-radius, 9), labels[id], HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, 26 if radius > 40.0 else 21, UiKit.TALLOW)
