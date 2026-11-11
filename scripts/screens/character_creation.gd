extends Control
## New game, in four steps: who you are, your temperament, your conscience,
## your abilities. Your character stands on the left in 3D as you build them;
## each step says in a sentence what it is for; every control has a tooltip,
## and the help line along the bottom repeats it for touch screens.

const STEPS := [
	["Who you are", "Your name and how you look. This is who you will see in the mirror and on the cameras."],
	["Temperament", "Your natural character. It shapes your abilities and the sins that tempt you most. There is no wrong choice."],
	["Conscience", "Mark the sins you struggle with. A struggle tempts you more but sharpens a skill. To be strong in a virtue, you need a struggle somewhere else."],
	["Abilities", "Spend your remaining points on what you are good at. Point at any ability to see what it does."],
]
## The looks you choose on the first step, in the order they are shown.
const LOOKS := ["sex", "head", "skin", "hair_colour", "top", "top_colour", "legs", "feet", "apron"]

var character := PlayerCharacter.new()
var _rng := RandomNumberGenerator.new()
var _step := 0
var _pages: Array[Control] = []
var _refreshers: Array[Callable] = []

var _step_title: Label
var _step_text: Label
var _step_dots: Array[Panel] = []
var _back_button: Button
var _next_button: Button
var _name_edit: LineEdit
var _summary: Label
var _status: Label
var _error := ""

var _preview_world: SubViewport
var _preview_holder: Node3D
var _preview_rig: PersonRig
var _preview_look := ""
var _preview_turn := PI + 0.35
var _dragging := false


func _ready() -> void:
	_rng.randomize()
	character.randomize_all(_rng)
	_build()
	_show_step(0)


# Layout -----------------------------------------------------------------------

func _build() -> void:
	var background := ColorRect.new()
	background.color = UiKit.COMPLINE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(margin)
	UiKit.apply_safe_area(margin, 14)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 18)
	margin.add_child(columns)
	columns.add_child(_build_preview())

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	columns.add_child(right)
	right.add_child(_build_header())

	var holder := Control.new()
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	holder.clip_contents = true
	right.add_child(holder)
	for build: Callable in [_build_looks_page, _build_temperament_page, _build_conscience_page, _build_abilities_page]:
		var scroll := ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var page: Control = build.call()
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		page.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.add_child(page)
		holder.add_child(scroll)
		_pages.append(scroll)

	_status = UiKit.label("", UiKit.SIZE_SMALL, Color("#e8767c"))
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(_status)
	right.add_child(_build_footer())
	var help := UiKit.help_line("Point at, or touch, anything to see what it does.")
	help.custom_minimum_size.y = 34
	right.add_child(help)


## Your character in 3D, turning. Drag to turn them yourself.
func _build_preview() -> Control:
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 340
	column.add_theme_constant_override("separation", 6)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	top.add_child(UiKit.tip(UiKit.button("Menu", go_back, 110), Tips.CREATION["menu"]))
	var random_all := UiKit.button("Random character", _randomize_all)
	random_all.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(UiKit.tip(random_all, Tips.CREATION["randomize_all"]))
	column.add_child(top)

	var frame := SubViewportContainer.new()
	frame.stretch = true
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	frame.gui_input.connect(_on_preview_input)
	UiKit.tip(frame, Tips.CREATION["preview"])
	column.add_child(frame)
	_preview_world = SubViewport.new()
	_preview_world.own_world_3d = true
	_preview_world.transparent_bg = false
	frame.add_child(_preview_world)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#1c1426")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#8a7a96")
	env.ambient_light_energy = 0.7
	environment.environment = env
	_preview_world.add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35.0, -30.0, 0.0)
	key.light_energy = 1.1
	key.light_color = Color("#ffe2b8")
	_preview_world.add_child(key)
	var rim := OmniLight3D.new()
	rim.position = Vector3(-1.2, 2.2, -1.2)
	rim.light_color = Color("#a07ad0")
	rim.light_energy = 1.4
	rim.omni_range = 5.0
	_preview_world.add_child(rim)
	var floor_disc := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.6
	disc.bottom_radius = 0.6
	disc.height = 0.04
	floor_disc.mesh = disc
	floor_disc.position.y = -0.02
	floor_disc.material_override = TextureFactory.plain(Color("#2b1b3a"))
	_preview_world.add_child(floor_disc)
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 1.05, 2.9)
	camera.rotation_degrees.x = -4.0
	camera.fov = 42.0
	_preview_world.add_child(camera)
	_preview_holder = Node3D.new()
	_preview_world.add_child(_preview_holder)

	_summary = UiKit.wrapped_label("", UiKit.SIZE_SMALL, UiKit.TALLOW)
	_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_summary)
	return column


func _build_header() -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_step_title = UiKit.heading("", 46)
	_step_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_step_title)
	for i in STEPS.size():
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(34, 10)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.tooltip_text = "Step %d: %s" % [i + 1, STEPS[i][0]]
		row.add_child(dot)
		_step_dots.append(dot)
	column.add_child(row)
	_step_text = UiKit.wrapped_label("", UiKit.SIZE_SMALL, UiKit.ASH)
	column.add_child(_step_text)
	return column


func _build_footer() -> Control:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	_back_button = UiKit.tip(UiKit.button("‹  Back", _go_back_step, 170), Tips.CREATION["back"]) as Button
	bar.add_child(_back_button)
	var random_step := UiKit.button("Randomize this step", _randomize_step)
	random_step.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(UiKit.tip(random_step, Tips.CREATION["randomize_step"]))
	_next_button = UiKit.button("Next  ›", _go_next_step, 220)
	UiKit.paint(_next_button, Color("#65421f"), UiKit.SODIUM, 3)
	bar.add_child(_next_button)
	return bar


# Step 1: who you are -----------------------------------------------------------

func _build_looks_page() -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 10)
	column.add_child(name_row)
	var title := UiKit.label("Name")
	title.custom_minimum_size.x = 150
	name_row.add_child(title)
	_name_edit = LineEdit.new()
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.custom_minimum_size.y = UiKit.TOUCH_HEIGHT
	_name_edit.max_length = 28
	_name_edit.placeholder_text = "Type a name"
	_name_edit.text_changed.connect(_on_name_changed)
	UiKit.tip(_name_edit, Tips.CREATION["name"])
	name_row.add_child(_name_edit)
	name_row.add_child(UiKit.tip(UiKit.button("Random name", _randomize_name, 200), Tips.CREATION["random_name"]))
	_refreshers.append(func() -> void:
		if _name_edit.text != character.full_name:
			_name_edit.text = character.full_name)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 8)
	column.add_child(grid)
	for id: String in LOOKS:
		grid.add_child(_make_chooser(id))
	return column


## "Label  ‹  value  ›": each arrow steps through the choices.
func _make_chooser(id: String) -> Control:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 4)
	var label := UiKit.label(GameData.appearance_def(id)["label"], UiKit.SIZE_SMALL, UiKit.ASH)
	label.custom_minimum_size.x = 130
	label.mouse_filter = Control.MOUSE_FILTER_STOP
	UiKit.tip(label, Tips.CREATION.get(id, ""))
	row.add_child(label)
	var left := UiKit.button("‹", _cycle.bind(id, -1), 64)
	left.add_theme_font_size_override("font_size", 34)
	row.add_child(UiKit.tip(left, Tips.CREATION.get(id, "")))
	var value := UiKit.label("")
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(value)
	var right := UiKit.button("›", _cycle.bind(id, 1), 64)
	right.add_theme_font_size_override("font_size", 34)
	row.add_child(UiKit.tip(right, Tips.CREATION.get(id, "")))
	_refreshers.append(func() -> void:
		value.text = GameData.option_name(id, character.appearance[id], character.appearance["sex"]))
	return row


func _cycle(id: String, direction: int) -> void:
	var options := GameData.options_for(id, character.appearance["sex"])
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
	_refresh_status()


func _randomize_name() -> void:
	character.randomize_name(_rng)
	_refresh()


# Step 2: temperament ------------------------------------------------------------

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
	card.custom_minimum_size.y = 236
	card.clip_contents = true
	var stats := _stats_text(def["stats"])
	var sins: Array = def["inclined"].map(func(sin_id: String) -> String: return GameData.sin_def(sin_id)["sin"])
	UiKit.tip(card, "%s: %s Abilities: %s. More easily tempted by %s and %s." % [def["name"], def["tagline"], stats, sins[0], sins[1]])
	var inner := MarginContainer.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		inner.add_theme_constant_override("margin_" + side, 14)
	card.add_child(inner)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(column)
	column.add_child(UiKit.heading(def["name"], 38))
	column.add_child(UiKit.wrapped_label(def["tagline"], UiKit.SIZE_SMALL))
	column.add_child(UiKit.wrapped_label("Good at: " + stats, 20, UiKit.LITURGICAL_GOLD))
	column.add_child(UiKit.wrapped_label("Tempted by: %s, %s" % sins, 20, Color("#e8767c")))
	for child in column.get_children():
		(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refreshers.append(func() -> void:
		if character.temperament == id:
			UiKit.paint(card, UiKit.VESTMENT_LIGHT, UiKit.SODIUM, 4)
		else:
			UiKit.paint(card, UiKit.VESTMENT, UiKit.VESTMENT_LIGHT, 2))
	return card


func _stats_text(stats: Dictionary) -> String:
	var parts: PackedStringArray = []
	for stat_id: String in stats:
		parts.append("%s %+d" % [GameData.stat_def(stat_id)["name"], stats[stat_id]])
	return ", ".join(parts)


func _choose_temperament(id: String) -> void:
	character.temperament = id
	_refresh()


# Step 3: conscience -------------------------------------------------------------

func _build_conscience_page() -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	# A legend over the five steps of each row.
	var legend := HBoxContainer.new()
	legend.add_theme_constant_override("separation", 4)
	var spacer := Control.new()
	spacer.custom_minimum_size.x = 230
	legend.add_child(spacer)
	for level in range(GameData.MIN_SIN_LEVEL, GameData.MAX_SIN_LEVEL + 1):
		var name := UiKit.label(GameData.LEVEL_NAMES[level].replace(" ", "\n"), 16, _level_colour(level))
		name.custom_minimum_size.x = 64
		name.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		name.size_flags_vertical = Control.SIZE_FILL
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		legend.add_child(name)
	column.add_child(legend)
	for def: Dictionary in GameData.SINS:
		column.add_child(_make_sin_row(def))
	var left := UiKit.label("", UiKit.SIZE_SMALL, UiKit.LITURGICAL_GOLD)
	column.add_child(left)
	_refreshers.append(func() -> void:
		left.text = "Virtue steps you can still take: %d (each struggle allows one)" % character.strengths_left())
	return column


func _make_sin_row(def: Dictionary) -> Control:
	var id: String = def["id"]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var names := VBoxContainer.new()
	names.custom_minimum_size.x = 230
	names.add_theme_constant_override("separation", -6)
	names.add_child(UiKit.label(def["virtue"], 18, UiKit.LITURGICAL_GOLD))
	names.add_child(UiKit.label("against " + def["sin"], 18, Color("#e8767c")))
	row.add_child(names)
	var segments: Array[Button] = []
	for level in range(GameData.MIN_SIN_LEVEL, GameData.MAX_SIN_LEVEL + 1):
		var segment := UiKit.button("", _set_sin.bind(id, level), 64)
		segment.custom_minimum_size.y = 50
		UiKit.tip(segment, "%s: %s" % [def["sin"], _sin_text(def, level)])
		row.add_child(segment)
		segments.append(segment)
	var effect := UiKit.wrapped_label("", 18, UiKit.TALLOW)
	effect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(effect)
	_refreshers.append(func() -> void:
		var current: int = character.sins[id]
		for i in segments.size():
			var level := GameData.MIN_SIN_LEVEL + i
			var fill := _level_colour(level)
			if level == current:
				UiKit.paint(segments[i], fill, UiKit.TALLOW, 4)
			else:
				UiKit.paint(segments[i], fill.darkened(0.62), Color(fill, 0.45), 2)
		effect.text = _sin_text(def, current))
	return row


func _level_colour(level: int) -> Color:
	match level:
		-2: return UiKit.LITURGICAL_GOLD
		-1: return Color("#9c8a55")
		1: return Color("#a03a42")
		2: return Color("#d9303c")
	return Color("#6d6275")


func _sin_text(def: Dictionary, level: int) -> String:
	var parts: PackedStringArray = []
	var bonus: Dictionary = def["vice_bonus"] if level > 0 else def["virtue_bonus"]
	if level != 0:
		for stat_id: String in bonus:
			parts.append("%s +%d" % [GameData.stat_def(stat_id)["name"], absi(level) * int(bonus[stat_id])])
	var strength := 1.0
	match level:
		-2: strength = 0.4
		-1: strength = 0.7
		1: strength = 1.4
		2: strength = 1.9
	parts.append("tempted %s" % ("far less" if strength < 0.5 else ("less" if strength < 1.0 else ("as usual" if strength == 1.0 else ("more" if strength < 1.5 else "far more")))))
	return "%s: %s" % [GameData.LEVEL_NAMES[level], ", ".join(parts)]


func _set_sin(id: String, level: int) -> void:
	if character.set_sin_level(id, level):
		_error = ""
	else:
		_error = "To be that strong in a virtue, first mark a struggle with another sin."
	_refresh()


# Step 4: abilities --------------------------------------------------------------

func _build_abilities_page() -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	var left := UiKit.label("", 30, UiKit.SODIUM)
	column.add_child(left)
	_refreshers.append(func() -> void:
		var points := character.free_points_left()
		left.text = "%d point%s left to spend" % [points, "" if points == 1 else "s"])
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 6)
	column.add_child(grid)
	for def: Dictionary in GameData.STATS:
		grid.add_child(_make_ability_row(def))
	return column


func _make_ability_row(def: Dictionary) -> Control:
	var id: String = def["id"]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", -4)
	text.mouse_filter = Control.MOUSE_FILTER_STOP
	UiKit.tip(text, "%s: %s" % [def["name"], def["desc"]])
	text.add_child(UiKit.label(def["name"]))
	text.add_child(UiKit.wrapped_label(def["desc"], 18, UiKit.ASH))
	row.add_child(text)
	var minus := UiKit.button("−", _change_point.bind(id, -1), 60)
	row.add_child(UiKit.tip(minus, "Take a point out of %s." % def["name"]))
	var value := UiKit.label("", 32, UiKit.SODIUM)
	value.custom_minimum_size.x = 46
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(value)
	var plus := UiKit.button("+", _change_point.bind(id, 1), 60)
	row.add_child(UiKit.tip(plus, "Put a point into %s." % def["name"]))
	_refreshers.append(func() -> void:
		value.text = str(character.stat_value(id))
		minus.disabled = character.free_points[id] <= 0
		plus.disabled = character.free_points_left() <= 0 or character.free_points[id] >= GameData.MAX_FREE_PER_STAT)
	return row


func _change_point(id: String, delta: int) -> void:
	character.change_free_point(id, delta)
	_refresh()


# The preview --------------------------------------------------------------------

func _process(delta: float) -> void:
	if _preview_rig == null:
		return
	if not _dragging:
		_preview_turn = lerp_angle(_preview_turn, PI + 0.35 + sin(Time.get_ticks_msec() / 2400.0) * 0.25, delta * 1.5)
	_preview_holder.rotation.y = _preview_turn


func _on_preview_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
	elif event is InputEventScreenTouch:
		_dragging = event.pressed
	elif event is InputEventMouseMotion and _dragging:
		_preview_turn += (event as InputEventMouseMotion).relative.x * 0.012
	elif event is InputEventScreenDrag:
		_preview_turn += (event as InputEventScreenDrag).relative.x * 0.012


## Builds the 3D figure again when the looks change.
func _update_preview() -> void:
	var recipe := People.player(character)
	var key := str(recipe)
	if key == _preview_look:
		return
	_preview_look = key
	if _preview_rig != null:
		_preview_rig.queue_free()
	_preview_rig = People.place(_preview_holder, recipe, Vector3.ZERO, 0.0)
	_preview_rig.rotation.y = 0.0


# Steps --------------------------------------------------------------------------

func _show_step(index: int) -> void:
	_step = index
	_error = ""
	for i in _pages.size():
		_pages[i].visible = i == index
	_refresh()


func _go_back_step() -> void:
	if _step > 0:
		_show_step(_step - 1)


func _go_next_step() -> void:
	if _step == 0 and character.full_name.strip_edges().is_empty():
		_error = "Give your character a name first, or press Random name."
		_refresh_status()
		return
	if _step < _pages.size() - 1:
		_show_step(_step + 1)
	else:
		_try_begin()


func _randomize_all() -> void:
	character.randomize_all(_rng)
	_error = ""
	_refresh()


func _randomize_step() -> void:
	_error = ""
	match _step:
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


## Leaving to the menu loses the unfinished character, so it asks first.
func go_back() -> void:
	ConfirmOverlay.ask(self, "Leave character creation?", "This character will be lost.", "Leave", "Stay", Router.goto.bind("main_menu"))


# Starting the game ----------------------------------------------------------------

func _try_begin() -> void:
	var problem := character.validation_error()
	if not problem.is_empty():
		_show_step(0 if character.full_name.strip_edges().is_empty() else 2)
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


# Refresh --------------------------------------------------------------------------

func _refresh() -> void:
	for refresher: Callable in _refreshers:
		refresher.call()
	_step_title.text = "Step %d of %d:  %s" % [_step + 1, STEPS.size(), STEPS[_step][0]]
	_step_text.text = STEPS[_step][1]
	for i in _step_dots.size():
		var box := UiKit.flat_box(UiKit.SODIUM if i == _step else (UiKit.LITURGICAL_GOLD if i < _step else UiKit.VESTMENT_LIGHT), Color.TRANSPARENT, 0, 0)
		_step_dots[i].add_theme_stylebox_override("panel", box)
	_back_button.disabled = _step == 0
	var last := _step == STEPS.size() - 1
	_next_button.text = "Begin  ›" if last else "Next  ›"
	_next_button.tooltip_text = Tips.CREATION["begin"] if last else Tips.CREATION["next"]
	_update_preview()
	_refresh_status()


func _refresh_status() -> void:
	var name := character.full_name.strip_edges()
	var fault := character.predominant_fault()
	_summary.text = "%s\n%s%s" % [
		name if not name.is_empty() else "Unnamed",
		GameData.temperament_def(character.temperament)["name"],
		"" if fault.is_empty() else ", struggles with " + GameData.sin_def(fault)["sin"].to_lower(),
	]
	_status.text = _error
