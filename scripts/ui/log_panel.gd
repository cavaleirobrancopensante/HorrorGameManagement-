class_name LogPanel
extends Control
## The test log on screen: everything that happened this session, newest at
## the bottom, coloured good, bad, lag, lighting or error, with filters, a
## live frame rate, and a button to copy or download it all.

const FILTERS := [
	["All", []],
	["Good", ["good"]],
	["Bad", ["bad"]],
	["Lag", ["perf"]],
	["Lighting", ["light"]],
	["Errors", ["error"]],
]

var _filter: Array = []
var _text: RichTextLabel
var _live: Label
var _status: Label
var _filter_buttons: Array[Button] = []


static func open(parent: Node) -> LogPanel:
	var panel := LogPanel.new()
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	panel.add_to_group("modal")
	parent.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel._build()
	return panel


## F3 opens and closes the log over whatever screen is showing.
static func toggle(parent: Node) -> void:
	for node in parent.get_tree().get_nodes_in_group("modal"):
		if node is LogPanel:
			(node as LogPanel).go_back()
			return
	open(parent)


func _build() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.01, 0.05, 0.92)
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiKit.apply_safe_area(margin, 24)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	var title := UiKit.heading("Test log", 48)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	_live = UiKit.label("", UiKit.SIZE_SMALL, Color("#f0c060"))
	top.add_child(_live)
	column.add_child(top)
	column.add_child(UiKit.wrapped_label("What happened this session. Green is good, red is bad, amber is lag (slow frames, which also make the music stutter), blue is lighting, purple is an error in the game itself.", 18, UiKit.ASH))

	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 6)
	for entry: Array in FILTERS:
		var button := UiKit.button(entry[0], _set_filter.bind(entry[1]), 120)
		button.set_meta("kinds", entry[1])
		filters.add_child(button)
		_filter_buttons.append(button)
	column.add_child(filters)

	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.scroll_following = true
	_text.selection_enabled = true
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.add_theme_font_size_override("normal_font_size", 18)
	column.add_child(_text)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	var frame_rate := CheckButton.new()
	frame_rate.text = "Show frame rate"
	frame_rate.button_pressed = GameLog.show_fps
	frame_rate.toggled.connect(func(on: bool) -> void: GameLog.show_fps = on)
	UiKit.tip(frame_rate, "Show the frame rate, the slowest recent frame and the draw calls in the corner while you play.")
	bar.add_child(frame_rate)
	_status = UiKit.label("", UiKit.SIZE_SMALL, UiKit.TALLOW)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(_status)
	var export_label := "Download log" if OS.has_feature("web") else "Copy log"
	bar.add_child(UiKit.tip(UiKit.button(export_label, _export, 220), "Copy the whole log, or download it on the web, to send it on."))
	bar.add_child(UiKit.button("Close", go_back, 160))
	column.add_child(bar)

	GameLog.added.connect(_on_added)
	_set_filter([])


func _process(_delta: float) -> void:
	var counts := GameLog.counts()
	_live.text = "%d fps   good %d   bad %d   lag %d   errors %d" % [Engine.get_frames_per_second(), counts["good"], counts["bad"], counts["perf"], counts["error"]]


func _set_filter(kinds: Array) -> void:
	_filter = kinds
	for button in _filter_buttons:
		var on: bool = button.get_meta("kinds") == kinds
		UiKit.paint(button, UiKit.VESTMENT_LIGHT if on else UiKit.VESTMENT, UiKit.SODIUM if on else UiKit.VESTMENT_LIGHT, 3 if on else 2)
	_text.clear()
	for entry in GameLog.entries:
		_write(entry)


func _on_added(entry: Dictionary) -> void:
	_write(entry)


func _write(entry: Dictionary) -> void:
	if not _filter.is_empty() and not _filter.has(entry["kind"]):
		return
	_text.push_color(Color(GameLog.KINDS[entry["kind"]]))
	_text.add_text(GameLog.line_for(entry) + "\n")
	_text.pop()


func _export() -> void:
	_status.text = GameLog.export_log()


func go_back() -> void:
	if GameLog.added.is_connected(_on_added):
		GameLog.added.disconnect(_on_added)
	remove_from_group("modal")
	queue_free()
