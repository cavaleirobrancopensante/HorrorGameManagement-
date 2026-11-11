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
## Game minutes since the last roll for a temptation.
var _tempt_minutes := 0.0
## What the crosshair has rested on, and for how long: tooltips wait a moment.
var _tip_target: Object = null
var _tip_wait := 0.0
const TIP_DELAY := 0.65
## Stages the demonic and the state, from the state of your soul.
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
	if not _touch_mode:
		hud.show_hint("Click to look around. WASD to move, E or click to use, Q or right click to eat what you hold, F torch, C plan the day, Esc pause.")


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
		for notice: String in Survival.take_notices(save):
			hud.toast(notice)
		_autosave += delta
		if _autosave >= AUTOSAVE_SECONDS:
			_autosave = 0.0
			_save_now()
		_update_music(delta)
		_check_temptation(delta * Survival.MINUTES_PER_SECOND)
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
	# At night, dread grows with sin and with stress.
	var lean := float(save["soul"].get("horror_lean", 0))
	var dread := clampf(0.25 + lean / 200.0 + Survival.need(save, "stress") / 400.0, 0.1, 0.8)
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
			if not Soul.church_open(Survival.now(save)):
				return "St. Brigid's is locked at night"
			return "Walk to St. Brigid's (%d min)" % int(Church.WALK_MINUTES)
		"church_exit":
			return "Walk home (%d min)" % int(Church.WALK_MINUTES)
		"pew":
			if Survival.activity_blocked(save, "mass").is_empty():
				return "Hear Mass"
			return "Kneel and pray"
		"tabernacle":
			return "Pray before the Blessed Sacrament"
		"confession":
			if Soul.confession_open(Survival.now(save)):
				return "Go to confession"
			return "Confessions: evenings, and Saturday afternoon"
		"priest":
			return "Talk to %s" % Soul.PRIEST
		"font":
			return "Bless yourself with holy water"
		"votive":
			return "Light a candle to Our Lady (1 credit)"
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
			if Soul.church_open(Survival.now(save)):
				_walk(true)
		"church_exit":
			_walk(false)
		"pew":
			if Survival.activity_blocked(save, "mass").is_empty():
				spend_shift("mass")
			else:
				_church_prayer("You kneel in the pew and pray. The church is quiet but for the heating ticking.", -15.0)
		"tabernacle":
			_church_prayer("You kneel at the rail before the tabernacle. The red lamp burns.", -25.0)
		"confession":
			if Soul.confession_open(Survival.now(save)):
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
				Survival.change_need(save, "stress", -8.0)
				Survival.change_lean(save, -1)
				hud.toast("You light a candle to Our Lady and ask her to pray for you.")


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
		Survival.change_need(save, "stress", -35.0)
		hud.toast("You light a candle and pray. Your stress eases.")
	else:
		Survival.change_need(save, "stress", -25.0)
		hud.toast("You pray. Your stress eases.")
	Survival.change_lean(save, -1)
	if Soul.do_penance(save):
		hud.toast("You say your penance.")
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
	var total := Survival.sleep_minutes(save)
	var night := Horror.night(save, _rng, bool(save["world"]["shutters_closed"]), total)
	var woken: bool = not night.is_empty() and night["id"] != "pry_marks"
	var cause := Survival.advance(save, float(night["after"]) if woken else total, Survival.SLEEP_RATES)
	if not cause.is_empty():
		_die(cause)
		return
	_update_day()
	if woken:
		if night["id"] == "burglar":
			await _burglar()
		else:
			await _paralysis()
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


## You wake and cannot move. Something comes closer.
func _paralysis() -> void:
	player.global_position = Vector3(9.0, 0.05, 1.9)
	player.rotation.y = PI / 2.0
	player.set_pitch(deg_to_rad(-4.0))
	world.blackout(true)
	var result := Horror.paralysis(save, character.stat_value("nerve"), _rng)
	var shape := horror._shape(Vector3(6.9, 0.0, 1.9), TrailerWorld.LAYER_WORLD, 6.0)
	var tween := create_tween()
	tween.tween_property(hud.fade, "color:a", 0.0, 1.2)
	await tween.finished
	Sound.play("tempt", 0.0, -2.0)
	var approach := create_tween()
	approach.tween_property(shape, "global_position:x", 8.25, 4.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await approach.finished
	if result["face"]:
		await horror._jumpscare()
	if is_instance_valid(shape):
		shape.queue_free()
	world.blackout(false)
	_after_night(result["text"])


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
	tween = create_tween()
	tween.tween_interval(0.5)
	tween.tween_property(hud.fade, "color:a", 0.0, 0.9)
	await tween.finished
	for notice: String in Survival.take_notices(save):
		hud.toast(notice)
	if id == "mass":
		_offer_communion()
		return
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
	Survival.change_health(save, -Combat.taken(amount, character))
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
		world.church.informant.visible = int(save["soul"]["horror_lean"]) <= -15


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


## Faithfulness draws the state's attention. The more it leans that way, the
## likelier a fine on the way home.
func _walk_home_events() -> void:
	var lean := int(save["soul"]["horror_lean"])
	if lean <= -20 and _rng.randf() < clampf(-lean / 100.0, 0.2, 0.6):
		var fine := mini(8, Survival.money(save))
		save["survival"]["money"] = Survival.money(save) - fine
		hud.toast("A Civic patrol stops you outside the church. 'Unregistered gathering.' Fined %d credits." % fine)
	else:
		hud.toast("You walk home past the cameras.")


func _church_prayer(text: String, stress: float) -> void:
	Survival.change_need(save, "stress", stress)
	Survival.change_lean(save, -1)
	hud.toast(text)
	if Soul.do_penance(save):
		hud.toast("You say your penance.")
	var cause := Survival.advance(save, 15.0)
	if not cause.is_empty():
		_die(cause)


func _confession() -> void:
	_set_busy(true)
	var lines := Soul.examination(save)
	var body := "You kneel in the dark. The grille slides open. \"Bless me, Father, for I have sinned.\"\n\n"
	if lines.is_empty():
		body += "You search your conscience and find little on record since your last confession."
	else:
		body += "Your conscience:\n" + "\n".join(lines)
	var choices := [["Confess everything", _confess.bind(true)]]
	if Soul.has_grave(save):
		choices.append(["Leave out the worst of it", _confess.bind(false)])
	ChoiceOverlay.ask(self, "Confession", body, choices, _set_busy.bind(false))


func _confess(full: bool) -> void:
	var text := Soul.confess(save, full)
	var cause := Survival.advance(save, 20.0)
	if not cause.is_empty():
		_die(cause)
		return
	_save_now()
	NoticeOverlay.show_notice(self, Soul.PRIEST, text, _set_busy.bind(false))


func _talk_to_priest() -> void:
	var lines := [
		"\"They want a list of everyone who comes on Sundays. I told them I have a poor memory.\"",
		"\"Come in the evening, if you need confession. The cameras watch the door less once the light goes.\"",
		"\"Fear is not a sin. What you do because of it can be.\"",
		"\"The kiosk robots never sleep. You must. Rest is not sloth.\"",
		"\"I have heard the stories about the rail yard. Stay inside after dark, and keep your candle lit.\"",
	]
	if not Soul.in_grace(save):
		lines.append("\"You look like a man carrying something heavy. The box is right there.\"")
	if int(save["soul"]["horror_lean"]) >= 20:
		lines.append("\"Something follows you in here and waits at the door. It cannot come further. Do not let it in at home either.\"")
	hud.toast("%s: %s" % [Soul.PRIEST, lines[_rng.randi_range(0, lines.size() - 1)]])


func _offer_communion() -> void:
	var body := "The priest holds up the Host. \"Behold the Lamb of God.\""
	if not Soul.in_grace(save):
		body += "\n\nYou are not in a state of grace."
	ChoiceOverlay.ask(self, "Communion", body, [
		["Go up and receive", _communion.bind(true)],
		["Stay in the pew", _communion.bind(false)],
	])


func _communion(receive: bool) -> void:
	var text := Soul.receive_communion(save) if receive else Soul.spiritual_communion(save)
	_save_now()
	NoticeOverlay.show_notice(self, "Communion", text, _set_busy.bind(false))


# Temptation -------------------------------------------------------------------

func _check_temptation(minutes: float) -> void:
	if _busy or _in_church:
		return
	_tempt_minutes += minutes
	if _tempt_minutes < 60.0:
		return
	_tempt_minutes = 0.0
	var entry := Temptation.roll(save, character, _rng, 1.0)
	if not entry.is_empty():
		_tempt(entry)


func _tempt(entry: Dictionary) -> void:
	_set_busy(true)
	Sound.play("tempt", 0.05, -4.0)
	var sin_def := GameData.sin_def(entry["sin"])
	ChoiceOverlay.ask(self, sin_def["sin"], entry["text"], [
		[entry["give"], _give_in.bind(entry)],
		["%s (resisting costs stress)" % entry["resist"], _resist.bind(entry)],
	], Callable(), UiKit.SANCTUARY)


func _give_in(entry: Dictionary) -> void:
	var result := Temptation.give_in(save, entry)
	if not str(result["cause"]).is_empty():
		_die(result["cause"])
		return
	hud.toast(result["text"])
	if entry["grave"]:
		hud.toast("You are no longer in a state of grace.")
	_set_busy(false)


func _resist(entry: Dictionary) -> void:
	hud.toast(Temptation.resist(save, entry, character))
	_set_busy(false)


# Death ------------------------------------------------------------------------

func _die(cause: String) -> void:
	_dead = true
	_set_busy(true)
	Saves.kill_current(cause)
	Sound.stop_ambience()
	Sound.play_music("requiem")
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
