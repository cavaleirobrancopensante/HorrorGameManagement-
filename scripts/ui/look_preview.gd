class_name LookPreview
extends SubViewportContainer
## A person shown in 3D on a little stage, turning slowly. Drag to turn them
## yourself. Used by character creation and the wardrobe.

var _holder: Node3D
var _rig: PersonRig
var _shown := ""
var _turn := PI + 0.35
var _dragging := false


func _init() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	var world := SubViewport.new()
	world.own_world_3d = true
	add_child(world)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#1c1426")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#8a7a96")
	env.ambient_light_energy = 0.7
	environment.environment = env
	world.add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35.0, -30.0, 0.0)
	key.light_energy = 1.1
	key.light_color = Color("#ffe2b8")
	world.add_child(key)
	var rim := OmniLight3D.new()
	rim.position = Vector3(-1.2, 2.2, -1.2)
	rim.light_color = Color("#a07ad0")
	rim.light_energy = 1.4
	rim.omni_range = 5.0
	world.add_child(rim)
	var stage := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.6
	disc.bottom_radius = 0.6
	disc.height = 0.04
	stage.mesh = disc
	stage.position.y = -0.02
	stage.material_override = TextureFactory.plain(Color("#2b1b3a"))
	world.add_child(stage)
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 1.05, 2.9)
	camera.rotation_degrees.x = -4.0
	camera.fov = 42.0
	world.add_child(camera)
	_holder = Node3D.new()
	world.add_child(_holder)


## Shows this person, building them again only if they look different.
func show_recipe(recipe: Dictionary) -> void:
	var key := str(recipe)
	if key == _shown:
		return
	_shown = key
	if _rig != null:
		_rig.queue_free()
	_rig = People.place(_holder, recipe, Vector3.ZERO, 0.0)


func _process(delta: float) -> void:
	if _rig == null:
		return
	if not _dragging:
		_turn = lerp_angle(_turn, PI + 0.35 + sin(Time.get_ticks_msec() / 2400.0) * 0.25, delta * 1.5)
	_holder.rotation.y = _turn


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
	elif event is InputEventScreenTouch:
		_dragging = event.pressed
	elif event is InputEventMouseMotion and _dragging:
		_turn += (event as InputEventMouseMotion).relative.x * 0.012
	elif event is InputEventScreenDrag:
		_turn += (event as InputEventScreenDrag).relative.x * 0.012


## "Label  ‹  value  ›" for one look: the arrows step through its choices.
## refreshers gets the function that keeps the value shown up to date.
static func chooser(character: PlayerCharacter, id: String, on_changed: Callable, refreshers: Array) -> Control:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 4)
	var tip: String = Tips.CREATION.get(id, "")
	var label := UiKit.label(GameData.appearance_def(id)["label"], UiKit.SIZE_SMALL, UiKit.ASH)
	label.custom_minimum_size.x = 130
	label.mouse_filter = Control.MOUSE_FILTER_STOP
	UiKit.tip(label, tip)
	row.add_child(label)
	var step := func(direction: int) -> void:
		var options := GameData.options_for(id, character.appearance["sex"])
		var index := 0
		for i in options.size():
			if options[i][0] == character.appearance[id]:
				index = i
		character.appearance[id] = options[posmod(index + direction, options.size())][0]
		character.normalize_appearance()
		on_changed.call()
	var left := UiKit.button("‹", step.bind(-1), 64)
	left.add_theme_font_size_override("font_size", 34)
	row.add_child(UiKit.tip(left, tip))
	var value := UiKit.label("")
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(value)
	var right := UiKit.button("›", step.bind(1), 64)
	right.add_theme_font_size_override("font_size", 34)
	row.add_child(UiKit.tip(right, tip))
	refreshers.append(func() -> void:
		value.text = GameData.option_name(id, character.appearance[id], character.appearance["sex"]))
	return row
