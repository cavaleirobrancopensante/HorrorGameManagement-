class_name ConfirmOverlay
extends Control
## A yes/no question drawn over the current screen.

var _on_yes := Callable()


## Shows the question. on_yes runs only if the player accepts.
static func ask(parent: Node, title: String, body: String, yes_text: String, no_text: String, on_yes: Callable) -> ConfirmOverlay:
	var overlay := ConfirmOverlay.new()
	overlay._on_yes = on_yes
	overlay.add_to_group("modal")
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(overlay)
	overlay._build(title, body, yes_text, no_text)
	return overlay


func _build(title: String, body: String, yes_text: String, no_text: String) -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.01, 0.05, 0.82)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(640, 0)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	panel.add_child(column)
	column.add_child(UiKit.heading(title))
	column.add_child(UiKit.wrapped_label(body))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	column.add_child(row)
	var no_button := UiKit.button(no_text, go_back)
	no_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(no_button)
	var yes_button := UiKit.button(yes_text, _accept)
	yes_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(yes_button)
	no_button.grab_focus()


func go_back() -> void:
	queue_free()
	remove_from_group("modal")


func _accept() -> void:
	go_back()
	if _on_yes.is_valid():
		_on_yes.call()
