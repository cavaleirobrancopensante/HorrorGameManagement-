class_name PauseMenu
extends Control
## Stops the clock. Resume, change settings, or save and leave.

var _on_resume := Callable()


static func open(parent: Node, on_resume: Callable, on_quit: Callable) -> PauseMenu:
	var menu := PauseMenu.new()
	menu._on_resume = on_resume
	menu.add_to_group("modal")
	parent.add_child(menu)
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.01, 0.05, 0.8)
	menu.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	menu.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 0)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	column.add_child(UiKit.heading("Paused"))
	var resume := UiKit.button("Resume", menu.go_back)
	column.add_child(resume)
	column.add_child(UiKit.button("Settings", func() -> void: SettingsPanel.open(menu)))
	column.add_child(UiKit.button("Save and return to menu", on_quit))
	resume.grab_focus()
	return menu


func go_back() -> void:
	remove_from_group("modal")
	queue_free()
	_on_resume.call()
