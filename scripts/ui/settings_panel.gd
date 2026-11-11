class_name SettingsPanel
extends Control
## Volume settings. Changes apply as you drag and are stored on leaving.

const ROWS := [["master", "Master volume"], ["music", "Music"], ["sfx", "Sound effects"]]


static func open(parent: Node) -> SettingsPanel:
	var panel := SettingsPanel.new()
	panel.add_to_group("modal")
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(panel)
	panel._build()
	return panel


func go_back() -> void:
	Settings.save()
	queue_free()
	remove_from_group("modal")


func _build() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.05, 0.03, 0.08, 0.8)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 0)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	panel.add_child(column)
	column.add_child(UiKit.heading("Settings"))
	for row: Array in ROWS:
		column.add_child(_make_row(row[0], row[1]))
	column.add_child(_picture_row())
	column.add_child(UiKit.button("Back", go_back))


## Sharp, Crisp or Retro: the size of the game's pixels.
func _picture_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var title := UiKit.label("Picture")
	title.custom_minimum_size.x = 150
	row.add_child(title)
	var buttons := []
	for scale: int in Settings.PICTURES:
		var button := UiKit.button(Settings.PICTURES[scale], func() -> void:
			Settings.set_pixel_scale(scale)
			for b: Button in buttons:
				b.button_pressed = b.get_meta("scale") == Settings.pixel_scale)
		button.toggle_mode = true
		button.set_meta("scale", scale)
		button.button_pressed = scale == Settings.pixel_scale
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buttons.append(button)
		row.add_child(button)
	return row


func _make_row(channel: String, title: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.custom_minimum_size.y = UiKit.TOUCH_HEIGHT
	var name_label := UiKit.label(title)
	name_label.custom_minimum_size.x = 200
	row.add_child(name_label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = Settings.volumes[channel]
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.custom_minimum_size.y = 40
	row.add_child(slider)
	var percent := UiKit.label(_percent(slider.value))
	percent.custom_minimum_size.x = 76
	percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(percent)
	slider.value_changed.connect(func(value: float) -> void:
		Settings.set_volume(channel, value)
		percent.text = _percent(value)
	)
	slider.drag_ended.connect(func(_changed: bool) -> void:
		if channel != "music":
			Sound.click()
	)
	return row


func _percent(value: float) -> String:
	return "%d%%" % roundi(value * 100.0)
