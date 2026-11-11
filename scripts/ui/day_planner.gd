class_name DayPlanner
extends Control
## The day at a glance: the date, the six shifts, Sunday Mass, and what to do
## with the rest of the current shift.

var game: TrailerGame


static func open(owner_game: TrailerGame) -> DayPlanner:
	var planner := DayPlanner.new()
	planner.game = owner_game
	planner.add_to_group("modal")
	owner_game.add_child(planner)
	planner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	planner._build()
	return planner


func go_back() -> void:
	remove_from_group("modal")
	queue_free()
	game.on_planner_closed()


func _build() -> void:
	var save := game.save
	var now := Survival.now(save)
	var current := Survival.shift_index(now)
	var remaining_hours := (Survival.shift_end(now) - now) / 60.0

	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.01, 0.05, 0.86)
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiKit.apply_safe_area(margin, 24)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)
	column.add_child(header)
	header.add_child(UiKit.button("Back", go_back, 130))
	header.add_child(UiKit.heading(Survival.date_text(now, true), 46))
	column.add_child(UiKit.label(_soul_line(save, now), UiKit.SIZE_SMALL, UiKit.LITURGICAL_GOLD))

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 24)
	column.add_child(body)

	var shifts := VBoxContainer.new()
	shifts.custom_minimum_size.x = 330
	shifts.add_theme_constant_override("separation", 4)
	body.add_child(shifts)
	for i in GameData.SHIFTS.size():
		shifts.add_child(_shift_row(i, current))

	var choices := VBoxContainer.new()
	choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choices.add_theme_constant_override("separation", 6)
	body.add_child(choices)
	var shift_label: String = GameData.SHIFTS[current]
	choices.add_child(UiKit.label("Spend the rest of the %s (%s left)" % [shift_label.to_lower(), _hours(remaining_hours)], UiKit.SIZE_BODY, UiKit.TALLOW))
	for activity: Dictionary in GameData.ACTIVITIES:
		choices.add_child(_activity_button(activity, remaining_hours))
	var free := UiKit.button("Spend it freely: walk around and do things yourself", go_back)
	free.alignment = HORIZONTAL_ALIGNMENT_LEFT
	choices.add_child(free)


func _soul_line(save: Dictionary, now: float) -> String:
	if not Parish.sacraments_available(save):
		return "There is no Mass at St. Brigid's for now. " + Parish.describe(save)
	var sunday := Survival.mass_sunday(now)
	var mass := ""
	if sunday > 0:
		mass = "You have been to Mass for this Sunday." if Survival.attended_mass(save, sunday) else "Mass is being said now."
	else:
		var day := Survival.day_of(now)
		var next_sunday := day + posmod(7 - Survival.weekday_of_day(day), 7)
		if Survival.attended_mass(save, next_sunday):
			mass = "You have been to Mass for this Sunday."
		else:
			mass = "Sunday Mass: Saturday evening vigil, or Sunday morning, noon or evening."
	return mass


func _shift_row(index: int, current: int) -> Control:
	var row := PanelContainer.new()
	var box := UiKit.flat_box(UiKit.VESTMENT if index == current else Color(UiKit.COMPLINE, 0.6), UiKit.SODIUM if index == current else UiKit.VESTMENT_LIGHT, 2, 14)
	row.add_theme_stylebox_override("panel", box)
	var line := HBoxContainer.new()
	row.add_child(line)
	var colour := UiKit.TALLOW if index >= current else UiKit.ASH
	var name_label := UiKit.label(GameData.SHIFTS[index], UiKit.SIZE_BODY, colour)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(name_label)
	var status := "now" if index == current else Survival.shift_hours_text(index)
	line.add_child(UiKit.label(status, UiKit.SIZE_SMALL, UiKit.SODIUM if index == current else colour))
	return row


func _activity_button(activity: Dictionary, hours: float) -> Control:
	var id: String = activity["id"]
	var blocked := Survival.activity_blocked(game.save, id)
	var button := UiKit.button("", game.spend_shift.bind(id))
	button.custom_minimum_size.y = 78
	button.disabled = not blocked.is_empty()
	var inner := MarginContainer.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right"]:
		inner.add_theme_constant_override("margin_" + side, 14)
	button.add_child(inner)
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var lines := VBoxContainer.new()
	lines.alignment = BoxContainer.ALIGNMENT_CENTER
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_theme_constant_override("separation", -2)
	inner.add_child(lines)
	var faded := Color(1, 1, 1, 0.45) if button.disabled else Color.WHITE
	var title := UiKit.label(activity["name"], 24, UiKit.TALLOW * faded)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_child(title)
	var detail: String = blocked if not blocked.is_empty() else "%s %s" % [activity["desc"], _effects(activity, hours)]
	var detail_label := UiKit.wrapped_label(detail, 19, UiKit.ASH * faded)
	detail_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_child(detail_label)
	return button


func _effects(activity: Dictionary, hours: float) -> String:
	var rates: Dictionary = activity["rates"]
	var parts: PackedStringArray = []
	for need_def: Dictionary in GameData.NEEDS:
		var change := roundi(float(rates.get(need_def["id"], 0.0)) * hours)
		if change != 0:
			parts.append("%s %+d" % [need_def["name"], change])
	if activity["id"] == "work":
		parts.append("earns money")
	return ", ".join(parts) + "."


func _hours(hours: float) -> String:
	var minutes := roundi(hours * 60.0)
	if minutes >= 60:
		return "%dh %02dm" % [minutes / 60, minutes % 60]
	return "%d minutes" % minutes
