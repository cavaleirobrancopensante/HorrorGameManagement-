extends Node
## Moves between screens and handles the Android back button and Escape.

const SCENES := {
	"main_menu": "res://scenes/main_menu.tscn",
	"character_creation": "res://scenes/character_creation.tscn",
	"game": "res://scenes/trailer.tscn",
}


const KEYS := {
	"move_forward": [KEY_W, KEY_UP],
	"move_back": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"interact": [KEY_E],
	"flashlight": [KEY_F],
	"plan_day": [KEY_C],
	"use_hand": [KEY_Q],
}


func _ready() -> void:
	get_window().theme = UiKit.build_theme()
	for action: String in KEYS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key: Key in KEYS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)


func goto(screen: String) -> void:
	get_tree().change_scene_to_file(SCENES[screen])


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		go_back()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		go_back()


## Closes the newest popup if there is one, otherwise asks the screen to step back.
func go_back() -> void:
	var modals := get_tree().get_nodes_in_group("modal")
	if not modals.is_empty():
		modals[-1].go_back()
		return
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("go_back"):
		scene.go_back()
