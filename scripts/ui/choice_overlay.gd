class_name ChoiceOverlay
extends Control
## A moment that needs an answer: a choice at the hatch, confession, Communion. Each
## choice is [button text, what happens]. The back button cannot skip it
## unless a cancel action is given.

var _on_cancel := Callable()
var _shade := 0.8


static func ask(parent: Node, title: String, body: String, choices: Array, on_cancel := Callable(), accent := UiKit.LITURGICAL_GOLD, shade := 0.8) -> ChoiceOverlay:
	var overlay := ChoiceOverlay.new()
	overlay._shade = shade
	overlay._on_cancel = on_cancel
	overlay.add_to_group("modal")
	parent.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay._build(title, body, choices, accent)
	return overlay


func _build(title: String, body: String, choices: Array, accent: Color) -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.01, 0.05, _shade)
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if _shade < 0.5:
		# Keep the middle of the scene in view: the panel sits low.
		center.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		center.offset_top = -360
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(660, 0)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	panel.add_child(column)
	var heading := UiKit.heading(title)
	heading.add_theme_color_override("font_color", accent)
	column.add_child(heading)
	column.add_child(UiKit.wrapped_label(body))
	var first: Button = null
	for choice: Array in choices:
		var action: Callable = choice[1]
		var button := UiKit.button(choice[0], _choose.bind(action))
		column.add_child(button)
		if first == null:
			first = button
	if _on_cancel.is_valid():
		column.add_child(UiKit.button("Not now", go_back))
	if first != null:
		first.grab_focus()


func _choose(action: Callable) -> void:
	_close()
	if action.is_valid():
		action.call()


func _close() -> void:
	remove_from_group("modal")
	queue_free()


func go_back() -> void:
	if not _on_cancel.is_valid():
		return
	_close()
	_on_cancel.call()
