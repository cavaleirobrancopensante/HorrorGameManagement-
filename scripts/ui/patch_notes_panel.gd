class_name PatchNotesPanel
extends Control
## Every patch's changes, newest first, in a scrolling panel.


static func open(parent: Node) -> PatchNotesPanel:
	var panel := PatchNotesPanel.new()
	panel.add_to_group("modal")
	parent.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel._build()
	return panel


func _build() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.01, 0.05, 0.86)
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiKit.apply_safe_area(margin, 40)
	var center := CenterContainer.new()
	margin.add_child(center)
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(900, 560)
	center.add_child(box)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	box.add_child(column)
	column.add_child(UiKit.heading("Patch notes"))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	for patch: Dictionary in Changelog.PATCHES:
		var head := UiKit.label("Version %s: %s" % [patch["version"], patch["title"]], UiKit.SIZE_BODY, UiKit.LITURGICAL_GOLD)
		list.add_child(head)
		list.add_child(UiKit.label(patch["date"], UiKit.SIZE_SMALL, UiKit.ASH))
		for change: String in patch["changes"]:
			list.add_child(UiKit.wrapped_label("•  " + change, UiKit.SIZE_SMALL))
		var gap := Control.new()
		gap.custom_minimum_size.y = 14
		list.add_child(gap)
	var close := UiKit.button("Close", go_back)
	column.add_child(close)
	close.grab_focus()


func go_back() -> void:
	remove_from_group("modal")
	queue_free()
