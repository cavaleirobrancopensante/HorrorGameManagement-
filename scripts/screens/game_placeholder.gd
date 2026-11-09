extends Control
## Stands in for the game until the trailer exists. Shows the loaded character
## and lets the save and death rules be tried on a real device.

var _column: VBoxContainer


func _ready() -> void:
	var background := ColorRect.new()
	background.color = UiKit.COMPLINE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 32)
	center.add_child(row)

	var portrait := CharacterPortrait.new()
	portrait.custom_minimum_size = Vector2(320, 384)
	portrait.character = Saves.current_character()
	row.add_child(portrait)

	_column = VBoxContainer.new()
	_column.custom_minimum_size.x = 560
	_column.alignment = BoxContainer.ALIGNMENT_CENTER
	_column.add_theme_constant_override("separation", 12)
	row.add_child(_column)
	_show_alive()


func _clear() -> void:
	for child in _column.get_children():
		_column.remove_child(child)
		child.queue_free()


func _show_alive() -> void:
	_clear()
	_column.add_child(UiKit.heading(Saves.current_character().full_name, 60))
	_column.add_child(UiKit.label("Day %d" % int(Saves.current.get("day", 1)), UiKit.SIZE_BODY, UiKit.LITURGICAL_GOLD))
	var survival: Dictionary = Saves.current.get("survival", {})
	_column.add_child(UiKit.label("Money %d, health %d of %d" % [
		int(survival.get("money", 0)), int(survival.get("health", 0)), int(survival.get("max_health", 0)),
	]))
	var needs: PackedStringArray = []
	for need: Dictionary in GameData.NEEDS:
		needs.append("%s %d" % [need["name"], int(survival.get(need["id"], 0))])
	_column.add_child(UiKit.label(", ".join(needs), UiKit.SIZE_SMALL, UiKit.ASH))
	_column.add_child(UiKit.wrapped_label("The trailer is not built yet. This screen is here so you can test saving and dying."))
	_column.add_child(UiKit.button("Save and return to menu", _save_and_leave))
	_column.add_child(UiKit.button("Test death", _ask_test_death))


func _save_and_leave() -> void:
	Saves.save_current()
	Router.goto("main_menu")


func _ask_test_death() -> void:
	ConfirmOverlay.ask(self, "Test death?", "This really ends this character.", "Die", "Live", _die)


func _die() -> void:
	Saves.kill_current("Died during testing.")
	_clear()
	_column.add_child(UiKit.heading("%s is dead." % Saves.current_character().full_name, 60))
	_column.add_child(UiKit.wrapped_label("This life is over. It can never be loaded again."))
	_column.add_child(UiKit.button("Return to menu", Router.goto.bind("main_menu")))


func go_back() -> void:
	if Saves.current.get("alive", false):
		_save_and_leave()
	else:
		Router.goto("main_menu")
