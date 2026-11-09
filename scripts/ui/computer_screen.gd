class_name ComputerScreen
extends Control
## The trailer's computer: security cameras, the shop and the state news.

const BEZEL := Color("#26221f")
const SCREEN := Color("#0b1512")
const PHOSPHOR := Color("#a6dcc3")
const DIM := Color("#62917e")
const LINE := Color("#2c5246")

const FEED_SHADER := """
shader_type canvas_item;
float noise(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	vec2 uv = UV;
	float line = floor(uv.y * 180.0);
	uv.x += (noise(vec2(line, floor(TIME * 12.0))) - 0.5) * 0.004;
	vec3 c = texture(TEXTURE, uv).rgb;
	float g = pow(dot(c, vec3(0.3, 0.59, 0.11)), 0.75) * 1.6;
	g *= 0.82 + 0.18 * sin(uv.y * 540.0);
	g += (noise(uv * vec2(320.0, 180.0) + fract(TIME) * 91.0) - 0.5) * 0.14;
	g *= mix(0.55, 1.0, smoothstep(0.85, 0.35, distance(UV, vec2(0.5))));
	COLOR = vec4(g * 0.72, g * 0.98, g * 0.82, 1.0);
}
"""

var game: TrailerGame
var _content: VBoxContainer
var _tab_buttons := {}
var _tab := ""
var _focused_feed := -1
var _live_labels: Array[Callable] = []
var _tick := 0.0
var _feed_material: ShaderMaterial


static func open(owner_game: TrailerGame) -> ComputerScreen:
	var screen := ComputerScreen.new()
	screen.game = owner_game
	screen.add_to_group("modal")
	owner_game.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen._build()
	screen.show_tab("cameras")
	return screen


func _build() -> void:
	var shader := Shader.new()
	shader.code = FEED_SHADER
	_feed_material = ShaderMaterial.new()
	_feed_material.shader = shader

	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.88)
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiKit.apply_safe_area(margin, 18)
	var bezel := PanelContainer.new()
	var bezel_box := UiKit.flat_box(SCREEN, BEZEL, 14, 14)
	bezel_box.set_corner_radius_all(10)
	bezel.add_theme_stylebox_override("panel", bezel_box)
	margin.add_child(bezel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	bezel.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	column.add_child(header)
	var title := UiKit.label("Civic Link", 30, PHOSPHOR)
	title.custom_minimum_size.x = 180
	header.add_child(title)
	for tab: Array in [["cameras", "Cameras"], ["shop", "Shop"], ["news", "News"]]:
		var button := _screen_button(tab[1], show_tab.bind(tab[0]))
		button.custom_minimum_size.x = 150
		header.add_child(button)
		_tab_buttons[tab[0]] = button
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	header.add_child(_screen_button("Log off", go_back))

	_content = VBoxContainer.new()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 8)
	column.add_child(_content)


func _screen_button(text: String, action: Callable) -> Button:
	var button := UiKit.button(text, action)
	_style(button, false)
	return button


func _style(button: Button, selected: bool) -> void:
	var fill := LINE if selected else SCREEN.lightened(0.05)
	button.add_theme_stylebox_override("normal", UiKit.flat_box(fill, LINE, 2))
	button.add_theme_stylebox_override("hover", UiKit.flat_box(fill, PHOSPHOR, 2))
	button.add_theme_stylebox_override("pressed", UiKit.flat_box(LINE, PHOSPHOR, 2))
	button.add_theme_stylebox_override("disabled", UiKit.flat_box(SCREEN, Color(LINE, 0.5), 2))
	button.add_theme_stylebox_override("focus", UiKit.flat_box(Color.TRANSPARENT, PHOSPHOR, 2))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, PHOSPHOR)
	button.add_theme_color_override("font_disabled_color", Color(DIM, 0.6))


func show_tab(tab: String) -> void:
	_tab = tab
	for id: String in _tab_buttons:
		_style(_tab_buttons[id], id == tab)
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	_live_labels.clear()
	game.set_feeds_live(tab == "cameras")
	match tab:
		"cameras":
			_build_cameras()
		"shop":
			_build_shop()
		"news":
			_build_news()
	_update_live()


func _process(delta: float) -> void:
	_tick += delta
	if _tick >= 0.25:
		_tick = 0.0
		_update_live()


func _update_live() -> void:
	for update: Callable in _live_labels:
		update.call()


func go_back() -> void:
	game.set_feeds_live(false)
	remove_from_group("modal")
	queue_free()
	game.on_computer_closed()


# Cameras ----------------------------------------------------------------------

func _build_cameras() -> void:
	var cameras := game.world.cameras
	if _focused_feed >= 0:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_content.add_child(row)
		for i in cameras.size():
			var button := _screen_button("%d. %s" % [i + 1, cameras[i].title], _focus_feed.bind(i))
			_style(button, i == _focused_feed)
			row.add_child(button)
		row.add_child(_screen_button("All cameras", _focus_feed.bind(-1)))
		_content.add_child(_make_feed(_focused_feed))
		return
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	_content.add_child(grid)
	for i in cameras.size():
		grid.add_child(_make_feed(i))


func _focus_feed(index: int) -> void:
	_focused_feed = index
	show_tab("cameras")


func _make_feed(index: int) -> Control:
	var unit: SecurityCamera = game.world.cameras[index]
	var frame := Button.new()
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var empty := UiKit.flat_box(Color.BLACK, LINE, 2, 0)
	for state in ["normal", "hover", "pressed", "focus"]:
		frame.add_theme_stylebox_override(state, empty)
	frame.pressed.connect(_focus_feed.bind(-1 if _focused_feed == index else index))
	var picture := TextureRect.new()
	picture.texture = unit.viewport.get_texture()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.material = _feed_material
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(picture)
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var stamp := UiKit.label("", 20, PHOSPHOR)
	stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamp.position = Vector2(12, 6)
	stamp.add_theme_constant_override("outline_size", 5)
	stamp.add_theme_color_override("font_outline_color", Color.BLACK)
	frame.add_child(stamp)
	_live_labels.append(func() -> void:
		stamp.text = "CAM %d  %s  %s" % [index + 1, unit.title, Survival.clock_text(Survival.now(game.save))]
	)
	return frame


# Shop -------------------------------------------------------------------------

func _build_shop() -> void:
	var top := HBoxContainer.new()
	_content.add_child(top)
	var money := UiKit.label("", 26, PHOSPHOR)
	money.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(money)
	var arrival := UiKit.label("", 22, DIM)
	top.add_child(arrival)
	_live_labels.append(func() -> void:
		money.text = "%d credits" % Survival.money(game.save)
		var next := Survival.next_arrival(game.save)
		var waiting := Survival.arrived(game.save).size()
		if next >= 0.0:
			arrival.text = "Next drone lands at %s" % Survival.clock_text(next)
		elif waiting > 0:
			arrival.text = "A delivery is waiting outside your door"
		else:
			arrival.text = "Drones deliver to your door within 45 minutes"
	)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 6)
	scroll.add_child(rows)
	for product: Dictionary in GameData.PRODUCTS:
		rows.add_child(_shop_row(product))


func _shop_row(product: Dictionary) -> Control:
	var id: String = product["id"]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", -4)
	text.add_child(UiKit.label(product["name"], 26, PHOSPHOR))
	text.add_child(UiKit.label("%s. %s" % [product["pack"], product["desc"]], 20, DIM))
	row.add_child(text)
	var owned := UiKit.label("", 22, DIM)
	owned.custom_minimum_size.x = 130
	row.add_child(owned)
	var price := UiKit.label("%d credits" % product["price"], 24, PHOSPHOR)
	price.custom_minimum_size.x = 120
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(price)
	var buy := _screen_button("Order", _order.bind(id))
	buy.custom_minimum_size.x = 130
	row.add_child(buy)
	_live_labels.append(func() -> void:
		owned.text = "You have %d" % Survival.stock(game.save, id)
		buy.disabled = Survival.money(game.save) < int(product["price"])
	)
	return row


func _order(id: String) -> void:
	game.order_product(id)
	_update_live()


# News -------------------------------------------------------------------------

func _build_news() -> void:
	var day := Survival.day_of(Survival.now(game.save))
	_content.add_child(UiKit.label("Civic News, day %d" % day, 30, PHOSPHOR))
	var lean := int(game.save["soul"].get("horror_lean", 0))
	var first := true
	for line: String in Survival.headlines(day, lean):
		var headline := UiKit.wrapped_label(line, 30 if first else 24, PHOSPHOR if first else DIM)
		_content.add_child(headline)
		var rule := ColorRect.new()
		rule.color = LINE
		rule.custom_minimum_size.y = 1
		_content.add_child(rule)
		first = false
