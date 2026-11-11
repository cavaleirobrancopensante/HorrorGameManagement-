class_name TrailerGame
extends Control
## The trailer and its street: walking around, needs, the computer, sleep and
## death. The world is drawn small and scaled up for the PS1 look.

const MOUSE_SPEED := 0.0025
const AUTOSAVE_SECONDS := 90.0

var save: Dictionary
var world: TrailerWorld
var player: Player
var hud: GameHud
var touch: TouchControls
var stand: Stand
var character: PlayerCharacter

var _touch_mode := false
var _paused := false
var _busy := false
var _dead := false
var _recapture := false
var _autosave := 0.0
var _flicker_wait := 50.0
var _arrived := 0
var _day := 0
## Seconds of quiet before the next piece of music.
var _music_wait := 8.0
var _last_piece := ""
var _shift := -1
var _rng := RandomNumberGenerator.new()
## The figure the mirror and the cameras see, and the canvas it is drawn on.
## Your body for the mirror and the cameras, and what it holds.
var body: PersonRig
var _body_prop: Node3D
var _body_look := ""
## Game minutes since the last roll for a moment.
var _moment_minutes := 0.0
## What the crosshair has rested on, and for how long: tooltips wait a moment.
var _tip_target: Object = null
var _tip_wait := 0.0
const TIP_DELAY := 0.65
## Stages the persecution and the street's dangers.
var horror: HorrorDirector
## Your bat and slingshot.
var fighter: Fighter
var _in_church := false


func _ready() -> void:
	if Saves.current.is_empty():
		Router.goto.call_deferred("main_menu")
		return
	save = Saves.current
	Survival.ensure(save)
	character = Saves.current_character()
	_rng.randomize()
	_touch_mode = DisplayServer.is_touchscreen_available()
	Sound.play_ambience("hum")
	Sound.stop_music()
	Sound.music_finished.connect(_on_music_finished)
	_build()
	_restore()
	_warm_up()
	if not _touch_mode:
		hud.show_hint("Click to look around. WASD to move, E or click to use, Q or right click to eat what you hold, F torch, C plan the day, Esc pause.")


## The first time anything is drawn, the graphics card has to prepare it, and
## that froze the game for a moment: the first customer, the first look in
## the mirror, the first visit to church. While the screen fades in, a hidden
## camera looks once at every place and at a man and a woman, so it is all
## ready before you play.
func _warm_up() -> void:
	GameLog.loading("warming up")
	GameLog._loaded_frames = 30
	hud.fade.color.a = 1.0
	var eye := SubViewport.new()
	eye.size = Vector2i(160, 90)
	eye.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	world.get_parent().add_child(eye)
	var camera := Camera3D.new()
	camera.cull_mask = 0xFFFFF
	eye.add_child(camera)
	var rng := RandomNumberGenerator.new()
	var models: Array[PersonRig] = []
	for sex in ["man", "woman"]:
		var recipe := People.stranger(rng)
		recipe["sex"] = sex
		recipe["head"] = "Casual"
		recipe["body"] = "Casual"
		recipe["legs"] = "Casual"
		recipe["feet"] = "Casual"
		models.append(People.place(world, recipe, Vector3(-3.0 + models.size() * 0.8, TrailerWorld.GROUND, 7.0), 0.0))
	var looks := [
		[Vector3(-1.4, 1.5, 5.0), Vector3(-2.6, 1.0, 7.0)],
		[Vector3(1.8, 1.6, 1.2), Vector3(1.8, 1.0, 3.0)],
		[Vector3(5.0, 1.6, 1.0), Vector3(8.0, 1.0, 2.5)],
		[Vector3(9.0, 1.6, 1.0), Vector3(10.6, 1.2, 1.3)],
		[Vector3(3.0, 1.7, 9.0), Vector3(3.0, 1.2, 2.0)],
		[Church.ORIGIN + Vector3(10.0, 1.6, 0.0), Church.ORIGIN + Vector3(23.0, 2.0, 0.0)],
		[Church.ORIGIN + Vector3(14.0, 1.6, -2.0), Church.ORIGIN + Vector3(8.0, 1.0, -3.9)],
	]
	for look: Array in looks:
		camera.look_at_from_position(look[0], look[1])
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	world.church.set_mass("elevation")
	camera.look_at_from_position(Church.ORIGIN + Vector3(19.0, 1.6, 0.0), Church.ORIGIN + Vector3(23.0, 2.2, 0.0))
	await get_tree().process_frame
	world.church.set_mass("")
	for model in models:
		model.queue_free()
	eye.queue_free()
	var tween := create_tween()
	tween.tween_property(hud.fade, "color:a", 0.0, 0.6)


func _build() -> void:
	var container := SubViewportContainer.new()
	container.stretch = true
	container.stretch_shrink = Settings.pixel_scale
	Settings.picture_changed.connect(func() -> void: container.stretch_shrink = Settings.pixel_scale)
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
	player.camera.make_current()
	var look: Dictionary = character.appearance
	player.arm.dress(Color(GameData.SKIN_TONES.get(look["skin"], "#c79a6e")), Color("#4b4a55"))
	world.mirror.viewer = player.camera
	_make_body()
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
	touch.hand_pressed.connect(_use_hand)
	touch.arm_pressed.connect(_cycle_weapon)
	stand = Stand.new()
	add_child(stand)
	stand.setup(self)
	stand.message.connect(hud.toast)
	horror = HorrorDirector.new()
	add_child(horror)
	horror.setup(self)
	fighter = Fighter.new()
	add_child(fighter)
	fighter.setup(self)
	_set_busy(false)


## Your body, seen only in the mirror and on the cameras: built from your
## character, walking when you walk, and doing what your arm does.
func _make_body() -> void:
	player.body_sprite.visible = false
	body = People.place(player, People.player(character), player.global_position, 0.0)
	body.set_layers(TrailerWorld.LAYER_BODY)


## The pose and what is in your hand, copied onto the body when it changes.
func _update_body_pose() -> void:
	if body == null:
		return
	body.speed = Vector2(player.velocity.x, player.velocity.z).length()
	var pose := player.arm.pose()
	var held := ""
	if stand.held != null:
		held = "%s|%s" % [stand.held.data["kind"], StandRules.sauces_on(stand.held.data)]
	elif fighter != null and fighter.armed():
		held = fighter.weapon
	var look := "%s|%s" % [pose, held]
	if look == _body_look:
		return
	_body_look = look
	match pose:
		"swing":
			body.act("swing", 0.45)
		"shoot":
			body.act("aim", 0.4)
		"reach":
			body.act("pay", 0.5)
		_:
			body.hold_pose = pose
	if _body_prop != null:
		_body_prop.queue_free()
		_body_prop = null
	var prop: Node3D = null
	if stand.held != null:
		var copy := FoodItem.create(stand.held.data["kind"])
		copy.data = stand.held.data.duplicate()
		copy.refresh(character.stat_value("cooking"))
		copy.pick.collision_layer = 0
		copy.remove_from_group("food")
		prop = copy
	elif fighter != null and fighter.weapon == "bat":
		prop = People._rod(0.03, 0.75, Vector3(0.0, 0.0, -0.3), Vector3(-70.0, 0.0, 0.0), Color("#8a5a32"))
	elif fighter != null and fighter.weapon == "slingshot":
		prop = People._box(Vector3(0.06, 0.14, 0.02), Vector3(0.0, 0.05, -0.04), Color("#6b4426"))
	if prop != null:
		_body_prop = body.attach("Hand.R", prop)
		body.set_layers(TrailerWorld.LAYER_BODY)


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
	_set_in_church(Church.contains(player.position))
	world.set_hatch_open(bool(state["hatch_open"]), false)
	world.set_sign_open(bool(state.get("sign_open", true)))
	world.apply_upgrades(state["upgrades"])
	world.set_shutters(bool(state["shutters_closed"]), false)
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
		stand.tick(delta)
		_check_arrivals()
		_update_day()
		_update_shift()
		GameLog.clock = "%s %s" % [Survival.date_text(Survival.now(save)), Survival.clock_text(Survival.now(save))]
		for notice: String in Survival.take_notices(save):
			GameLog.bad(notice)
			hud.toast(notice)
		_autosave += delta
		if _autosave >= AUTOSAVE_SECONDS:
			_autosave = 0.0
			_save_now()
		_update_music(delta)
		_check_moment(delta * Survival.MINUTES_PER_SECOND)
		_check_illness()
		horror.tick(delta, _busy, _in_church)
		_flicker_wait -= delta
		if _flicker_wait <= 0.0:
			_flicker_wait = _rng.randf_range(45.0, 120.0)
			world.flicker()
	var target := player.focused
	var prompt := "" if _busy or fighter.attacks(target) else _prompt_for(target)
	hud.set_prompt(prompt)
	if fighter.armed():
		hud.set_holding("" if _busy else fighter.text() + ("" if _touch_mode else "   (R to switch)"), false)
		touch.arm_label = fighter.text().get_slice(" ", 0)
	else:
		hud.set_holding("" if _busy else stand.held_text(), stand.can_eat_held())
		touch.arm_label = "Arm"
	hud.set_step("" if _busy else stand.hint())
	_update_tip(target, delta)
	player.arm.holding = stand.held != null
	_update_body_pose()
	hud.bubbles = [] if _busy else stand.bubbles(player.camera, float(Settings.pixel_scale))
	if touch.hand_ready != stand.can_eat_held():
		touch.hand_ready = stand.can_eat_held()
		touch.queue_redraw()
	var ready := not prompt.is_empty() or fighter.armed()
	if touch.use_ready != ready:
		touch.use_ready = ready
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


## Music comes in pieces, with silence between them: the hum of the trailer is
## part of the score. The piece follows the hour, Sunday, and the soul.
func _update_music(delta: float) -> void:
	if Sound.is_music_playing():
		return
	_music_wait -= delta
	if _music_wait > 0.0:
		return
	_music_wait = 9999.0
	var piece := choose_piece()
	_last_piece = piece
	Sound.play_music(piece)


func choose_piece() -> String:
	var now := Survival.now(save)
	var light := Survival.daylight(now)
	if _in_church or (Survival.weekday(now) == 0 and light > 0.3):
		return "sunday"
	if light >= 0.5:
		return "overcast"
	# At night, unease grows with the state's attention and with stress.
	var dread := clampf(0.25 + Horror.attention(save) * 0.3 + Survival.need(save, "stress") / 400.0, 0.1, 0.8)
	if _last_piece == "outside":
		dread *= 0.5
	return "outside" if _rng.randf() < dread else "night_shift"


func _on_music_finished() -> void:
	if not _dead:
		_music_wait = _rng.randf_range(30.0, 75.0)


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
	if event.is_action_pressed("use_hand"):
		_use_hand()
		return
	if event.is_action_pressed("plan_day"):
		_open_planner()
		return
	if event.is_action_pressed("weapon"):
		_cycle_weapon()
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
		elif (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
			_use_hand()
		elif (event as InputEventMouseButton).button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and not _busy:
			_cycle_weapon()
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


## F3: pause and show the test log.
func open_log() -> void:
	if not _busy:
		go_back()
	var menus := get_tree().get_nodes_in_group("modal")
	LogPanel.open(menus[-1] if not menus.is_empty() else self)


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


func _use_hand() -> void:
	if _busy or _dead or _paused:
		return
	if stand.can_eat_held():
		player.arm.to_mouth(stand.use_held)
	else:
		stand.use_held()


func _toggle_light() -> void:
	if _busy or _dead:
		return
	player.flashlight.visible = not player.flashlight.visible
	touch.light_on = player.flashlight.visible
	touch.queue_redraw()
	Sound.click()


# Using things -----------------------------------------------------------------

func _prompt_for(target: Interactable) -> String:
	var kitchen := stand.prompt_for(target)
	if target == null or not kitchen.is_empty() or target.id in ["customer", "item", "surface"]:
		return kitchen
	match target.id:
		"door":
			return (target.get_meta("door") as Door).prompt()
		"computer":
			return "Use the computer"
		"sink":
			return "Drink tap water"
		"shower":
			return "Take a shower"
		"wardrobe":
			return "Change clothes"
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
		"coffee":
			return "Make coffee" if Survival.stock(save, "coffee") > 0 else "Kettle (no coffee left)"
		"shelves":
			return "Check the stock"
		"hatch":
			return "Close the hatch" if bool(save["world"]["hatch_open"]) else "Open the hatch"
		"sign":
			return "Turn the sign to CLOSED" if bool(save["world"].get("sign_open", true)) else "Turn the sign to OPEN"
		"delivery":
			return "Carry the delivery inside"
		"calendar":
			return "Plan the day"
		"shutters":
			return "Open the shutters" if save["world"]["shutters_closed"] else "Close the shutters"
		"barricade":
			var door := world.entrance
			if door.barricaded:
				return "Take down the barricade"
			if door.is_open:
				return "Planks (close the door to barricade it)"
			return "Barricade the door"
		"first_aid":
			var bandages := Survival.stock(save, "bandages")
			if bandages <= 0:
				return "First aid box: empty. Order bandages."
			if Survival.health(save) >= Survival.max_health(save):
				return "First aid box (%d bandages)" % bandages
			return "Bandage your wounds (%d left)" % bandages
		"church_street":
			if Parish.closed(save):
				return "St. Brigid's is closed: its doors are chained"
			if not Soul.church_open(save, Survival.now(save)):
				return "St. Brigid's is locked at night"
			return "Walk to St. Brigid's (%d min)" % int(Church.WALK_MINUTES)
		"church_exit":
			return "Walk home (%d min)" % int(Church.WALK_MINUTES)
		"pew":
			if Survival.activity_blocked(save, "mass").is_empty() and Parish.sacraments_available(save):
				return "Hear Mass"
			return "Kneel and pray"
		"tabernacle":
			return "Pray before the Blessed Sacrament"
		"confession":
			if Soul.confession_open(save, Survival.now(save)):
				return "Go to confession"
			if not Parish.priest_free(save):
				return "No confessions: the priest is being held"
			return "Confessions: evenings, and Saturday afternoon"
		"priest":
			return "Talk to %s" % Soul.PRIEST
		"font":
			return "Bless yourself with holy water"
		"votive":
			return "Light a candle to Our Lady (1 credit)"
		"poor_box":
			return "Give to the poor box (5 credits)"
	return ""


func _interact() -> void:
	if _busy or _dead or _paused:
		return
	var target := player.focused
	if fighter.attacks(target):
		if not _busy:
			fighter.attack()
		return
	if _prompt_for(target).is_empty():
		return
	if not fighter.armed():
		player.arm.reach()
	if stand.use(target) or target == null:
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
		"shower":
			_shower()
		"wardrobe":
			_set_busy(true)
			WardrobePanel.open(self, character)
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
		"sign":
			var open_sign := not bool(save["world"].get("sign_open", true))
			save["world"]["sign_open"] = open_sign
			world.set_sign_open(open_sign)
			Sound.play("click", 0.1)
			GameLog.add("info", "Turned the sign to %s." % ("OPEN" if open_sign else "CLOSED"))
			hud.toast("Open for business." if open_sign else "Closed. Nobody new will come; anyone already waiting can still be served.")
		"hatch":
			var open := not bool(save["world"]["hatch_open"])
			save["world"]["hatch_open"] = open
			world.set_hatch_open(open, true)
			Sound.play("door", 0.1)
		"bed":
			_bed()
		"altar":
			_pray()
		"delivery":
			_collect()
		"calendar":
			_open_planner()
		"barricade":
			var door := world.entrance
			if door.barricaded:
				door.set_barricade(false)
				hud.toast("You pull the planks down.")
			elif not door.is_open:
				door.set_barricade(true)
				Sound.play("knock", 0.2, -2.0)
				hud.toast("You nail the planks across the door. It will hold for a while.")
		"first_aid":
			if Survival.health(save) < Survival.max_health(save) and Survival.take_stock(save, "bandages"):
				Survival.change_health(save, 30.0)
				Survival.change_need(save, "stress", -4.0)
				Sound.play("step", 0.1, -6.0)
				hud.toast("You clean and bandage the wound.")
		"shutters":
			var closed := not bool(save["world"]["shutters_closed"])
			save["world"]["shutters_closed"] = closed
			world.set_shutters(closed, true)
			Sound.play("door", 0.15, -10.0)
			save["world"]["learned"]["shutters"] = true
		"church_street":
			if Soul.church_open(save, Survival.now(save)):
				_walk(true)
		"church_exit":
			_walk(false)
		"pew":
			if Survival.activity_blocked(save, "mass").is_empty() and Parish.sacraments_available(save):
				spend_shift("mass")
			else:
				_church_prayer("You kneel in the pew and pray. The church is quiet but for the heating ticking.")
		"tabernacle":
			_church_prayer("You kneel at the rail before the tabernacle. The red lamp burns.")
		"confession":
			if Soul.confession_open(save, Survival.now(save)):
				_confession()
		"priest":
			_talk_to_priest()
		"font":
			Survival.change_need(save, "stress", -3.0)
			Sound.play("water", 0.1, -12.0)
			hud.toast("You bless yourself. The water is cold.")
		"votive":
			if Survival.money(save) < 1:
				hud.toast("You have no credits for a candle.")
			else:
				save["survival"]["money"] = Survival.money(save) - 1
				world.church.light_votive()
				hud.toast("You light a candle to Our Lady and ask her to pray for you.")
		"poor_box":
			var given := Parish.give(save, 5)
			if given.begins_with("You put"):
				Virtue.act(save, "charity", character, 0.5)
				Horror.notice(save, 0.5)
				GameLog.good("Gave 5 credits to the poor box.")
			hud.toast(given)


## A quarter of an hour under the water: it eases stress and wakes you a little.
func _shower() -> void:
	Sound.play("water", 0.0, -2.0)
	Survival.change_need(save, "stress", -15.0)
	Survival.change_need(save, "tiredness", -5.0)
	var cause := Survival.advance(save, 15.0)
	if not cause.is_empty():
		_die(cause)
		return
	hud.toast("You take a shower. The water runs brown, then clear.")


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
		Survival.change_need(save, "stress", -6.0)
		hud.toast("You light a candle and pray. For a while the trailer is very quiet.")
	else:
		Survival.change_need(save, "stress", -4.0)
		hud.toast("You kneel at the little altar and pray, and are quiet for a while.")
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
	var installed: PackedStringArray = []
	for id: String in items:
		if not GameData.upgrade_def(id).is_empty():
			installed.append(GameData.upgrade_def(id)["name"].to_lower())
		else:
			parts.append("%d %s" % [items[id], GameData.product_def(id)["name"].to_lower()])
	Sound.play("door", 0.2, -4.0)
	if not parts.is_empty():
		hud.toast("You carry in %s." % ", ".join(parts))
	if not installed.is_empty():
		world.apply_upgrades(save["world"]["upgrades"])
		hud.toast("You install the %s." % " and the ".join(installed))


## The bed: sleep the night, or let weeks pass in a summary, living them as
## your habits would. A life is long; this is how a game can hold one.
func _bed() -> void:
	var hour := Survival.hour_of(Survival.now(save))
	if not (hour >= 20 or hour < 5 or Survival.need(save, "tiredness") >= 60.0):
		hud.toast("You are not tired enough to sleep.")
		return
	if Life.ill(save):
		_sleep()
		return
	_set_busy(true)
	ChoiceOverlay.ask(self, "Bed", "You are %d. %s" % [Life.age(save), Parish.describe(save)], [
		["Sleep until morning", _sleep_now],
		["Let a week go by", _pass_time.bind(7)],
		["Let a month go by", _pass_time.bind(28)],
		["Let a season go by", _pass_time.bind(91)],
	], _set_busy.bind(false))


func _sleep_now() -> void:
	_set_busy(false)
	_sleep()


func _pass_time(days: int) -> void:
	hud.fade.color = Color(0, 0, 0, 0)
	var tween := create_tween()
	tween.tween_property(hud.fade, "color:a", 1.0, 0.8)
	await tween.finished
	stand.clear()
	var result := Life.pass_days(save, character, days, _rng)
	for notice: String in Survival.take_notices(save):
		result["lines"].append(notice)
	world.apply_upgrades(save["world"]["upgrades"])
	_update_day()
	_save_now()
	GameLog.add("info", "%d days passed in a summary." % int(result["days"]))
	NoticeOverlay.show_notice(self, "The weeks go by", "\n\n".join(PackedStringArray(result["lines"])), func() -> void:
		_set_busy(false)
		_sleep())


func _sleep() -> void:
	var now := Survival.now(save)
	_set_busy(true)
	hud.fade.color = Color(0, 0, 0, 0)
	var tween := create_tween()
	tween.tween_property(hud.fade, "color:a", 1.0, 0.8)
	await tween.finished
	var total := Survival.sleep_minutes(save)
	var night := Horror.night(save, _rng, bool(save["world"]["shutters_closed"]), total)
	var woken: bool = not night.is_empty() and night["id"] != "pry_marks"
	var cause := Survival.advance(save, float(night["after"]) if woken else total, Survival.SLEEP_RATES)
	if not cause.is_empty():
		_die(cause)
		return
	_update_day()
	if woken:
		await _burglar()
		return
	_save_now()
	var woke := Survival.now(save)
	hud.toast("Day %d, %s. You wake up." % [Survival.day_of(woke), Survival.clock_text(woke)])
	if not night.is_empty():
		hud.toast("In the morning there are pry marks on your window shutter. It held.")
	tween = create_tween()
	tween.tween_interval(0.6)
	tween.tween_property(hud.fade, "color:a", 0.0, 1.0)
	await tween.finished
	_set_busy(false)


## Glass breaks in the night: someone is coming in through the window.
func _burglar() -> void:
	if save["world"]["shutters_closed"]:
		save["world"]["shutters_closed"] = false
		world.set_shutters(false, false)
	player.global_position = Vector3(8.3, 0.05, 1.7)
	player.rotation.y = PI
	player.set_pitch(deg_to_rad(6.0))
	var thief: PersonRig = People.place(world, People.role("burglar", _rng), Vector3(8.3, -0.15, 3.4), 0.0)
	thief.hold_pose = "reach"
	Sound.play("glass")
	await get_tree().create_timer(0.4).timeout
	var tween := create_tween()
	tween.tween_property(hud.fade, "color:a", 0.0, 0.35)
	await tween.finished
	# A moment to see him before you decide.
	hud.toast("Someone is coming in through the window.")
	await get_tree().create_timer(1.8).timeout
	var chance := Horror.fight_chance(character.stat_value("endurance"), character.stat_value("vigilance"))
	var odds := "good odds" if chance >= 0.6 else ("even odds" if chance >= 0.4 else "poor odds")
	ChoiceOverlay.ask(self, "Someone at the window", "Glass on the floor. A man in black is climbing in through your window, reaching for the cash tin. He has not seen that you are awake.", [
		["Fight him (%s)" % odds, _burglar_fight.bind(thief)],
		["Lie still and let him take it", _burglar_let.bind(thief)],
	], Callable(), Color("#ff6a70"), 0.35)


## You grab the bat from beside the bed, and he is in the room.
func _burglar_fight(thief: Node3D) -> void:
	thief.queue_free()
	_set_busy(false)
	fighter.set_weapon("bat")
	horror.burglar_fight()


func _burglar_let(thief: Node3D) -> void:
	var text := Horror.let_burglar(save, _rng)
	thief.queue_free()
	_after_night(text, true)


func _after_night(text: String, window := false) -> void:
	if window and not bool(save["world"]["learned"].get("shutters", false)):
		text += "\n\nThe window has a roller shutter. Close it before you sleep."
	_save_now()
	NoticeOverlay.show_notice(self, "The night", text, func() -> void:
		if Survival.health(save) <= 0.0:
			_die("A burglar killed you in your own trailer.")
			return
		_set_busy(false)
	)


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
	stand.clear()
	if id == "work":
		save["world"]["hatch_open"] = true
		world.set_hatch_open(true, false)
	var result := Survival.spend_shift(save, id, character, _rng)
	if not str(result["cause"]).is_empty():
		_die(result["cause"])
		return
	_check_arrivals()
	_update_day()
	_update_shift()
	_save_now()
	hud.toast(result["text"])
	if id == "mass":
		_take_pew()
	tween = create_tween()
	tween.tween_interval(0.5)
	tween.tween_property(hud.fade, "color:a", 0.0, 0.9)
	await tween.finished
	for notice: String in Survival.take_notices(save):
		GameLog.bad(notice)
		hud.toast(notice)
	if id == "mass":
		_elevation()
		return
	_set_busy(false)


## Mass is heard from the front pew, looking up the nave to the high altar.
func _take_pew() -> void:
	player.global_position = Church.ORIGIN + Vector3(15.55, 0.05, -1.4)
	player.rotation.y = -PI / 2.0 - 0.1
	player.set_pitch(deg_to_rad(-3.0))
	# Your eyes are on the altar: the view narrows on it until Mass ends.
	player.camera.fov = 30.0
	world.church.set_mass("altar")


## The high point of the Mass: from the front pew you watch the priest, his
## back to you as he faces the altar with all of you, raise the Host high.
func _elevation() -> void:
	var church := world.church
	await get_tree().create_timer(1.2).timeout
	church.set_mass("elevation")
	for ring in 3:
		Sound.bell()
		await get_tree().create_timer(0.9).timeout
	await get_tree().create_timer(1.2).timeout
	_offer_communion()


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
		unit.set_live(on and not Horror.feeds_off(save))
	var hour := Survival.hour_of(Survival.now(save))
	world.set_figure_visible(on and (hour >= 21 or hour < 5) and _rng.randf() < 0.45)


func on_computer_closed() -> void:
	_set_busy(false)


## Back from the wardrobe: look is the new appearance, or empty if cancelled.
func on_wardrobe_closed(look: Dictionary) -> void:
	_set_busy(false)
	if look.is_empty() or look == character.appearance:
		return
	character.appearance = look.duplicate()
	save["character"] = character.to_dict()
	if body != null:
		body.queue_free()
		body = null
	_make_body()
	Sound.play("door", 0.2, -10.0)
	hud.toast("You change your clothes.")


# Tooltips ---------------------------------------------------------------------

## Holding the crosshair on something for a moment shows what it is.
func _update_tip(target: Interactable, delta: float) -> void:
	var looked: Object = target
	if looked == null:
		var collider: Object = player.aim.get("collider")
		if collider is Enemy:
			looked = collider
	if _busy or looked != _tip_target:
		_tip_target = null if _busy else looked
		_tip_wait = 0.0
		hud.set_tip("", "")
		return
	if looked == null:
		return
	_tip_wait += delta
	if _tip_wait < TIP_DELAY:
		return
	var tip := _tip_for(looked)
	hud.set_tip(tip[0] if tip.size() > 0 else "", tip[1] if tip.size() > 1 else "")


## [title, text] for whatever the crosshair rests on, or [] for nothing to say.
func _tip_for(looked: Object) -> Array:
	if looked is Enemy:
		var enemy := looked as Enemy
		var tip: Array = Tips.ENEMIES.get(enemy.kind, []).duplicate()
		if not tip.is_empty() and not enemy.is_down:
			tip[1] = "%s\nHealth: %d%%" % [tip[1], roundi(enemy.health / float(enemy.stats["health"]) * 100.0)]
		return tip
	var target := looked as Interactable
	match target.id:
		"item":
			var item: FoodItem = target.get_meta("item")
			var data := item.data
			var lines: PackedStringArray = []
			if StandRules.is_sauce(data):
				lines.append("%d portions left. With food in your hand, look at the bottle to add sauce." % int(data["left"]))
				if int(data["left"]) <= 0:
					lines.append("Empty: use it to refill from stock.")
			elif data["kind"] in StandRules.MEATS:
				var state := StandRules.cook_state(data, character.stat_value("cooking"), Survival.has_upgrade(save, "grill"))
				lines.append({"raw": "Raw. Cook it on the grill.", "cooked": "Cooked. Put it in a roll before it burns.", "burnt": "Burnt. Bin it."}[state])
			elif data["kind"] in StandRules.FOODS:
				lines.append("Ready to hand over, if it matches an order.")
			elif data["kind"] == "bun":
				lines.append("Add cooked meat to make a hot dog or a burger.")
			if data.get("dirty", false):
				lines.append("Dirty: every customer will refuse it.")
			elif data.get("odd", false):
				lines.append("It sat somewhere food does not belong. Customers will mind.")
			var title := item.describe(character.stat_value("cooking"))
			return [title.left(1).to_upper() + title.substr(1), "\n".join(lines)]
		"surface":
			var surface := target as Surface
			var dirt := float(save["world"]["dirt"].get(surface.key, 0.0))
			var state := "Clean." if dirt < 0.08 else ("Greasy. Wipe it with cleaning spray soon." if dirt < Surface.DIRTY else "Filthy. Food put here will be refused. Wipe it now.")
			var what := "Meat cooks wherever it sits on it." if surface.kind == "grill" else "Food belongs here; customers mind it anywhere else."
			return [surface.label.left(1).to_upper() + surface.label.substr(1), "%s\n%s" % [what, state]]
		"customer":
			var customer: Customer = target.get_meta("customer")
			var feeling: String = {"happy": "Happy", "neutral": "Getting impatient", "angry": "Angry"}[StandRules.face(customer.mood)]
			return ["Customer", "Wants: %s.\n%s. The sooner you serve them, the bigger the tip." % [StandRules.order_text(customer.order).replace("\n", " "), feeling]]
		"door":
			var door: Door = target.get_meta("door")
			if door == world.entrance:
				var state := "Barricaded." if door.barricaded else ("Open." if door.is_open else "Closed.")
				return ["Front door", "%s Close it, and barricade it with the planks, when trouble comes." % state]
			return ["Door", "Inside doors open for anyone."]
	return Tips.world(target.id)


# Fighting ---------------------------------------------------------------------

func _cycle_weapon() -> void:
	if _busy or _dead or _paused:
		return
	fighter.cycle()


## Something hurts you. cause: what the death screen says if it kills you.
func hurt(amount: float, cause: String) -> void:
	if _dead:
		return
	var lost := Combat.taken(amount, character)
	Survival.change_health(save, -lost)
	GameLog.bad("Hurt by %s: -%d health (%d left)." % [cause, roundi(lost), roundi(Survival.health(save))])
	Survival.change_need(save, "stress", amount * 0.5)
	hud.flash(Color(0.6, 0.0, 0.0, 0.45))
	horror._shake(0.25, 0.06)
	if Survival.health(save) <= 0.0:
		_die(cause)


# The church -------------------------------------------------------------------

func _set_in_church(inside: bool) -> void:
	_in_church = inside
	world.set_in_church(inside)
	if inside:
		world.church.informant.visible = Horror.attention(save) >= 0.3
		Horror.notice(save, 1.0)


## The walk to St. Brigid's or back home: a fade and twenty minutes.
func _walk(to_church: bool) -> void:
	_set_busy(true)
	hud.fade.color = Color(0, 0, 0, 0)
	var tween := create_tween()
	tween.tween_property(hud.fade, "color:a", 1.0, 0.7)
	await tween.finished
	stand.clear()
	var cause := Survival.advance(save, Church.WALK_MINUTES)
	if not cause.is_empty():
		_die(cause)
		return
	if to_church:
		player.position = Church.SPAWN
		player.rotation.y = Church.SPAWN_YAW
	else:
		player.position = Church.HOME_SPAWN
		player.rotation.y = Church.HOME_YAW
	player.set_pitch(0.0)
	_set_in_church(to_church)
	_save_now()
	if to_church:
		hud.toast("St. Brigid's. A state drone hums above the door as you go in.")
		if world.church.informant.visible:
			hud.toast("A man in a grey coat stands at the back. He does not pray.")
	else:
		_walk_home_events()
	tween = create_tween()
	tween.tween_interval(0.3)
	tween.tween_property(hud.fade, "color:a", 0.0, 0.8)
	await tween.finished
	_set_busy(false)


## Faithfulness draws the state's attention. The more it watches you, the
## likelier a fine on the way home.
func _walk_home_events() -> void:
	var watched := Horror.attention(save)
	if watched >= 0.25 and _rng.randf() < clampf(watched * 0.8, 0.2, 0.6):
		var fine := mini(8, Survival.money(save))
		save["survival"]["money"] = Survival.money(save) - fine
		hud.toast("A Civic patrol stops you outside the church. 'Unregistered gathering.' Fined %d credits." % fine)
	else:
		hud.toast("You walk home past the cameras.")


## A moment of prayer in the church: quiet, and nothing to count.
func _church_prayer(text: String) -> void:
	Survival.change_need(save, "stress", -4.0)
	hud.toast(text)
	var cause := Survival.advance(save, 15.0)
	if not cause.is_empty():
		_die(cause)


## Confession is mercy. You bring what you carry, and it is taken from you.
func _confession() -> void:
	_set_busy(true)
	var lines := Soul.examination(save)
	var body := "You kneel in the dark. The grille slides open, and Father Columba says quietly, \"Welcome. Take your time.\"\n\n"
	if lines.is_empty():
		body += "You search your conscience. Nothing stands out, only the ordinary dust of the days."
	else:
		body += "You tell him:\n" + "\n".join(lines)
	ChoiceOverlay.ask(self, "Confession", body, [["\"Bless me, Father, for I have sinned.\"", _confess]], _set_busy.bind(false), UiKit.LITURGICAL_GOLD)


func _confess() -> void:
	var text := Soul.confess(save)
	Horror.notice(save, 1.0)
	GameLog.good("Went to confession.")
	var cause := Survival.advance(save, 20.0)
	if not cause.is_empty():
		_die(cause)
		return
	_save_now()
	NoticeOverlay.show_notice(self, "Absolution", text, _set_busy.bind(false))


func _talk_to_priest() -> void:
	var lines := [
		"\"They want a list of everyone who comes on Sundays. I told them I have a poor memory.\"",
		"\"Come in the evening, if you need confession. The cameras watch the door less once the light goes.\"",
		"\"Fear is not a sin. What you do because of it can be.\"",
		"\"The kiosk robots never sleep. You must. Rest is not sloth.\"",
		"\"Virtue is a habit, like your grill. Every day you light it, it lights more easily.\"",
		"\"The parish is not this building. It is the people who keep coming.\"",
	]
	if not Virtue.regrets(save).is_empty():
		lines.append("\"You look like someone carrying something heavy. The box is right there, any evening.\"")
	if Parish.strength(save) < 30.0:
		lines.append("\"We are fewer every week. Bring someone with you on Sunday, if you can.\"")
	hud.toast("%s: %s" % [Soul.PRIEST, lines[_rng.randi_range(0, lines.size() - 1)]])


func _offer_communion() -> void:
	var body := "The bells ring as the priest lifts the Host high over the altar. Soon he turns to you: \"Ecce Agnus Dei. Behold the Lamb of God.\""
	ChoiceOverlay.ask(self, "Communion", body, [
		["Go up and receive", _communion.bind(true)],
		["Stay in the pew", _communion.bind(false)],
	], Callable(), UiKit.LITURGICAL_GOLD, 0.35)


func _communion(receive: bool) -> void:
	var text := Soul.communion_text(receive)
	GameLog.good("Received Communion." if receive else "Made a spiritual communion.")
	_save_now()
	world.church.set_mass("altar")
	NoticeOverlay.show_notice(self, "Communion", text, func() -> void:
		world.church.set_mass("")
		player.camera.fov = 75.0
		_set_busy(false))


# Moments ------------------------------------------------------------------------

func _check_moment(minutes: float) -> void:
	if _busy or _in_church:
		return
	_moment_minutes += minutes
	if _moment_minutes < 60.0:
		return
	_moment_minutes = 0.0
	var waiting := not stand.waiting_orders().is_empty() or stand.spots.any(func(c: Variant) -> bool: return c != null and is_instance_valid(c))
	var entry := Moments.roll(save, _rng, 1.0, waiting)
	if not entry.is_empty():
		_moment(entry)


## A moment: a real choice, put plainly, with no hint of which "pays".
func _moment(entry: Dictionary) -> void:
	_set_busy(true)
	Sound.play("beep", 0.05, -12.0)
	var choices := []
	for option: Dictionary in entry["options"]:
		choices.append([option["label"], _choose.bind(option)])
	ChoiceOverlay.ask(self, "A moment", entry["text"], choices, Callable(), UiKit.VESTMENT_LIGHT)


func _choose(option: Dictionary) -> void:
	var result := Moments.choose(save, option, character)
	var virtue_name: String = GameData.virtue_def(option["virtue"])["name"]
	if option["kind"] == "good":
		GameLog.good("%s: %s" % [virtue_name, option["label"]])
	else:
		GameLog.bad("Failed in %s: %s" % [virtue_name.to_lower(), option["label"]])
	if not str(result["cause"]).is_empty():
		_die(result["cause"])
		return
	hud.toast(result["text"])
	if not str(result["growth"]).is_empty():
		hud.toast(result["growth"])
	_set_busy(false)


# The last illness -------------------------------------------------------------------

var _illness_told := false


## Old age: when the last illness begins you are told, and may send for the
## priest; when it has run its course, the end comes.
func _check_illness() -> void:
	if _busy or _dead or not Life.ill(save):
		return
	if not _illness_told:
		_illness_told = true
		_set_busy(true)
		ChoiceOverlay.ask(self, "The last illness", "Your heart is failing, and you know it. You are %d. There is time, a little, to put things in order." % Life.age(save), [
			["Send for Father Columba", _send_for_priest],
		], _set_busy.bind(false), UiKit.LITURGICAL_GOLD)
		return
	if Life.illness_over(save):
		# If you never sent for him, those who love you may have.
		if int(save["life"]["anointed"]) == 0 and Parish.sacraments_available(save) and _rng.randf() < 0.3 + Life.trust(save) / 200.0:
			Life.send_for_priest(save)
		_die("Died in bed, of old age, with the lamp still lit.")


func _send_for_priest() -> void:
	var text := Life.send_for_priest(save)
	_save_now()
	NoticeOverlay.show_notice(self, "The last sacraments", text, _set_busy.bind(false))


## For the life panel: send for the priest while ill.
func can_send_for_priest() -> bool:
	return Life.ill(save) and int(save["life"]["anointed"]) == 0


func send_for_priest_from_menu() -> void:
	_send_for_priest()


# Death ------------------------------------------------------------------------

func _die(cause: String) -> void:
	_dead = true
	GameLog.bad("Died: %s." % cause)
	_set_busy(true)
	Saves.kill_current(cause)
	Sound.stop_ambience()
	Sound.play_music("requiem")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# A good death fades to warm dark; a violent one to red.
	var peaceful := int(save["life"]["anointed"]) > 0
	hud.fade.color = Color(0.1, 0.07, 0.03, 0.0) if peaceful else Color(0.22, 0.0, 0.02, 0.0)
	var tween := create_tween()
	tween.tween_property(hud.fade, "color:a", 0.94, 1.5)
	tween.tween_callback(_show_death.bind(cause))


func _show_death(cause: String) -> void:
	var ending := Life.ending(save, character, cause)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 760
	column.add_theme_constant_override("separation", 12)
	center.add_child(column)
	column.add_child(UiKit.heading(ending["title"], 58))
	for line: String in ending["lines"]:
		column.add_child(UiKit.wrapped_label(line, UiKit.SIZE_SMALL))
	column.add_child(UiKit.wrapped_label("This life is over. It can never be loaded again.", UiKit.SIZE_SMALL, UiKit.ASH))
	column.add_child(UiKit.button("Return to menu", Router.goto.bind("main_menu")))
