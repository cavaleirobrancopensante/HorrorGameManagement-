class_name NoticeOverlay
extends Control
## A short message with one button to close it.

var _on_close := Callable()


static func show_notice(parent: Node, title: String, body: String, on_close := Callable()) -> NoticeOverlay:
	var overlay := NoticeOverlay.new()
	overlay._on_close = on_close
	overlay.add_to_group("modal")
	parent.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.01, 0.05, 0.75)
	overlay.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	column.add_child(UiKit.heading(title))
	column.add_child(UiKit.wrapped_label(body))
	var close := UiKit.button("Close", overlay.go_back)
	column.add_child(close)
	close.grab_focus()
	return overlay


func go_back() -> void:
	remove_from_group("modal")
	queue_free()
	if _on_close.is_valid():
		_on_close.call()
