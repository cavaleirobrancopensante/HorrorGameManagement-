class_name UiKit
extends RefCounted
## Shared look of the interface: liturgical violet, tallow and sodium light.

const COMPLINE := Color("#17101f")
const VESTMENT := Color("#2b1b3a")
const VESTMENT_LIGHT := Color("#4b3060")
const TALLOW := Color("#efe0bf")
const ASH := Color("#b0a3b4")
const SODIUM := Color("#f0a640")
const SANCTUARY := Color("#c8323c")
const LITURGICAL_GOLD := Color("#d7bd6a")

const BODY_FONT_PATH := "res://assets/fonts/Alegreya-Variable.ttf"
const TITLE_FONT_PATH := "res://assets/fonts/PirataOne-Regular.ttf"

const SIZE_BODY := 26
const SIZE_SMALL := 22
const SIZE_HEADING := 44
const TOUCH_HEIGHT := 64


## Alegreya defaults to old-style numbers, which are hard to read in stats,
## so lining numbers are switched on.
static func body_font() -> Font:
	var font := FontVariation.new()
	font.base_font = load(BODY_FONT_PATH)
	font.opentype_features = {TextServerManager.get_primary_interface().name_to_tag("lnum"): 1}
	return font


static func title_font() -> Font:
	return load(TITLE_FONT_PATH)


static func flat_box(fill: Color, border: Color = Color.TRANSPARENT, border_width: int = 0, margin: int = 12) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(2)
	box.content_margin_left = margin
	box.content_margin_right = margin
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	return box


static func build_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font = body_font()
	theme.default_font_size = SIZE_BODY

	theme.set_color("font_color", "Label", TALLOW)

	theme.set_stylebox("normal", "Button", flat_box(VESTMENT, VESTMENT_LIGHT, 2))
	theme.set_stylebox("hover", "Button", flat_box(VESTMENT_LIGHT, LITURGICAL_GOLD, 2))
	theme.set_stylebox("pressed", "Button", flat_box(Color("#65421f"), SODIUM, 2))
	theme.set_stylebox("disabled", "Button", flat_box(Color(VESTMENT, 0.4), Color(VESTMENT_LIGHT, 0.4), 2))
	theme.set_stylebox("focus", "Button", flat_box(Color.TRANSPARENT, TALLOW, 3))
	theme.set_color("font_color", "Button", TALLOW)
	theme.set_color("font_hover_color", "Button", TALLOW)
	theme.set_color("font_pressed_color", "Button", TALLOW)
	theme.set_color("font_focus_color", "Button", TALLOW)
	theme.set_color("font_hover_pressed_color", "Button", TALLOW)
	theme.set_color("font_disabled_color", "Button", Color(ASH, 0.45))

	theme.set_stylebox("normal", "LineEdit", flat_box(COMPLINE, VESTMENT_LIGHT, 2))
	theme.set_stylebox("focus", "LineEdit", flat_box(Color.TRANSPARENT, SODIUM, 2))
	theme.set_color("font_color", "LineEdit", TALLOW)
	theme.set_color("caret_color", "LineEdit", SODIUM)
	theme.set_color("font_placeholder_color", "LineEdit", Color(ASH, 0.7))

	theme.set_stylebox("panel", "PanelContainer", flat_box(Color(COMPLINE, 0.94), VESTMENT_LIGHT, 2, 16))
	theme.set_stylebox("panel", "TooltipPanel", flat_box(Color(COMPLINE, 0.96), LITURGICAL_GOLD, 2, 10))
	theme.set_color("font_color", "TooltipLabel", TALLOW)
	theme.set_font_size("font_size", "TooltipLabel", SIZE_SMALL)

	var slider_track := flat_box(VESTMENT_LIGHT)
	slider_track.content_margin_top = 8
	slider_track.content_margin_bottom = 8
	var slider_fill := flat_box(SODIUM)
	slider_fill.content_margin_top = 8
	slider_fill.content_margin_bottom = 8
	theme.set_stylebox("slider", "HSlider", slider_track)
	theme.set_stylebox("grabber_area", "HSlider", slider_fill)
	theme.set_stylebox("grabber_area_highlight", "HSlider", slider_fill)
	theme.set_icon("grabber", "HSlider", _square_icon(36, TALLOW))
	theme.set_icon("grabber_highlight", "HSlider", _square_icon(36, SODIUM))
	theme.set_icon("grabber_disabled", "HSlider", _square_icon(36, ASH))
	return theme


static func _square_icon(side: int, color: Color) -> ImageTexture:
	var image := Image.create(side, side, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)


static func label(text: String, font_size: int = SIZE_BODY, color: Color = TALLOW) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return node


static func wrapped_label(text: String, font_size: int = SIZE_BODY, color: Color = TALLOW) -> Label:
	var node := label(text, font_size, color)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return node


static func heading(text: String, font_size: int = SIZE_HEADING) -> Label:
	var node := label(text, font_size, TALLOW)
	node.add_theme_font_override("font", title_font())
	return node


static func button(text: String, action: Callable = Callable(), min_width: int = 0) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size = Vector2(min_width, TOUCH_HEIGHT)
	node.pressed.connect(Sound.click)
	if action.is_valid():
		node.pressed.connect(action)
	return node


## Where tooltips go on screens without a mouse: the help line of the
## current screen, if it has one.
static var help_target := Callable()


## Gives a control a tooltip. With a mouse it shows when you point at it; on a
## touch screen, touching or focusing the control puts it in the help line.
static func tip(node: Control, text: String) -> Control:
	node.tooltip_text = text
	node.focus_entered.connect(func() -> void: _help(text))
	node.mouse_entered.connect(func() -> void: _help(text))
	if node is BaseButton:
		(node as BaseButton).button_down.connect(func() -> void: _help(text))
	return node


static func _help(text: String) -> void:
	if help_target.is_valid():
		help_target.call(text)


## A line along the bottom of a screen that explains whatever you last
## pointed at or touched. Shows default_text when nothing has been touched.
static func help_line(default_text: String) -> Label:
	var line := wrapped_label(default_text, SIZE_SMALL, ASH)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help_target = func(text: String) -> void:
		if is_instance_valid(line):
			line.text = text
	return line


## Gives one button a fixed fill, used to show which choice is selected.
static func paint(node: Button, fill: Color, border: Color, border_width: int = 2) -> void:
	var box := flat_box(fill, border, border_width)
	for state in ["normal", "hover", "pressed", "disabled"]:
		node.add_theme_stylebox_override(state, box)


## Keeps content clear of phone notches and rounded corners.
static func apply_safe_area(margin: MarginContainer, base: int) -> void:
	var window := margin.get_window()
	var safe := DisplayServer.get_display_safe_area()
	var screen := DisplayServer.screen_get_size()
	var left := base
	var right := base
	if window != null and window.size.x > 0 and safe.size.x > 0 and DisplayServer.is_touchscreen_available():
		var to_canvas: float = margin.get_viewport_rect().size.x / float(window.size.x)
		left = maxi(base, int(safe.position.x * to_canvas))
		right = maxi(base, int((screen.x - safe.end.x) * to_canvas))
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_top", base)
	margin.add_theme_constant_override("margin_bottom", base)
