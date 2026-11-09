extends Control
## Title screen: New game, Continue, Load game, Settings, Quit game.

var _continue_slot := -1
var _first_button: Button


func _ready() -> void:
	add_child(MenuBackdrop.new())
	_add_reading_shade()
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(margin)
	UiKit.apply_safe_area(margin, 40)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.custom_minimum_size.x = 460
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 4)
	margin.add_child(column)

	var title := UiKit.heading("Daily Bread", 112)
	title.add_theme_color_override("font_color", UiKit.TALLOW)
	column.add_child(title)
	var line := UiKit.label("And deliver us from evil.", UiKit.SIZE_BODY, UiKit.LITURGICAL_GOLD)
	column.add_child(line)
	var gap := Control.new()
	gap.custom_minimum_size.y = 20
	column.add_child(gap)

	_first_button = _menu_button(column, "New game", _on_new_game)
	_continue_slot = Saves.most_recent_living_slot()
	var continue_text := "Continue"
	if _continue_slot >= 0:
		continue_text = "Continue as %s" % Saves.read_slot(_continue_slot)["character"].get("full_name", "")
	var continue_button := _menu_button(column, continue_text, _on_continue)
	continue_button.disabled = _continue_slot < 0
	var load_button := _menu_button(column, "Load game", _on_load)
	load_button.disabled = not Saves.any_saves()
	_menu_button(column, "Settings", _on_settings)
	# iOS does not let apps close themselves.
	if not OS.has_feature("ios"):
		_menu_button(column, "Quit game", go_back)
	if not DisplayServer.is_touchscreen_available():
		_first_button.grab_focus()


func _add_reading_shade() -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(UiKit.COMPLINE, 0.94))
	gradient.set_color(1, Color(UiKit.COMPLINE, 0.0))
	gradient.set_offset(0, 0.45)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(1, 0)
	texture.width = 256
	texture.height = 4
	var shade := TextureRect.new()
	shade.texture = texture
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.anchor_bottom = 1.0
	shade.anchor_right = 0.62
	add_child(shade)


func _menu_button(parent: Control, text: String, action: Callable) -> Button:
	var node := UiKit.button(text, action)
	node.alignment = HORIZONTAL_ALIGNMENT_LEFT
	node.add_theme_font_size_override("font_size", 34)
	node.add_theme_color_override("font_hover_color", UiKit.SODIUM)
	node.add_theme_color_override("font_disabled_color", Color(UiKit.ASH, 0.4))
	var quiet := StyleBoxEmpty.new()
	quiet.content_margin_left = 0
	var hover := StyleBoxEmpty.new()
	hover.content_margin_left = 14
	node.add_theme_stylebox_override("normal", quiet)
	node.add_theme_stylebox_override("disabled", quiet)
	node.add_theme_stylebox_override("hover", hover)
	node.add_theme_stylebox_override("pressed", hover)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = UiKit.SODIUM
	focus.border_width_left = 4
	focus.expand_margin_left = 16
	node.add_theme_stylebox_override("focus", focus)
	parent.add_child(node)
	return node


func _on_new_game() -> void:
	Router.goto("character_creation")


func _on_continue() -> void:
	if Saves.load_slot(_continue_slot):
		Router.goto("game")


func _on_load() -> void:
	SlotsPanel.open(self, false, _on_slot_chosen)


func _on_slot_chosen(slot: int) -> void:
	if Saves.load_slot(slot):
		Router.goto("game")


func _on_settings() -> void:
	SettingsPanel.open(self)


## Quit game and the phone's back button both land here.
func go_back() -> void:
	ConfirmOverlay.ask(self, "Quit game?", "Your last save is kept.", "Quit", "Stay", get_tree().quit)
