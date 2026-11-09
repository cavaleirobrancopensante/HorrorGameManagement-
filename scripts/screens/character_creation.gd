extends Control
## New game: person, temperament, examination of conscience, abilities.

const PAGE_TITLES := ["Person", "Temperament", "Conscience", "Abilities"]

var character := PlayerCharacter.new()
var _rng := RandomNumberGenerator.new()
var _page := 0
var _pages: Array[Control] = []
var _step_buttons: Array[Button] = []
var _refreshers: Array[Callable] = []

var _portrait: CharacterPortrait
var _summary_name: Label
var _summary_line: Label
var _summary_fault: Label
var _summary_stats := {}
var _status: Label
var _previous_button: Button
var _next_button: Button
var _name_edit: LineEdit
var _error := ""


func _ready() -> void:
	_rng.randomize()
	character.randomize_all(_rng)
	_build_layout()
	_show_page(0)


# Layout -----------------------------------------------------------------------

func _build_layout() -> void:
	var background := ColorRect.new()
	background.color = UiKit.COMPLINE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(margin)
	UiKit.apply_safe_area(margin, 14)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	column.add_child(_build_top_bar())

	var middle := HBoxContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override("separation", 16)
	column.add_child(middle)
	middle.add_child(_build_summary())

	var holder := Control.new()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	holder.clip_contents = true
	middle.add_child(holder)
	for build: Callable in [_build_person_page, _build_temperament_page, _build_conscience_page, _build_abilities_page]:
		var page: Control = build.call()
		page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		holder.add_child(page)
		_pages.append(page)

	column.add_child(_build_bottom_bar())


func _build_top_bar() -> Control:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	bar.add_child(UiKit.button("Menu", go_back, 120))
	for i in PAGE_TITLES.size():
		var step := UiKit.button("%d. %s" % [i + 1, PAGE_TITLES[i]], _show_page.bind(i))
		step.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.add_child(step)
		_step_buttons.append(step)
	bar.add_child(UiKit.button("Randomize all", _randomize_all, 210))
	return bar


func _build_summary() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 300
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	panel.add_child(column)

	_portrait = CharacterPortrait.new()
	_portrait.custom_minimum_size = Vector2(0, 240)
	_portrait.character = character
	column.add_child(_portrait)

	_summary_name = UiKit.label("", UiKit.SIZE_BODY, UiKit.TALLOW)
	_summary_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_summary_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(_summary_name)
	_summary_line = UiKit.label("", UiKit.SIZE_SMALL, UiKit.LITURGICAL_GOLD)
	_summary_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_summary_line)
	_summary_fault = UiKit.label("", UiKit.SIZE_SMALL, Color("#e8767c"))
	_summary_fault.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_summary_fault)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 0)
	column.add_child(grid)
	for def: Dictionary in GameData.STATS:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var short_name: String = {"marksmanship": "Aim"}.get(def["id"], def["name"])
		var title := UiKit.label(short_name, 20, UiKit.ASH)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(title)
		var value := UiKit.label("", 20, UiKit.TALLOW)
		row.add_child(value)
		grid.add_child(row)
		_summary_stats[def["id"]] = value
	return panel


func _build_bottom_bar() -> Control:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	_previous_button = UiKit.button("Previous", _go_previous, 150)
	bar.add_child(_previous_button)
	bar.add_child(UiKit.button("Randomize page", _randomize_page, 230))
	_status = UiKit.wrapped_label("", UiKit.SIZE_SMALL, UiKit.ASH)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(_status)
	_next_button = UiKit.button("Next", _go_next, 200)
	bar.add_child(_next_button)
	return bar


# Page 1: person ---------------------------------------------------------------

func _build_person_page() -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 10)
	column.add_child(name_row)
	var name_title := UiKit.label("Name")
	name_title.custom_minimum_size.x = 130
	name_row.add_child(name_title)
	_name_edit = LineEdit.new()
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.custom_minimum_size.y = UiKit.TOUCH_HEIGHT
	_name_edit.max_length = 28
	_name_edit.placeholder_text = "Your character's name"
	_name_edit.text_changed.connect(_on_name_changed)
	name_row.add_child(_name_edit)
	name_row.add_child(UiKit.button("Random name", _randomize_name, 190))
	_refreshers.append(func() -> void:
		if _name_edit.text != character.full_name:
			_name_edit.text = character.full_name
	)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 8)
	column.add_child(grid)
	for def: Dictionary in GameData.APPEARANCE:
		grid.add_child(_make_selector(def))
	return column


func _make_selector(def: Dictionary) -> Control:
	var id: String = def["id"]
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 4)
	var title := UiKit.label(def["label"], UiKit.SIZE_SMALL, UiKit.ASH)
	title.custom_minimum_size.x = 112
	row.add_child(title)
	var left := UiKit.button("‹", _cycle_appearance.bind(id, -1), 68)
	left.add_theme_font_size_override("font_size", 36)
	row.add_child(left)
	var value := UiKit.label("")
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(value)
	var right := UiKit.button("›", _cycle_appearance.bind(id, 1), 68)
	right.add_theme_font_size_override("font_size", 36)
	row.add_child(right)
	_refreshers.append(func() -> void:
		value.text = GameData.option_name(id, character.appearance[id])
		var locked: bool = id == "facial" and character.appearance["sex"] == "woman"
		left.disabled = locked
		right.disabled = locked
		value.modulate.a = 0.4 if locked else 1.0
	)
	return row


func _cycle_appearance(id: String, direction: int) -> void:
	var options: Array = GameData.appearance_def(id)["options"]
	var index := 0
	for i in options.size():
		if options[i][0] == character.appearance[id]:
			index = i
	character.appearance[id] = options[posmod(index + direction, options.size())][0]
	character.normalize_appearance()
	_refresh()


func _on_name_changed(text: String) -> void:
	character.full_name = text
	_error = ""
	_refresh_summary_and_status()


func _randomize_name() -> void:
	character.randomize_name(_rng)
	_refresh()


# Page 2: temperament ----------------------------------------------------------

func _build_temperament_page() -> Control:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	for def: Dictionary in GameData.TEMPERAMENTS:
		grid.add_child(_make_temperament_card(def))
	return grid


func _make_temperament_card(def: Dictionary) -> Control:
	var id: String = def["id"]
	var card := UiKit.button("", _choose_temperament.bind(id))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.clip_contents = true

	var inner := MarginContainer.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_theme_constant_override("margin_left", 18)
	inner.add_theme_constant_override("margin_right", 18)
	inner.add_theme_constant_override("margin_top", 10)
	inner.add_theme_constant_override("margin_bottom", 10)
	card.add_child(inner)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 4)
	inner.add_child(column)

	column.add_child(UiKit.heading(def["name"], 42))
	column.add_child(UiKit.wrapped_label(def["tagline"]))
	column.add_child(UiKit.wrapped_label(_temperament_stats_text(def), UiKit.SIZE_SMALL, UiKit.LITURGICAL_GOLD))
	var sin_names: Array = def["inclined"].map(func(sin_id: String) -> String: return GameData.sin_def(sin_id)["sin"])
	column.add_child(UiKit.wrapped_label("More easily tempted by %s and %s." % sin_names, UiKit.SIZE_SMALL, Color("#e8767c")))
	_set_children_ignore_mouse(column)

	_refreshers.append(func() -> void:
		if character.temperament == id:
			UiKit.paint(card, UiKit.VESTMENT_LIGHT, UiKit.SODIUM, 4)
		else:
			UiKit.paint(card, UiKit.VESTMENT, UiKit.VESTMENT_LIGHT, 2)
	)
	return card


func _set_children_ignore_mouse(parent: Control) -> void:
	for child in parent.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE


func _temperament_stats_text(def: Dictionary) -> String:
	var parts: PackedStringArray = []
	for stat_id: String in def["stats"]:
		parts.append("%s %+d" % [GameData.stat_def(stat_id)["name"], def["stats"][stat_id]])
	return ", ".join(parts)


func _choose_temperament(id: String) -> void:
	character.temperament = id
	_refresh()


# Page 3: conscience -----------------------------------------------------------

func _build_conscience_page() -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	for def: Dictionary in GameData.SINS:
		column.add_child(_make_sin_row(def))
	return column


func _make_sin_row(def: Dictionary) -> Control:
	var id: String = def["id"]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var virtue := UiKit.wrapped_label(def["virtue"], UiKit.SIZE_SMALL, UiKit.LITURGICAL_GOLD)
	virtue.size_flags_horizontal = Control.SIZE_FILL
	virtue.custom_minimum_size.x = 150
	virtue.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(virtue)

	var segments: Array[Button] = []
	for level in range(GameData.MIN_SIN_LEVEL, GameData.MAX_SIN_LEVEL + 1):
		var segment := UiKit.button("", _set_sin.bind(id, level), 60)
		segment.custom_minimum_size.y = 58
		segment.size_flags_vertical = Control.SIZE_EXPAND_FILL
		row.add_child(segment)
		segments.append(segment)

	var sin_label := UiKit.label(def["sin"], UiKit.SIZE_SMALL, Color("#e8767c"))
	sin_label.custom_minimum_size.x = 92
	row.add_child(sin_label)

	var effect := UiKit.wrapped_label("", 20, UiKit.TALLOW)
	row.add_child(effect)

	_refreshers.append(func() -> void:
		var current: int = character.sins[id]
		for i in segments.size():
			var level := GameData.MIN_SIN_LEVEL + i
			var fill := _sin_segment_colour(level)
			if level == current:
				UiKit.paint(segments[i], fill, UiKit.TALLOW, 4)
			else:
				UiKit.paint(segments[i], fill.darkened(0.62), Color(fill, 0.45), 2)
		effect.text = _sin_effect_text(def, current)
	)
	return row


func _sin_segment_colour(level: int) -> Color:
	match level:
		-2: return UiKit.LITURGICAL_GOLD
		-1: return Color("#9c8a55")
		1: return Color("#a03a42")
		2: return Color("#d9303c")
	return Color("#6d6275")


func _sin_effect_text(def: Dictionary, level: int) -> String:
	var parts: PackedStringArray = []
	var bonus: Dictionary = def["vice_bonus"] if level > 0 else def["virtue_bonus"]
	if level != 0:
		for stat_id: String in bonus:
			parts.append("%s +%d" % [GameData.stat_def(stat_id)["name"], absi(level) * int(bonus[stat_id])])
	parts.append("temptation %d%%" % roundi(character.temptation_strength(def["id"]) * 100.0))
	parts[0] = parts[0].capitalize() if parts.size() == 1 else parts[0]
	return "%s. %s" % [GameData.LEVEL_NAMES[level], ", ".join(parts)]


func _set_sin(id: String, level: int) -> void:
	if character.set_sin_level(id, level):
		_error = ""
	else:
		_error = "You need another struggle before you can be that strong."
	_refresh()


# Page 4: abilities ------------------------------------------------------------

func _build_abilities_page() -> Control:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 6)
	for def: Dictionary in GameData.STATS:
		grid.add_child(_make_ability_row(def))
	return grid


func _make_ability_row(def: Dictionary) -> Control:
	var id: String = def["id"]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var text_column := VBoxContainer.new()
	text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_column.alignment = BoxContainer.ALIGNMENT_CENTER
	text_column.add_child(UiKit.label(def["name"]))
	text_column.add_child(UiKit.wrapped_label(def["desc"], 20, UiKit.ASH))
	row.add_child(text_column)

	var minus := UiKit.button("−", _change_point.bind(id, -1), 68)
	minus.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(minus)
	var value := UiKit.label("", 34, UiKit.SODIUM)
	value.custom_minimum_size.x = 50
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(value)
	var plus := UiKit.button("+", _change_point.bind(id, 1), 68)
	plus.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(plus)

	_refreshers.append(func() -> void:
		value.text = str(character.stat_value(id))
		minus.disabled = character.free_points[id] <= 0
		plus.disabled = character.free_points_left() <= 0 or character.free_points[id] >= GameData.MAX_FREE_PER_STAT
	)
	return row


func _change_point(id: String, delta: int) -> void:
	character.change_free_point(id, delta)
	_refresh()


# Navigation and randomizing ---------------------------------------------------

func _show_page(index: int) -> void:
	_page = index
	_error = ""
	for i in _pages.size():
		_pages[i].visible = i == index
	_refresh()


func _go_previous() -> void:
	if _page > 0:
		_show_page(_page - 1)


func _go_next() -> void:
	if _page < _pages.size() - 1:
		_show_page(_page + 1)
	else:
		_try_begin()


func _randomize_all() -> void:
	character.randomize_all(_rng)
	_error = ""
	_refresh()


func _randomize_page() -> void:
	_error = ""
	match _page:
		0:
			character.randomize_appearance(_rng)
			character.randomize_name(_rng)
		1:
			character.randomize_temperament(_rng)
		2:
			character.randomize_sins(_rng)
		3:
			character.randomize_free_points(_rng)
	_refresh()


## Leaving to the menu discards the unfinished character, so it asks first.
func go_back() -> void:
	ConfirmOverlay.ask(self, "Leave character creation?", "This character will be lost.", "Leave", "Stay", Router.goto.bind("main_menu"))


# Starting the game ------------------------------------------------------------

func _try_begin() -> void:
	var problem := character.validation_error()
	if not problem.is_empty():
		_show_page(0 if character.full_name.strip_edges().is_empty() else 2)
		_error = problem
		_refresh()
		return
	ConfirmOverlay.ask(self, "One life", "If %s dies, this save ends for good. There is no reloading and no second chance." % character.full_name.strip_edges(), "Begin", "Not yet", _begin)


func _begin() -> void:
	var slot := Saves.first_empty_slot()
	if slot == -1:
		SlotsPanel.open(self, true, _begin_in_slot)
	else:
		_begin_in_slot(slot)


func _begin_in_slot(slot: int) -> void:
	character.full_name = character.full_name.strip_edges()
	if Saves.start_new(character, slot):
		Sound.bell()
		Router.goto("game")
	else:
		_error = "The save file could not be written. Check the device's free space."
		_refresh()


# Refresh ----------------------------------------------------------------------

func _refresh() -> void:
	for refresher: Callable in _refreshers:
		refresher.call()
	for i in _step_buttons.size():
		if i == _page:
			UiKit.paint(_step_buttons[i], UiKit.VESTMENT_LIGHT, UiKit.SODIUM)
		else:
			UiKit.paint(_step_buttons[i], UiKit.VESTMENT, UiKit.VESTMENT_LIGHT)
	_previous_button.disabled = _page == 0
	_next_button.text = "Begin" if _page == _pages.size() - 1 else "Next"
	_portrait.queue_redraw()
	_refresh_summary_and_status()


func _refresh_summary_and_status() -> void:
	_summary_name.text = character.full_name if not character.full_name.strip_edges().is_empty() else "Unnamed"
	_summary_line.text = GameData.temperament_def(character.temperament)["name"]
	var fault := character.predominant_fault()
	_summary_fault.text = "No struggle chosen" if fault.is_empty() else "Worst struggle: %s" % GameData.sin_def(fault)["sin"]
	for id: String in _summary_stats:
		_summary_stats[id].text = str(character.stat_value(id))
	_status.add_theme_color_override("font_color", Color("#e8767c") if not _error.is_empty() else UiKit.ASH)
	_status.text = _error if not _error.is_empty() else _page_hint()


func _page_hint() -> String:
	match _page:
		1:
			return "Your natural disposition. Grace can build on it."
		2:
			return "Virtue steps left: %d. Each struggle allows one." % character.strengths_left()
		3:
			return "Points left: %d." % character.free_points_left()
	return ""
