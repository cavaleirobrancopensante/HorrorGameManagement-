class_name LifePanel
extends Control
## Your life so far: your age, the virtues you are building, what you are
## carrying, the parish, and how the street and the state see you.

var game: TrailerGame


static func open(parent: Node, owner_game: TrailerGame) -> LifePanel:
	var panel := LifePanel.new()
	panel.game = owner_game
	panel.add_to_group("modal")
	parent.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel._build()
	return panel


func _build() -> void:
	var save := game.save
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.01, 0.05, 0.93)
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiKit.apply_safe_area(margin, 28)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	margin.add_child(outer)
	outer.add_child(UiKit.heading("%s, %d" % [game.character.full_name, Life.age(save)], 48))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	scroll.add_child(column)

	column.add_child(UiKit.label("Virtues", 30, UiKit.SODIUM))
	column.add_child(UiKit.wrapped_label("Each good act makes the next one easier. They grow slowly, as habits do.", 18, UiKit.ASH))
	for def: Dictionary in GameData.VIRTUES:
		column.add_child(_virtue_row(def))

	column.add_child(UiKit.label("What you carry", 30, UiKit.SODIUM))
	var regrets := Virtue.regrets(save)
	if regrets.is_empty():
		column.add_child(UiKit.wrapped_label("Nothing weighs on you just now.", UiKit.SIZE_SMALL))
	else:
		for regret: Dictionary in regrets:
			column.add_child(UiKit.wrapped_label("· " + str(regret["text"]), UiKit.SIZE_SMALL, UiKit.TALLOW))
		column.add_child(UiKit.wrapped_label("Confession is heard in the evenings at St. Brigid's.", 18, UiKit.ASH))

	column.add_child(UiKit.label("The parish", 30, UiKit.SODIUM))
	column.add_child(UiKit.wrapped_label(Parish.describe(save), UiKit.SIZE_SMALL))
	column.add_child(UiKit.label("The street", 30, UiKit.SODIUM))
	var trust := Life.trust(save)
	var street := "Your regulars swear by you." if trust >= 70.0 else ("People know you and come back." if trust >= 45.0 else ("Some people trust you; most just pass." if trust >= 20.0 else "People cross the road rather than queue at your hatch."))
	column.add_child(UiKit.wrapped_label(street, UiKit.SIZE_SMALL))
	var watched := Horror.attention(save)
	var state := "The state barely knows you exist." if watched < 0.15 else ("The state has noticed you." if watched < 0.4 else ("You are watched." if watched < 0.7 else "You are flagged for enforcement."))
	column.add_child(UiKit.wrapped_label(state, UiKit.SIZE_SMALL))

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	if game.can_send_for_priest():
		bar.add_child(UiKit.button("Send for Father Columba", func() -> void:
			go_back()
			game.send_for_priest_from_menu(), 360))
	var filler := Control.new()
	filler.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(filler)
	bar.add_child(UiKit.button("Back", go_back, 180))
	outer.add_child(bar)


func _virtue_row(def: Dictionary) -> Control:
	var save := game.save
	var id: String = def["id"]
	var level := Virtue.level(save, id)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var name := UiKit.label(def["name"], UiKit.SIZE_BODY, UiKit.LITURGICAL_GOLD)
	name.custom_minimum_size.x = 180
	row.add_child(name)
	var meter := ProgressBar.new()
	meter.max_value = 100.0
	meter.value = level
	meter.show_percentage = false
	meter.custom_minimum_size = Vector2(220, 14)
	meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(meter)
	var note := Virtue.rank(save, id)
	if game.character.struggles.has(id):
		note += " (a struggle for you)"
	elif game.character.gift() == id:
		note += " (comes naturally)"
	row.add_child(UiKit.label(note, 18, UiKit.TALLOW))
	box.add_child(row)
	box.add_child(UiKit.wrapped_label(def["effect"], 16, UiKit.ASH))
	UiKit.tip(box, "%s: %s %s" % [def["name"], def["desc"], def["effect"]])
	return box


func go_back() -> void:
	remove_from_group("modal")
	queue_free()
