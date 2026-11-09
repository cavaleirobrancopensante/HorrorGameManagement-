class_name TrailerGame
extends Control
## The trailer and its street: walking around, needs, the computer, sleep and
## death. The world is drawn small and scaled up for the PS1 look.

const MOUSE_SPEED := 0.0025
const AUTOSAVE_SECONDS := 90.0
const PIXEL_SCALE := 3

var save: Dictionary
var world: TrailerWorld
var player: Player
var hud: GameHud
var touch: TouchControls

var _touch_mode := false
var _paused := false
var _busy := false
var _dead := false
var _recapture := false
var _autosave := 0.0
var _flicker_wait := 50.0
var _arrived := 0
var _day := 0
var _shift := -1
var _character: PlayerCharacter
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	if Saves.current.is_empty():
		Router.goto.call_deferred("main_menu")
		return
	save = Saves.current
	Survival.ensure(save)
	_character = Saves.current_character()
	_rng.randomize()
	_touch_mode = DisplayServer.is_touchscreen_available()
	Sound.play_music("hum")
	_build()
	_restore()
	if not _touch_mode:
		hud.show_hint("Click to look around. WASD to move, E to use, F for the torch, C to plan the day, Esc to pause.")


func _build() -> void:
	var container := SubViewportContainer.new()
	container.stretch = true
	container.stretch_shrink = PIXEL_SCALE
	container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var viewport := SubViewport.new()
	container.add_child(viewport)

	world = TrailerWorld.new()
	viewport.add_child(world)
	world.build()
	player = Player.new()
	viewport.add_child(player)
	world.mirror.viewer = player.camera
	player.body_sprite.texture = _make_body_texture()
	player.stepped.connect(func() -> void: Sound.play("step", 0.12, -8.0))

	hud = GameHud.new()
	hud.save = save
	hud.touch_mode = _touch_mode
	add_child(hud)
	touch = TouchControls.new()
	touch.player = player
	add_child(touch)
	touch.use_pressed.connect(_interact)
	touch.light_pressed.connect(_toggle_light)
	touch.pause_pressed.connect(go_back)
	touch.plan_pressed.connect(_open_planner)
	_set_busy(false)


## Draws the character head to feet once, for the mirror and the cameras.
func _make_body_texture() -> Texture2D:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(80, 320)
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var portrait := CharacterPortrait.new()
	portrait.full_body = true
	portrait.size = Vector2(80, 320)
	portrait.character = Saves.current_character()
	viewport.add_child(portrait)
	add_child(viewport)
	get_tree().create_timer(1.0).timeout.connect(func() -> void:
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	)
	return viewport.get_texture()


func _restore() -> void:
	var state: Dictionary = save["world"]
	var spot: Variant = state.get("player")
	if spot is Dictionary and (spot as Dictionary).has("pos"):
		var pos: Array = spot["pos"]
		player.position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
		player.rotation.y = float(spot.get("yaw", 0.0))
	else:
		player.position = TrailerWorld.SPAWN
		player.rotation.y = TrailerWorld.SPAWN_YAW
	world.set_hatch_open(bool(state["hatch_open"]), false)
	_arrived = Survival.arrived(save).size()
	world.show_crates(_arrived)
	_update_day()
	hud.refresh()


func _process(delta: float) -> void:
	if save.is_empty() or _dead:
		return
	world.set_daylight(Survival.daylight(Survival.now(save)))
	if not _paused:
		var cause := Survival.advance(save, delta * Survival.MINUTES_PER_SECOND)
		if not cause.is_empty():
			_die(cause)
			return
		_check_arrivals()
		_update_day()
		_update_shift()
		for notice: String in Survival.take_notices(save):
			hud.toast(notice)
		_autosave += delta
		if _autosave >= AUTOSAVE_SECONDS:
			_autosave = 0.0
			_save_now()
		_flicker_wait -= delta
		if _flicker_wait <= 0.0:
			_flicker_wait = _rng.randf_range(45.0, 120.0)
			world.flicker()
	var target := player.focused
	hud.set_prompt("" if _busy or target == null else _prompt_for(target))
	if touch.use_ready != (target != null):
		touch.use_ready = target != null
		touch.queue_redraw()
	hud.refresh()


func _update_day() -> void:
	var day := Survival.day_of(Survival.now(save))
	if day == _day:
		return
	_day = day
	world.set_candle_lit(int(save["world"]["candle_day"]) == day)


func _update_shift() -> void:
	var shift := Survival.shift_index(Survival.now(save))
	if shift != _shift:
		if _shift != -1:
			hud.toast("The %s begins." % GameData.SHIFTS[shift].to_lower() if shift == 5 else "The %s shift begins." % GameData.SHIFTS[shift].to_lower())
		_shift = shift


func _check_arrivals() -> void:
	var count := Survival.arrived(save).size()
	if count > _arrived:
		Sound.play("drone")
		hud.toast("A drone dropped a delivery outside the door.")
	if count != _arrived:
		world.show_crates(count)
	_arrived = count


# Input ------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if save.is_empty() or _dead:
		return
	if event.is_action_pressed("interact"):
		_interact()
		return
	if event.is_action_pressed("flashlight"):
		_toggle_light()
		return
	if event.is_action_pressed("plan_day"):
		_open_planner()
		return
	if _touch_mode:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			if not _busy:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				hud.show_hint("")
		elif (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			_interact()
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not _busy:
		player.look((event as InputEventMouseMotion).relative * MOUSE_SPEED)


func _set_busy(on: bool) -> void:
	_busy = on
	player.controls_enabled = not on
	player.move_input = Vector2.ZERO
	touch.reset()
	touch.visible = _touch_mode and not on
	touch.set_process_input(_touch_mode and not on)
	if on:
		_recapture = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
		if _recapture:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif _recapture and not _touch_mode:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_recapture = false


## Escape and the phone's back button: pause, or leave once dead.
func go_back() -> void:
	if _dead:
		Router.goto("main_menu")
		return
	if _busy:
		return
	_paused = true
	_set_busy(true)
	PauseMenu.open(self, _resume, _save_and_quit)


func _resume() -> void:
	_paused = false
	_set_busy(false)


func _save_and_quit() -> void:
	_save_now()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Router.goto("main_menu")


func _save_now() -> void:
	if _dead or save.is_empty() or player == null:
		return
	var at := player.global_position
	save["world"]["player"] = {"pos": [at.x, at.y, at.z], "yaw": player.rotation.y}
	Saves.save_current()


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		_save_now()


func _toggle_light() -> void:
	if _busy or _dead:
		return
	player.flashlight.visible = not player.flashlight.visible
	touch.light_on = player.flashlight.visible
	touch.queue_redraw()
	Sound.click()


# Using things -----------------------------------------------------------------

func _prompt_for(target: Interactable) -> String:
	match target.id:
		"door":
			return (target.get_meta("door") as Door).prompt()
		"computer":
			return "Use the computer"
		"sink":
			return "Drink tap water"
		"bed":
			return "Sleep"
		"altar":
			return "Light a candle and pray" if _can_light_candle() else "Pray"
		"fridge":
			if Survival.stock(save, "meals") > 0:
				return "Eat a ready meal"
			if Survival.stock(save, "sausages") > 0 and Survival.stock(save, "buns") > 0:
				return "Eat a sausage roll from the stock"
			return "Fridge (empty)"
		"cooler":
			return "Drink a can" if Survival.stock(save, "soda") > 0 else "Drinks cooler (empty)"
		"coffee":
			return "Make coffee" if Survival.stock(save, "coffee") > 0 else "Kettle (no coffee left)"
		"shelves":
			return "Check the stock"
		"grill":
			return "Grill"
		"hatch":
			return "Close the hatch" if bool(save["world"]["hatch_open"]) else "Open the hatch"
		"delivery":
			return "Carry the delivery inside"
		"calendar":
			return "Plan the day"
	return ""


func _interact() -> void:
	if _busy or _dead or _paused:
		return
	var target := player.focused
	if target == null:
		return
	match target.id:
		"door":
			(target.get_meta("door") as Door).toggle()
		"computer":
			Sound.play("beep")
			_set_busy(true)
			ComputerScreen.open(self)
		"sink":
			Survival.change_need(save, "thirst", -40.0)
			Sound.play("water")
			hud.toast("You drink from the tap. The water tastes of rust.")
		"fridge":
			_eat()
		"cooler":
			if Survival.take_stock(save, "soda"):
				Survival.change_need(save, "thirst", -30.0)
				Survival.change_need(save, "stress", -3.0)
				Sound.play("can")
				hud.toast("You drink a can of your own stock.")
			else:
				hud.toast("No cans left. Order more on the computer.")
		"coffee":
			if Survival.take_stock(save, "coffee"):
				Survival.change_need(save, "tiredness", -20.0)
				Survival.change_need(save, "thirst", -5.0)
				Sound.play("water", 0.0, -6.0)
				hud.toast("Bitter, but you feel awake.")
			else:
				hud.toast("No coffee left. Order more on the computer.")
		"shelves":
			_show_stock()
		"grill":
			hud.toast("The grill is cold. Cooking and customers come in the next build.")
		"hatch":
			var open := not bool(save["world"]["hatch_open"])
			save["world"]["hatch_open"] = open
			world.set_hatch_open(open, true)
			Sound.play("door", 0.1)
		"bed":
			_sleep()
		"altar":
			_pray()
		"delivery":
			_collect()
		"calendar":
			_open_planner()


func _eat() -> void:
	if Survival.take_stock(save, "meals"):
		Survival.change_need(save, "hunger", -45.0)
		hud.toast("You heat a ready meal and eat it.")
	elif Survival.stock(save, "sausages") > 0 and Survival.stock(save, "buns") > 0:
		Survival.take_stock(save, "sausages")
		Survival.take_stock(save, "buns")
		Survival.change_need(save, "hunger", -30.0)
		hud.toast("You eat a sausage roll meant for customers.")
	else:
		hud.toast("The fridge is empty. Order food on the computer.")


func _can_light_candle() -> bool:
	var day := Survival.day_of(Survival.now(save))
	return int(save["world"]["candle_day"]) != day and Survival.stock(save, "candles") > 0


func _pray() -> void:
	if _can_light_candle():
		Survival.take_stock(save, "candles")
		save["world"]["candle_day"] = Survival.day_of(Survival.now(save))
		world.set_candle_lit(true)
		Survival.change_need(save, "stress", -35.0)
		hud.toast("You light a candle and pray. Your stress eases.")
	else:
		Survival.change_need(save, "stress", -25.0)
		hud.toast("You pray. Your stress eases.")
	Survival.change_lean(save, -1)
	var cause := Survival.advance(save, 10.0)
	if not cause.is_empty():
		_die(cause)


func _show_stock() -> void:
	var lines: PackedStringArray = []
	for product: Dictionary in GameData.PRODUCTS:
		lines.append("%s: %d" % [product["name"], Survival.stock(save, product["id"])])
	_set_busy(true)
	NoticeOverlay.show_notice(self, "Stock", "\n".join(lines), _set_busy.bind(false))


func _collect() -> void:
	var items := Survival.collect(save)
	_arrived = 0
	world.show_crates(0)
	var parts: PackedStringArray = []
	for id: String in items:
		parts.append("%d %s" % [items[id], GameData.product_def(id)["name"].to_lower()])
	Sound.play("door", 0.2, -4.0)
	hud.toast("You carry in %s." % ", ".join(parts))


func _sleep() -> void:
	var now := Survival.now(save)
	var hour := Survival.hour_of(now)
	if not (hour >= 20 or hour < 5 or Survival.need(save, "tiredness") >= 60.0):
		hud.toast("You are not tired enough to sleep.")
		return
	_set_busy(true)
	hud.fade.color = Color(0, 0, 0, 0)
	var tween := create_tween()
	tween.tween_property(hud.fade, "color:a", 1.0, 0.8)
	await tween.finished
	var cause := Survival.sleep(save)
	if not cause.is_empty():
		_die(cause)
		return
	_update_day()
	_save_now()
	var woke := Survival.now(save)
	hud.toast("Day %d, %s. You wake up." % [Survival.day_of(woke), Survival.clock_text(woke)])
	tween = create_tween()
	tween.tween_interval(0.6)
	tween.tween_property(hud.fade, "color:a", 0.0, 1.0)
	await tween.finished
	_set_busy(false)


# Shifts -----------------------------------------------------------------------

func _open_planner() -> void:
	if _busy or _dead or _paused:
		return
	Sound.click()
	_set_busy(true)
	DayPlanner.open(self)


func on_planner_closed() -> void:
	_set_busy(false)


## Spends the rest of the shift on an activity: fade out, move the clock on,
## fade back in and say what happened.
func spend_shift(id: String) -> void:
	var planner := get_tree().get_nodes_in_group("modal").filter(func(n: Node) -> bool: return n is DayPlanner)
	for node: Node in planner:
		node.remove_from_group("modal")
		node.queue_free()
	hud.fade.color = Color(0, 0, 0, 0)
	var tween := create_tween()
	tween.tween_property(hud.fade, "color:a", 1.0, 0.7)
	await tween.finished
	if id == "work":
		save["world"]["hatch_open"] = true
		world.set_hatch_open(true, false)
	var result := Survival.spend_shift(save, id, _character, _rng)
	if not str(result["cause"]).is_empty():
		_die(result["cause"])
		return
	_check_arrivals()
	_update_day()
	_update_shift()
	_save_now()
	hud.toast(result["text"])
	tween = create_tween()
	tween.tween_interval(0.5)
	tween.tween_property(hud.fade, "color:a", 0.0, 0.9)
	await tween.finished
	for notice: String in Survival.take_notices(save):
		hud.toast(notice)
	_set_busy(false)


# Computer ---------------------------------------------------------------------

func order_product(id: String) -> void:
	var problem := Survival.order(save, id)
	if problem.is_empty():
		Sound.play("beep")
	else:
		hud.toast(problem)


## The cameras only render while someone is watching them. At night, something
## may be standing out there that is not there when you go and look.
func set_feeds_live(on: bool) -> void:
	for unit in world.cameras:
		unit.set_live(on)
	var hour := Survival.hour_of(Survival.now(save))
	world.set_figure_visible(on and (hour >= 21 or hour < 5) and _rng.randf() < 0.45)


func on_computer_closed() -> void:
	_set_busy(false)


# Death ------------------------------------------------------------------------

func _die(cause: String) -> void:
	_dead = true
	_set_busy(true)
	Saves.kill_current(cause)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.fade.color = Color(0.22, 0.0, 0.02, 0.0)
	var tween := create_tween()
	tween.tween_property(hud.fade, "color:a", 0.92, 1.5)
	tween.tween_callback(_show_death.bind(cause))


func _show_death(cause: String) -> void:
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 620
	column.add_theme_constant_override("separation", 14)
	center.add_child(column)
	column.add_child(UiKit.heading("%s is dead." % Saves.current_character().full_name, 64))
	column.add_child(UiKit.wrapped_label(cause))
	column.add_child(UiKit.wrapped_label("This life is over. It can never be loaded again.", UiKit.SIZE_BODY, UiKit.ASH))
	column.add_child(UiKit.button("Return to menu", Router.goto.bind("main_menu")))
