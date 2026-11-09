class_name SlotsPanel
extends Control
## The ten save files. Used to load a life, or to choose one to replace.

signal slot_chosen(slot: int)

var overwrite_mode := false
var _grid: GridContainer


static func open(parent: Node, overwrite: bool, on_chosen: Callable) -> SlotsPanel:
	var panel := SlotsPanel.new()
	panel.overwrite_mode = overwrite
	panel.add_to_group("modal")
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.slot_chosen.connect(on_chosen)
	parent.add_child(panel)
	panel._build()
	return panel


func go_back() -> void:
	queue_free()
	remove_from_group("modal")


func _build() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.06, 0.04, 0.09, 0.985)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(margin)
	UiKit.apply_safe_area(margin, 20)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)
	column.add_child(header)
	header.add_child(UiKit.button("Back", go_back, 140))
	var title_text := "All ten save files are full. Choose one to replace." if overwrite_mode else "Load game"
	header.add_child(UiKit.heading(title_text, 40 if overwrite_mode else UiKit.SIZE_HEADING))

	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 14)
	_grid.add_theme_constant_override("v_separation", 8)
	_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_grid)
	_refresh()


func _refresh() -> void:
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	for slot in Saves.SLOT_COUNT:
		_grid.add_child(_make_slot(slot))


func _make_slot(slot: int) -> Control:
	var data := Saves.read_slot(slot)
	var empty := data.is_empty()
	var damaged := data.has("damaged")
	var dead: bool = not empty and not damaged and not data.get("alive", false)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var main := UiKit.button("", _choose.bind(slot, empty, damaged, dead))
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.custom_minimum_size.y = 96
	main.alignment = HORIZONTAL_ALIGNMENT_LEFT
	main.text = _slot_text(slot, data, empty, damaged, dead)
	main.add_theme_font_size_override("font_size", UiKit.SIZE_SMALL + 2)
	if not overwrite_mode and (empty or damaged or dead):
		main.disabled = true
	if dead:
		UiKit.paint(main, Color("#1c0f14"), Color("#54242c"))
		main.add_theme_color_override("font_disabled_color", UiKit.ASH)
	row.add_child(main)

	if not empty:
		var delete_text := "Clear" if damaged or dead else "Delete"
		var delete_button := UiKit.button(delete_text, _ask_delete.bind(slot, data, damaged, dead), 96)
		delete_button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		delete_button.add_theme_font_size_override("font_size", UiKit.SIZE_SMALL)
		row.add_child(delete_button)
	return row


func _slot_text(slot: int, data: Dictionary, empty: bool, damaged: bool, dead: bool) -> String:
	var number := "%d." % (slot + 1)
	if empty:
		return "%s Empty" % number
	if damaged:
		return "%s This save file is damaged and cannot be read." % number
	var character := PlayerCharacter.from_dict(data["character"])
	var temperament: String = GameData.temperament_def(character.temperament)["name"]
	var day := int(data.get("day", 1))
	if dead:
		return "%s † %s\nDied on day %d. %s" % [number, character.full_name, day, str(data.get("death_cause", ""))]
	var when := Time.get_date_string_from_unix_time(int(data.get("updated", 0.0)))
	return "%s %s\n%s, day %d, last played %s" % [number, character.full_name, temperament, day, when]


func _choose(slot: int, empty: bool, damaged: bool, dead: bool) -> void:
	if overwrite_mode:
		ConfirmOverlay.ask(self, "Replace this save?", "The life stored in file %d will be gone for good." % (slot + 1), "Replace", "Keep it", slot_chosen.emit.bind(slot))
	elif not empty and not damaged and not dead:
		slot_chosen.emit(slot)


func _ask_delete(slot: int, data: Dictionary, damaged: bool, dead: bool) -> void:
	var who := "this file"
	if not damaged:
		who = PlayerCharacter.from_dict(data["character"]).full_name
	var body := "Remove the memorial of %s?" % who if dead else "Delete %s for good? This cannot be undone." % who
	ConfirmOverlay.ask(self, "Delete save?", body, "Delete", "Keep it", _delete.bind(slot))


func _delete(slot: int) -> void:
	Saves.delete_slot(slot)
	_refresh()
