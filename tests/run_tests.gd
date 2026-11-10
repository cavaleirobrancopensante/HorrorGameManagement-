extends SceneTree
## Rules and save tests. Run with:
## godot --headless --path . -s tests/run_tests.gd

var failures := 0
var saves: Node


func _initialize() -> void:
	saves = root.get_node("Saves")
	saves.base_dir = "user://test_saves"
	_clean()
	_test_random_characters()
	_test_sin_budget()
	_test_stats()
	_test_save_round_trip()
	_test_ten_independent_slots()
	_test_dead_is_dead()
	_test_damaged_file()
	_test_needs_and_time()
	_test_shop_and_deliveries()
	_test_sleep()
	_test_news()
	_test_calendar()
	_test_shifts()
	_test_mass()
	_test_stand_rules()
	_test_supplies_and_upgrades()
	_test_music()
	_test_two_fingers()
	_test_confession()
	_test_communion()
	_test_temptation()
	_test_changelog()
	_test_horror()
	_test_scripts_compile()
	_test_scare_pacing()
	_test_night()
	_test_combat_rules()
	_clean()
	print("FAILURES: %d" % failures)
	quit(1 if failures > 0 else 0)


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		printerr("FAILED: ", what)


func _clean() -> void:
	for slot in saves.SLOT_COUNT:
		saves.delete_slot(slot)


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _test_random_characters() -> void:
	var seen_temperaments := {}
	var seen_skin := {}
	for i in 500:
		var character := PlayerCharacter.new()
		character.randomize_all(_rng(i))
		_check(character.validation_error() == "", "random character %d valid: %s" % [i, character.validation_error()])
		_check(character.free_points_left() == 0, "random spends all points")
		_check(character.strengths_left() >= 0, "random stays within virtue budget")
		if character.appearance["sex"] == "woman":
			_check(character.appearance["facial"] == "none", "no facial hair on women")
		seen_temperaments[character.temperament] = true
		seen_skin[character.appearance["skin"]] = true
	_check(seen_temperaments.size() == 4, "all temperaments appear")
	_check(seen_skin.size() == 6, "all skin tones appear")


func _test_sin_budget() -> void:
	var character := PlayerCharacter.new()
	character.full_name = "Test"
	_check(not character.set_sin_level("pride", -1), "cannot start with free virtue")
	_check(character.validation_error() != "", "no struggle is rejected")
	_check(character.set_sin_level("gluttony", 2), "can struggle")
	_check(character.set_sin_level("pride", -2), "struggle pays for virtue")
	_check(not character.set_sin_level("gluttony", 1), "cannot withdraw a struggle a virtue depends on")
	_check(character.sins["gluttony"] == 2, "refused change leaves value")
	_check(character.validation_error() == "", "balanced character valid")


func _test_stats() -> void:
	var character := PlayerCharacter.new()
	character.temperament = "melancholic"
	character.set_sin_level("gluttony", 2)
	character.change_free_point("cooking", 2)
	_check(character.stat_value("cooking") == 5 + 3 + 6 + 2, "cooking stacks base, temperament, sin, points")
	_check(is_equal_approx(character.temptation_strength("gluttony"), 1.6), "besetting sin tempts 160%")
	_check(is_equal_approx(character.temptation_strength("envy"), 1.15), "inclined sin tempts 115%")
	_check(character.predominant_fault() == "gluttony", "predominant fault")
	for i in 3:
		character.change_free_point("nerve", 1)
	_check(not character.change_free_point("nerve", 1), "per-stat limit")
	character.change_free_point("charm", 1)
	_check(not character.change_free_point("devotion", 1), "total point limit")


func _test_save_round_trip() -> void:
	_clean()
	var character := PlayerCharacter.new()
	character.randomize_all(_rng(77))
	_check(saves.first_empty_slot() == 0, "first empty is 0")
	_check(saves.start_new(character, 0), "start_new writes")
	_check(saves.load_slot(0), "load_slot")
	var loaded: PlayerCharacter = saves.current_character()
	_check(JSON.stringify(loaded.to_dict(), "", true) == JSON.stringify(character.to_dict(), "", true), "character round trip")
	for def: Dictionary in GameData.STATS:
		_check(loaded.stat_value(def["id"]) == character.stat_value(def["id"]), "stat round trip")
	_check(typeof(loaded.sins["pride"]) == TYPE_INT, "sin levels return to ints")
	_check(not FileAccess.file_exists(saves.slot_path(0) + ".tmp"), "no temp file left")
	var survival: Dictionary = saves.current["survival"]
	_check(int(survival["health"]) == character.max_health(), "starts at full health")
	_check(int(survival["money"]) == character.starting_money(), "starting money from business")
	for need: Dictionary in GameData.NEEDS:
		_check(survival.has(need["id"]), "need stored: %s" % need["id"])
	_check(int(saves.current["soul"]["horror_lean"]) == 0, "horror starts balanced")


func _test_ten_independent_slots() -> void:
	_clean()
	for slot in saves.SLOT_COUNT:
		var character := PlayerCharacter.new()
		character.randomize_all(_rng(slot))
		character.full_name = "Person %d" % slot
		_check(saves.first_empty_slot() == slot, "slots fill in order")
		saves.start_new(character, slot)
		saves.current["updated"] = 0.0
	_check(saves.first_empty_slot() == -1, "ten slots full")
	saves.load_slot(4)
	saves.current["world"]["time"] = float(saves.current["world"]["time"]) + 8 * Survival.DAY
	saves.save_current()
	_check(saves.most_recent_living_slot() == 4, "continue picks last played")
	saves.load_slot(5)
	_check(int(saves.current["day"]) == 1, "other slots untouched")
	saves.load_slot(4)
	_check(int(saves.current["day"]) == 9, "day stored in own slot")
	saves.delete_slot(2)
	_check(saves.first_empty_slot() == 2, "delete frees that slot")
	_check(saves.read_slot(3)["character"]["full_name"] == "Person 3", "delete leaves neighbours")


func _test_dead_is_dead() -> void:
	_clean()
	var character := PlayerCharacter.new()
	character.randomize_all(_rng(5))
	saves.start_new(character, 0)
	_check(saves.most_recent_living_slot() == 0, "living can continue")
	_check(saves.kill_current("Test"), "kill writes")
	saves.current = {}
	saves.current_slot = -1
	_check(not saves.load_slot(0), "dead cannot load")
	_check(saves.most_recent_living_slot() == -1, "dead cannot continue")
	_check(saves.read_slot(0)["alive"] == false, "death is on disk")
	_check(saves.any_saves(), "memorial still listed")
	_check(saves.first_empty_slot() == 1, "memorial occupies slot")


func _new_save() -> Dictionary:
	var character := PlayerCharacter.new()
	character.randomize_all(_rng(9))
	var save := {"character": character.to_dict(), "day": 1}
	Survival.ensure(save)
	return save


func _test_needs_and_time() -> void:
	var save := _new_save()
	_check(Survival.clock_text(Survival.now(save)) == "20:00", "day starts at 20:00")
	_check(Survival.stock(save, "meals") == 2, "starting stock")
	var hunger := Survival.need(save, "hunger")
	_check(Survival.advance(save, 60.0) == "", "an hour passes alive")
	_check(is_equal_approx(Survival.need(save, "hunger"), hunger + 3.0), "hunger rises per hour")
	_check(Survival.clock_text(Survival.now(save)) == "21:00", "clock moves")
	Survival.advance(save, 3.0 * 60.0)
	_check(int(save["day"]) == 2, "day rolls over at midnight")
	_check(is_equal_approx(Survival.daylight(12 * 60.0), 1.0) and Survival.daylight(23 * 60.0) == 0.0, "daylight")
	save["survival"]["thirst"] = 100.0
	var cause := ""
	for i in 30:
		cause = Survival.advance(save, 60.0)
		if not cause.is_empty():
			break
	_check(cause == "Died of thirst.", "thirst kills: %s" % cause)
	_check(Survival.health(save) == 0.0, "health at zero")


func _test_shop_and_deliveries() -> void:
	var save := _new_save()
	save["survival"]["money"] = 20
	_check(Survival.order(save, "sausages") == "", "can buy")
	_check(Survival.money(save) == 8, "money taken")
	_check(Survival.order(save, "sausages") == "Not enough money.", "cannot overspend")
	_check(Survival.order(save, "buns") == "", "second order")
	_check((save["world"]["deliveries"] as Array).size() == 1, "orders share a drone")
	_check(Survival.arrived(save).is_empty(), "not yet arrived")
	Survival.advance(save, Survival.delivery_time(Survival.now(save)) - Survival.now(save))
	_check(Survival.arrived(save).size() == 1, "delivery arrives")
	var before := Survival.stock(save, "sausages")
	var got := Survival.collect(save)
	_check(int(got["sausages"]) == 10 and int(got["buns"]) == 10, "collected items")
	_check(Survival.stock(save, "sausages") == before + 10, "stock grows")
	_check((save["world"]["deliveries"] as Array).is_empty(), "delivery cleared")
	_check(Survival.take_stock(save, "candles") and not Survival.take_stock(save, "candles"), "take stock")
	# JSON turns numbers into floats; the rules must still work after a reload.
	var reloaded: Dictionary = JSON.parse_string(JSON.stringify(save))
	reloaded["survival"]["money"] = 50.0
	_check(Survival.stock(reloaded, "sausages") == before + 10, "stock after reload")
	_check(Survival.order(reloaded, "coffee") == "", "order after reload")


func _test_sleep() -> void:
	var save := _new_save()
	save["survival"]["tiredness"] = 80.0
	Survival.advance(save, 2.0 * 60.0)  # 22:00
	_check(is_equal_approx(Survival.sleep_minutes(save), 9.0 * 60.0), "sleep until 07:00")
	_check(Survival.sleep(save) == "", "sleep is safe")
	_check(Survival.clock_text(Survival.now(save)) == "07:00", "wake at 07:00")
	_check(Survival.need(save, "tiredness") < 5.0, "rested")
	_check(int(save["day"]) == 2, "next day after sleep")
	Survival.advance(save, 6.0 * 60.0)  # 13:00
	_check(is_equal_approx(Survival.sleep_minutes(save), 480.0), "nap is 8 hours")


func _test_news() -> void:
	_check(Survival.headlines(3, 0).size() == 5, "five headlines")
	_check(Survival.headlines(3, 0) == Survival.headlines(3, 0), "same day same news")
	var faithful := Survival.headlines(4, -50)
	_check(GameData.NEWS_PERSECUTION.has(faithful[0]), "faithful see persecution")
	var sinful := Survival.headlines(4, 50)
	_check(GameData.NEWS_DEMONIC.has(sinful[0]), "sinful see the strange")


func _test_calendar() -> void:
	var save := _new_save()
	var start := Survival.now(save)
	_check(Survival.date_text(start) == "Sat 15 Jan 2050", "start date: %s" % Survival.date_text(start))
	_check(Survival.date_text(start, true) == "Saturday 15 January 2050", "long date")
	_check(Survival.weekday_of_day(2) == 0, "day 2 is Sunday")
	_check(Survival.date_text(Survival.DAY * 17 + 600.0) == "Tue 1 Feb 2050", "month rolls over: %s" % Survival.date_text(Survival.DAY * 17 + 600.0))
	_check(Survival.shift_name(start) == "Evening", "20:00 is evening")
	_check(Survival.clock_text(Survival.shift_end(start)) == "22:00", "evening ends at 22:00")
	_check(Survival.shift_name(3 * 60.0) == "Dead shift", "03:00 is the dead shift")
	_check(Survival.shift_name(23 * 60.0) == "Night", "23:00 is night")
	_check(Survival.clock_text(Survival.shift_end(23 * 60.0)) == "02:00", "night ends at 02:00")
	_check(Survival.shift_name(6 * 60.0) == "Morning" and Survival.shift_name(10 * 60.0) == "Noon", "morning and noon")


func _test_shifts() -> void:
	var save := _new_save()
	var character := PlayerCharacter.from_dict(save["character"])
	var money := Survival.money(save)
	var sausages := Survival.stock(save, "sausages")
	var result := Survival.spend_shift(save, "work", character, _rng(3))
	_check(result["cause"] == "", "working is safe")
	_check(Survival.clock_text(Survival.now(save)) == "22:00", "work runs to the end of the shift")
	_check(Survival.money(save) > money, "work earns money: %s" % result["text"])
	_check(Survival.stock(save, "sausages") < sausages, "work uses stock")
	var tired := Survival.need(save, "tiredness")
	Survival.spend_shift(save, "sleep", character, _rng(3))
	_check(Survival.need(save, "tiredness") < tired, "sleeping a shift rests")
	_check(Survival.clock_text(Survival.now(save)) == "02:00", "night shift slept")
	save["world"]["stock"]["sausages"] = 0
	_check(Survival.activity_blocked(save, "work") != "", "no stock, no work")


func _test_mass() -> void:
	var save := _new_save()
	var character := PlayerCharacter.from_dict(save["character"])
	_check(Survival.mass_sunday(Survival.now(save)) == 2, "Saturday evening is the vigil")
	Survival.spend_shift(save, "mass", character, _rng(1))
	_check(Survival.attended_mass(save, 2), "vigil counts for Sunday")
	_check(Survival.activity_blocked(save, "mass") != "", "no Mass at night")
	Survival.advance(save, 2.0 * Survival.DAY)
	_check(bool(save["soul"]["state_of_grace"]), "kept the Sunday obligation")
	# A second character skips Mass.
	var lazy := _new_save()
	Survival.advance(lazy, 2.0 * Survival.DAY)
	_check(not bool(lazy["soul"]["state_of_grace"]), "missing Mass loses grace")
	_check(Survival.take_notices(lazy).size() == 1, "missed Mass notice")
	_check(Survival.take_notices(lazy).is_empty(), "notices are taken once")


func _test_stand_rules() -> void:
	var sausage := StandRules.new_item("sausage")
	var bun := StandRules.new_item("bun")
	_check(StandRules.cook_state(sausage, 5) == "raw", "starts raw")
	_check(str(StandRules.combine(bun, sausage, 5)) == "Cook it first.", "raw meat refused")
	sausage["cook"] = StandRules.COOK_SECONDS + 1.0
	_check(StandRules.cook_state(sausage, 5) == "cooked", "cooks")
	var hot_dog: Dictionary = StandRules.combine(bun, sausage, 5)
	_check(hot_dog["kind"] == "hot_dog" and not hot_dog["burnt"], "bun plus sausage is a hot dog")
	var other_way: Dictionary = StandRules.combine(sausage, bun, 5)
	_check(other_way["kind"] == "hot_dog", "roll onto cooked sausage also makes a hot dog")
	var ketchup := StandRules.new_item("ketchup")
	hot_dog = StandRules.combine(hot_dog, ketchup, 5)
	_check(hot_dog["ketchup"], "ketchup added")
	_check(str(StandRules.combine(hot_dog, ketchup, 5)) == "It already has ketchup.", "no double ketchup")
	_check(str(StandRules.combine(bun, ketchup, 5)) == "Make the hot dog or burger first.", "sauce needs food")
	var mayo := StandRules.new_item("mayo")
	var with_mayo: Dictionary = StandRules.combine(hot_dog, mayo, 5)
	_check(with_mayo["mayo"] and with_mayo["ketchup"], "mayonnaise adds to ketchup")
	_check(StandRules.describe(with_mayo, 5) == "hot dog with ketchup and mayo", "describe: %s" % StandRules.describe(with_mayo, 5))
	var patty := StandRules.new_item("patty")
	patty["cook"] = 500.0
	_check(StandRules.cook_state(patty, 5) == "burnt", "burns")
	_check(StandRules.cook_state(patty, 5, true) == "burnt", "even a pro grill burns eventually")
	var just_cooked := StandRules.new_item("patty")
	just_cooked["cook"] = StandRules.COOK_SECONDS + StandRules.burn_window(5) + 1.0
	_check(StandRules.cook_state(just_cooked, 5) == "burnt" and StandRules.cook_state(just_cooked, 5, true) == "cooked", "pro grill forgives longer")
	var burger: Dictionary = StandRules.combine(bun, patty, 5)
	_check(burger["kind"] == "burger" and burger["burnt"], "burnt burger")
	# Dirt and odd places carry into what you make.
	var dirty_bun := StandRules.new_item("bun")
	dirty_bun["dirty"] = true
	var dirty_dog: Dictionary = StandRules.combine(dirty_bun, sausage, 5)
	_check(dirty_dog["dirty"], "a dirty roll makes a dirty hot dog")

	var order := {"food": "hot_dog", "ketchup": true, "mustard": false, "mayo": false, "can": true}
	_check(StandRules.give_problem(order, hot_dog, false, false) == "", "right hot dog")
	_check(StandRules.give_problem(order, with_mayo, false, false) == "That's not what I asked for.", "unwanted mayo")
	_check(StandRules.give_problem(order, burger, false, false) == "This is burnt!", "burnt refused")
	var floor_dog := hot_dog.duplicate()
	floor_dog["dirty"] = true
	_check(StandRules.give_problem(order, floor_dog, false, false) == "That's filthy. I'm not touching it.", "dirty refused outright")
	burger["burnt"] = false
	_check(StandRules.give_problem(order, burger, false, false) == "I wanted a hot dog.", "wrong food")
	_check(StandRules.give_problem(order, hot_dog, true, false) == "I already have my food.", "no second food")
	var can := StandRules.new_item("can")
	_check(StandRules.give_problem(order, can, true, false) == "", "can accepted")
	order["can"] = false
	_check(StandRules.give_problem(order, can, true, false) == "I didn't ask for a can.", "unwanted can")
	_check(StandRules.price({"food": "burger", "ketchup": false, "mustard": false, "mayo": false, "can": true}) == GameData.BURGER_PRICE + GameData.CAN_PRICE, "burger price")
	_check(StandRules.spawn_interval(1, 1.0) < StandRules.spawn_interval(5, 1.0), "noon busier than the dead shift")
	_check(StandRules.spawn_interval(1, 1.0, true) < StandRules.spawn_interval(1, 1.0), "neon brings more customers")
	_check(StandRules.eat_effect(StandRules.new_item("sausage"), 5).size() == 1, "raw meat is not eaten")
	_check(float(StandRules.eat_effect(hot_dog, 5)["hunger"]) < 0.0, "hot dogs feed you")
	_check(StandRules.order_text({"food": "burger", "ketchup": false, "mustard": true, "mayo": true, "can": true}) == "Burger: mustard, mayo\n+ a can", "order text")
	_check(StandRules.bottle_size(true) > StandRules.bottle_size(false), "large bottles hold more")

	# Mood and tips.
	_check(StandRules.face(90.0) == "happy" and StandRules.face(45.0) == "neutral" and StandRules.face(10.0) == "angry", "faces")
	_check(StandRules.tip(95.0, 8) > StandRules.tip(50.0, 8), "happier customers tip more")
	_check(StandRules.tip(10.0, 20) == 0, "angry customers tip nothing")
	_check(StandRules.mood_decay(5, true) < StandRules.mood_decay(5, false), "the TV keeps them patient")

	# Out of stock: they settle for something else, or leave.
	var wants := {"food": "burger", "ketchup": false, "mustard": false, "mayo": true, "can": true}
	var stocked := {"hot_dog": true, "burger": true, "ketchup": true, "mustard": true, "mayo": true, "can": true}
	_check(StandRules.missing(wants, stocked).is_empty(), "nothing missing")
	var short := stocked.duplicate()
	short["burger"] = false
	short["mayo"] = false
	_check(StandRules.missing(wants, short).size() == 2, "missing burgers and mayo")
	var settled := StandRules.substitute(wants, short)
	_check(settled["food"] == "hot_dog" and not settled["mayo"] and settled["can"], "settles for a hot dog without mayo")
	short["hot_dog"] = false
	_check(StandRules.substitute(wants, short).is_empty(), "nothing to eat: they leave")

	# Hints name the next step.
	var raw := StandRules.new_item("sausage")
	_check(StandRules.hint(raw, [], 5)["id"] == "grill", "raw meat: grill it")
	_check(StandRules.hint(sausage, [], 5)["id"] == "assemble", "cooked meat: into a roll")
	_check(StandRules.hint(hot_dog, [order], 5)["id"] == "serve", "finished order: serve it")
	var plain_dog: Dictionary = StandRules.combine(bun, sausage, 5)
	_check(StandRules.hint(plain_dog, [order], 5)["id"] == "sauce", "needs ketchup: sauce it")
	_check(StandRules.hint(floor_dog, [order], 5)["id"] == "bin", "dirty: bin it")


func _test_supplies_and_upgrades() -> void:
	var save := _new_save()
	save["survival"]["money"] = 500
	# Deliveries land at the start of the shift after next.
	var now := Survival.now(save)
	_check(Survival.delivery_time(now) - now > Survival.SHIFT_MINUTES, "deliveries take more than a shift")
	_check(Survival.delivery_time(now) - now <= 2.0 * Survival.SHIFT_MINUTES, "and at most two")
	_check(Survival.stock(save, "mayo") > 0 and Survival.stock(save, "cleaner") > 0, "start with refills and spray")
	_check(Survival.order(save, "tv") == "", "buy the TV")
	_check(Survival.order(save, "tv") == "You already have that.", "only one TV")
	_check(not Survival.has_upgrade(save, "tv"), "not installed before it lands")
	Survival.advance(save, Survival.delivery_time(Survival.now(save)) - Survival.now(save))
	Survival.collect(save)
	_check(Survival.has_upgrade(save, "tv"), "installed when carried in")
	_check(Survival.stock(save, "tv") == 0, "an upgrade is not stock")
	# Old saves get the new supplies.
	var old := _new_save()
	(old["world"]["stock"] as Dictionary).erase("mayo")
	(old["world"] as Dictionary).erase("upgrades")
	(old["world"] as Dictionary).erase("learned")
	Survival.ensure(old)
	_check(Survival.stock(old, "mayo") > 0 and old["world"]["upgrades"] is Dictionary and old["world"]["learned"] is Dictionary, "old saves upgraded")


func _test_music() -> void:
	var sound: Node = root.get_node("Sound")
	for id: String in sound.MUSIC:
		_check(ResourceLoader.exists(sound.MUSIC[id]), "music piece exists: %s" % id)
		_check(sound.TITLES.has(id), "music piece has a title: %s" % id)
	for piece in ["night_shift", "outside", "overcast", "sunday", "menu", "requiem"]:
		_check(sound.MUSIC.has(piece), "game asks for an existing piece: %s" % piece)


func _touch(controls: Variant, finger: int, at: Vector2, down: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = finger
	event.position = at
	event.pressed = down
	controls._input(event)


func _drag(controls: Variant, finger: int, at: Vector2, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = finger
	event.position = at
	event.relative = relative
	controls._input(event)


## Walking with one thumb while looking with another finger: the look must follow
## only its own finger, even when the two fingers' events interleave.
func _test_two_fingers() -> void:
	# Loaded at run time: these scripts use the Sound autoload, which only exists once the tree is up.
	var player: Variant = load("res://scripts/world/player.gd").new()
	var controls: Variant = load("res://scripts/ui/touch_controls.gd").new()
	var look_speed: float = controls.LOOK_SPEED
	controls.player = player
	controls.size = Vector2(1280, 720)
	_touch(controls, 0, Vector2(200, 560), true)
	_drag(controls, 0, Vector2(200, 500), Vector2(0, -60))
	_check(player.move_input.y < -0.5, "the stick walks")
	_touch(controls, 1, Vector2(900, 400), true)
	var start: float = player.rotation.y
	for k in range(1, 11):
		# Wrong "relative" values, as the web build sends them, must not matter.
		_drag(controls, 0, Vector2(203, 500), Vector2(-697, 100))
		_drag(controls, 1, Vector2(900 - k * 10, 400), Vector2(697, -100))
	var turned: float = player.rotation.y - start
	_check(is_equal_approx(turned, 100.0 * look_speed), "the look follows its own finger: %f" % turned)
	_check(player.move_input.y < -0.5, "still walking while looking")
	_touch(controls, 1, Vector2(800, 400), false)
	_touch(controls, 2, Vector2(900, 300), true)
	start = player.rotation.y
	_drag(controls, 2, Vector2(880, 300), Vector2.ZERO)
	_check(is_equal_approx(player.rotation.y - start, 20.0 * look_speed), "a new finger looks again")
	_touch(controls, 0, Vector2(203, 500), false)
	_check(player.move_input == Vector2.ZERO, "lifting the thumb stops walking")
	# A lost release: the next finger on the right still takes the look.
	_touch(controls, 7, Vector2(900, 300), true)
	start = player.rotation.y
	_drag(controls, 7, Vector2(910, 300), Vector2.ZERO)
	_check(not is_equal_approx(player.rotation.y, start), "a lost release does not block looking")
	controls.free()
	player.free()


func _test_damaged_file() -> void:
	_clean()
	DirAccess.make_dir_recursive_absolute(saves.base_dir)
	var file := FileAccess.open(saves.slot_path(3), FileAccess.WRITE)
	file.store_string("{ not json")
	file.close()
	_check(saves.read_slot(3).has("damaged"), "damaged detected")
	_check(not saves.load_slot(3), "damaged cannot load")
	_check(saves.most_recent_living_slot() == -1, "damaged cannot continue")


func _test_confession() -> void:
	var save := _new_save()
	_check(Soul.in_grace(save), "new soul in grace")
	_check(Soul.sins(save).is_empty(), "new soul has no sins on record")
	Soul.record(save, "gluttony", "Gluttony: two hot dogs.", false, 1)
	_check(Soul.in_grace(save), "a venial sin keeps grace")
	Soul.record(save, "envy", "Envy: reported a rival.", true, 4)
	_check(not Soul.in_grace(save), "a grave sin costs grace")
	var lines := Soul.examination(save)
	_check(lines.size() == 2 and lines[0].begins_with("Grave:"), "examination lists grave sins first")
	# Holding back a grave sin: nothing is forgiven, and it adds sacrilege.
	var lean := int(save["soul"]["horror_lean"])
	Soul.confess(save, false)
	_check(not Soul.in_grace(save), "bad confession does not restore grace")
	_check(Soul.sins(save).size() == 3, "bad confession adds sacrilege to the record")
	_check(int(save["soul"]["horror_lean"]) > lean, "bad confession pushes toward the demonic")
	# A full confession clears everything.
	Soul.confess(save, true)
	_check(Soul.in_grace(save), "full confession restores grace")
	_check(Soul.sins(save).is_empty(), "full confession clears the record")
	_check(bool(save["soul"]["penance"]), "confession gives a penance")
	_check(Soul.fortified(save, int(save["day"])), "fortified on the day of confession")
	_check(Soul.do_penance(save), "prayer completes the penance")
	_check(not Soul.do_penance(save), "penance only once")
	# Missing Sunday Mass goes on the record. Day 1 is Saturday; skip to Monday.
	Survival.advance(save, Survival.DAY * 2.0)
	_check(not Soul.in_grace(save), "missing Mass costs grace")
	_check(Soul.has_grave(save), "missed Mass is on the record")
	# Hours: evenings every day, Saturday afternoon too.
	var saturday_afternoon := float(Survival.FIRST_SHIFT_MINUTE + 2 * 240 + 30)
	_check(Soul.confession_open(saturday_afternoon), "confession on Saturday afternoon")
	_check(not Soul.confession_open(saturday_afternoon + Survival.DAY * 2.0), "no confession Monday afternoon")
	_check(Soul.confession_open(saturday_afternoon + Survival.DAY * 2.0 + 240.0), "confession Monday evening")
	_check(not Soul.church_open(saturday_afternoon + 600.0), "church locked at night")


func _test_communion() -> void:
	var save := _new_save()
	var stress := Survival.need(save, "stress")
	Soul.receive_communion(save)
	_check(Soul.fortified(save, int(save["day"])), "Communion fortifies for the day")
	_check(Soul.sins(save).is_empty(), "Communion in grace adds no sin")
	Soul.record(save, "lust", "Lust.", true, 4)
	Soul.receive_communion(save)
	_check(Soul.sins(save).size() == 2, "Communion in mortal sin is a sacrilege")
	Soul.spiritual_communion(save)
	_check(Soul.sins(save).size() == 2, "spiritual communion adds nothing")
	_check(stress >= 0.0, "stress stays valid")


func _test_temptation() -> void:
	var save := _new_save()
	var character := PlayerCharacter.from_dict(save["character"])
	_check(Temptation.LIST.size() >= 7, "a temptation for each sin")
	var covered := {}
	for entry: Dictionary in Temptation.LIST:
		covered[entry["sin"]] = true
		_check(not GameData.sin_def(entry["sin"]).is_empty(), "temptation %s has a real sin" % entry["id"])
	_check(covered.size() == GameData.SINS.size(), "every capital sin tempts")
	# Temptations are personal, never an attack on the faith.
	for entry: Dictionary in Temptation.LIST:
		var words := (str(entry["text"]) + " " + str(entry["give"]) + " " + str(entry["give_text"])).to_lower()
		for banned: String in Temptation.FAITH_WORDS:
			_check(not (" " + banned) in (" " + words.replace(".", " ").replace(",", " ")), "temptation %s keeps the faith out of it: %s" % [entry["id"], banned])
	# Stress makes temptation likelier.
	Survival.change_need(save, "stress", -100.0)
	var calm := Temptation.chance_per_hour(save)
	Survival.change_need(save, "stress", 100.0)
	_check(Temptation.chance_per_hour(save) > calm * 3.0, "stress multiplies temptation")
	# Hatch-only temptations wait for the hatch.
	save["world"]["hatch_open"] = false
	_check(not Temptation.available(save, Temptation.def("change")), "no customer temptation with the hatch shut")
	save["world"]["hatch_open"] = true
	_check(Temptation.available(save, Temptation.def("change")), "customer temptation with the hatch open")
	# One per shift at most.
	var rng := _rng(3)
	var first := {}
	for i in 200:
		first = Temptation.roll(save, character, rng, 1.0)
		if not first.is_empty():
			break
	_check(not first.is_empty(), "temptation comes when stressed")
	_check(Temptation.roll(save, character, rng, 50.0).is_empty(), "only one temptation per shift")
	# Giving in pays and stains; resisting costs stress.
	var money := Survival.money(save)
	var result := Temptation.give_in(save, Temptation.def("report"))
	_check(Survival.money(save) == money + 15, "giving in pays")
	_check(not Soul.in_grace(save), "grave temptation costs grace")
	_check(str(result["cause"]).is_empty(), "giving in does not kill")
	Survival.change_need(save, "stress", -100.0)
	Temptation.resist(save, Temptation.def("change"), character)
	var cost := Survival.need(save, "stress")
	_check(cost > 0.0, "resisting costs stress")
	# Struggling with a sin makes resisting it harder; Communion halves it.
	var weak := PlayerCharacter.from_dict(save["character"])
	var strong := PlayerCharacter.from_dict(save["character"])
	weak.sins["greed"] = 2
	strong.sins["greed"] = -2
	var entry := Temptation.def("change")
	_check(Temptation.resist_cost(save, entry, weak) > Temptation.resist_cost(save, entry, strong), "besetting sin costs more to resist")
	var before := Temptation.resist_cost(save, entry, weak)
	Soul.confess(save, true)
	_check(Temptation.resist_cost(save, entry, weak) < before, "fortified resists for less")


func _test_changelog() -> void:
	_check(Changelog.version() == str(ProjectSettings.get_setting("application/config/version")), "menu version matches project.godot")
	var seen := {}
	for patch: Dictionary in Changelog.PATCHES:
		_check(not seen.has(patch["version"]), "patch versions unique")
		seen[patch["version"]] = true
		_check((patch["changes"] as Array).size() > 0, "patch %s lists changes" % patch["version"])


func _test_horror() -> void:
	var save := _new_save()
	_check(save["horror"] is Dictionary, "saves carry horror state")
	# Calm, faithful-neutral, daytime: weak.
	save["soul"]["horror_lean"] = 0
	save["survival"]["stress"] = 0.0
	save["world"]["time"] = Survival.now(save) - fmod(Survival.now(save), Survival.DAY) + 12 * 60.0
	var calm := Horror.intensity(save)
	_check(calm < 0.1, "calm noon is quiet: %f" % calm)
	# Leaning far toward sin, stressed, at night: strong, and demonic.
	save["soul"]["horror_lean"] = 45
	save["survival"]["stress"] = 80.0
	save["world"]["time"] = float(save["world"]["time"]) + 14 * 60.0
	_check(Horror.is_night(Survival.now(save)), "2am is night")
	_check(Horror.intensity(save) > 0.8, "sin, stress and night: strong")
	_check(Horror.demonic_weight(save) > 0.9, "sin brings the demonic")
	_check(Horror.chance(save) > Horror.CHANCE_MIN * 4.0, "strong horror comes often")
	save["soul"]["horror_lean"] = -45
	_check(Horror.demonic_weight(save) < 0.1, "faithfulness brings the state")
	save["soul"]["horror_lean"] = 0
	_check(is_equal_approx(Horror.demonic_weight(save), 0.5), "in between, both")
	# Rules for when events can happen.
	save["soul"]["horror_lean"] = 45
	var context := {"in_church": false, "near_mirror": false, "hatch_open": false, "customers": false}
	_check(not Horror.available(save, Horror.def("mirror"), context), "mirror needs the mirror")
	context["near_mirror"] = true
	save["horror"]["dread"] = Horror.DREAD_NEEDED
	save["world"]["time"] = float(save["world"]["time"]) + Survival.DAY
	_check(Horror.available(save, Horror.def("mirror"), context), "near the mirror")
	_check(not Horror.available(save, Horror.def("smile"), context), "a smiling customer needs customers")
	_check(not Horror.available(save, Horror.def("inspector"), context), "no inspector at night")
	context["in_church"] = true
	_check(not Horror.available(save, Horror.def("whisper"), context), "nothing follows you into the church")
	_check(Horror.roll(save, _rng(1), context).is_empty(), "the church is safe")
	context["in_church"] = false
	# Cooldowns.
	Horror.apply(save, Horror.def("whisper"))
	_check(not Horror.available(save, Horror.def("whisper"), context), "whisper cools down")
	Survival.advance(save, 4 * 60.0)
	_check(Horror.available(save, Horror.def("whisper"), context), "whisper can come back")
	# Rolls happen when strong.
	var rng := _rng(5)
	var happened := 0
	for i in 200:
		if not Horror.roll(save, rng, context).is_empty():
			happened += 1
	_check(happened > 10, "a strong director acts: %d" % happened)
	# Effects.
	var money := Survival.money(save)
	Horror.apply(save, Horror.def("tax"))
	_check(Survival.money(save) == money - 12, "the surcharge takes money")
	Horror.apply(save, Horror.def("feeds_seized"))
	_check(Horror.feeds_off(save), "feeds seized")
	Survival.advance(save, Survival.SHIFT_MINUTES + 1.0)
	_check(not Horror.feeds_off(save), "feeds back after the shift")
	save["world"]["hatch_open"] = true
	save["world"]["dirt"]["serving"] = 0.9
	money = Survival.money(save)
	var report := Horror.apply(save, Horror.def("inspector"))
	_check(Survival.money(save) == money - 20 and not bool(save["world"]["hatch_open"]), "inspector fines more for filth and shuts the hatch")
	_check(report.contains("counters"), "inspector mentions the counters")
	save["world"]["stock"]["candles"] = 3
	save["world"]["stock"]["sausages"] = 10
	var health := Survival.health(save)
	Horror.apply(save, Horror.def("raid"))
	_check(Survival.stock(save, "candles") == 0 and Survival.stock(save, "sausages") == 5, "raid takes candles and half the meat")
	_check(Survival.health(save) < health, "raid hurts")


## Every script compiles, including the ones the tests never run.
func _test_scripts_compile() -> void:
	for folder in ["res://scripts/core", "res://scripts/world", "res://scripts/ui", "res://scripts/screens", "res://scripts/autoload"]:
		for file in DirAccess.get_files_at(folder):
			if not file.ends_with(".gd"):
				continue
			var script: GDScript = load(folder + "/" + file)
			_check(script != null and script.can_instantiate(), "compiles: %s/%s" % [folder, file])


## Big scares grow out of small ones, are spread out, and are not regular.
func _test_scare_pacing() -> void:
	var save := _new_save()
	var context := {"in_church": false, "near_mirror": true, "hatch_open": false, "customers": false, "shutters_closed": false}
	_check(not Horror.big_ready(save), "nothing big on the first day")
	# Worst case: far toward sin, stressed, play through 30 days.
	var rng := _rng(11)
	var faces: Array = []
	var bigs: Array = []
	var smalls := 0
	for step in int(30 * Survival.DAY / Horror.ROLL_MINUTES):
		save["soul"]["horror_lean"] = 50
		save["survival"]["stress"] = 85.0
		Survival.advance(save, Horror.ROLL_MINUTES)
		save["survival"]["health"] = 100.0
		save["survival"]["hunger"] = 0.0
		save["survival"]["thirst"] = 0.0
		save["survival"]["tiredness"] = 0.0
		var event := Horror.roll(save, rng, context)
		if event.is_empty():
			continue
		Horror.apply(save, event, 0, rng)
		if event["id"] == "jumpscare":
			faces.append(Survival.now(save))
		if event.get("big", false):
			bigs.append(Survival.now(save))
		else:
			smalls += 1
	print("pacing: faces %d, big %d, small %d" % [faces.size(), bigs.size(), smalls])
	_check(faces.size() >= 3 and faces.size() <= 15, "faces over 30 worst-case days: %d" % faces.size())
	_check(bigs.size() <= 30, "at most about one big scare a day: %d" % bigs.size())
	_check(smalls > bigs.size() * 2, "small scares outnumber big ones: %d to %d" % [smalls, bigs.size()])
	var gaps: Array = []
	for i in range(1, faces.size()):
		var gap: float = (faces[i] - faces[i - 1]) / Survival.DAY
		gaps.append(gap)
		_check(gap >= 1.7, "faces at least ~2 days apart: %.2f" % gap)
	if gaps.size() >= 2:
		_check(absf(gaps.max() - gaps.min()) > 0.5, "faces are not on a schedule")
	# A calm soul in daylight barely sees anything.
	var calm := _new_save()
	var quiet := 0
	for step in int(10 * Survival.DAY / Horror.ROLL_MINUTES):
		Survival.advance(calm, Horror.ROLL_MINUTES)
		calm["survival"]["health"] = 100.0
		calm["survival"]["hunger"] = 0.0
		calm["survival"]["thirst"] = 0.0
		calm["survival"]["tiredness"] = 0.0
		calm["survival"]["stress"] = 0.0
		calm["soul"]["horror_lean"] = 0
		var event := Horror.roll(calm, rng, context)
		if not event.is_empty():
			Horror.apply(calm, event, 0, rng)
			if event.get("big", false):
				quiet += 1
	_check(quiet == 0, "no big scares for a calm, balanced soul: %d" % quiet)
	_check(Horror.scare_stress({"stress": 20.0}, 10) < Horror.scare_stress({"stress": 20.0}, 0), "nerve softens scares")


func _test_night() -> void:
	var save := _new_save()
	save["survival"]["money"] = 200
	_check(Horror.burglar_chance(save, true) < Horror.burglar_chance(save, false) * 0.5, "shutters keep most burglars out")
	save["survival"]["money"] = 0
	var poor := Horror.burglar_chance(save, false)
	save["survival"]["money"] = 300
	_check(Horror.burglar_chance(save, false) > poor, "cash draws burglars")
	_check(Horror.fight_chance(10, 10) > Horror.fight_chance(1, 1), "endurance and vigilance help in a fight")
	# Letting him take it costs money but not health.
	var health := Survival.health(save)
	Horror.let_burglar(save, _rng(2))
	_check(Survival.money(save) < 300 and Survival.health(save) == health, "doing nothing costs money")
	# Fights: sometimes won, sometimes lost and hurt.
	var won := 0
	var hurt := 0
	for i in 60:
		var s := _new_save()
		s["survival"]["money"] = 100
		var result := Horror.fight_burglar(s, 5, 5, _rng(100 + i))
		if result["won"]:
			won += 1
			_check(Survival.money(s) == 100, "winning keeps your money")
		elif Survival.health(s) < Survival.max_health(s) - 15.0:
			hurt += 1
	_check(won > 10 and hurt > 10, "fights go both ways: won %d, hurt %d" % [won, hurt])
	# Burglars do not come every night.
	var nights := _new_save()
	nights["survival"]["money"] = 150
	var rng := _rng(9)
	var burglaries := 0
	for night in 60:
		var result := Horror.night(nights, rng, false, 480.0)
		if result.get("id", "") == "burglar":
			burglaries += 1
		Survival.advance(nights, Survival.DAY)
		nights["survival"]["health"] = 100.0
		nights["survival"]["hunger"] = 0.0
		nights["survival"]["thirst"] = 0.0
		nights["survival"]["tiredness"] = 0.0
	_check(burglaries >= 2 and burglaries <= 16, "burglaries over 60 nights: %d" % burglaries)
	# The waking only comes to those leaning toward sin.
	var faithful := _new_save()
	faithful["soul"]["horror_lean"] = -40
	Survival.advance(faithful, 2 * Survival.DAY)
	faithful["horror"]["dread"] = 5
	var wakings := 0
	for i in 50:
		if Horror.night(faithful, rng, true, 480.0).get("id", "") == "paralysis":
			wakings += 1
	_check(wakings == 0, "no demonic waking for the faithful")


func _test_combat_rules() -> void:
	var save := _new_save()
	_check(Combat.next("") == "bat" and Combat.next("bat") == "slingshot" and Combat.next("slingshot") == "", "weapon cycle")
	var crack := PlayerCharacter.from_dict(save["character"])
	var poor := PlayerCharacter.from_dict(save["character"])
	crack.free_points["marksmanship"] = 8
	poor.free_points["marksmanship"] = 0
	_check(Combat.spread(crack) < Combat.spread(poor), "marksmanship tightens the slingshot")
	_check(Combat.damage("slingshot", crack) > Combat.damage("slingshot", poor), "marksmanship hits harder")
	_check(Combat.aim_spread(crack, 90.0) > Combat.aim_spread(crack, 0.0), "stress shakes your aim")
	var strong := PlayerCharacter.from_dict(save["character"])
	strong.free_points["endurance"] = 8
	poor.free_points["endurance"] = 0
	_check(Combat.damage("bat", strong) > Combat.damage("bat", poor), "endurance swings harder")
	_check(Combat.taken(10.0, strong) < Combat.taken(10.0, poor), "endurance takes it better")
	_check(Survival.stock(save, "shot") > 0 and Survival.stock(save, "bandages") > 0, "start with shot and bandages")
	_check("shooter" in Combat.RANGED and "drone" in Combat.RANGED and not "thug" in Combat.RANGED, "who can hurt you from range")
	# Gangs: night only, not in the first two days, with some shooters.
	var rng := _rng(4)
	_check(Combat.roll_gang(save, rng) == 0, "no gang on the first night")
	var later := _new_save()
	later["survival"]["money"] = 300
	later["world"]["time"] = float(later["world"]["time"]) + 3 * Survival.DAY + 6 * 60.0
	var gangs := 0
	for i in 400:
		later["horror"]["next_gang"] = 0.0
		if Combat.roll_gang(later, rng) > 0:
			gangs += 1
	_check(gangs > 10 and gangs < 120, "gangs come some nights: %d of 400" % gangs)
	var members := Combat.gang_members(5, _rng(1))
	_check(members[0] == "thug" and members.size() == 5, "a gang always has someone to break in")
	# The state: hunts for the faithful, stopped by paying.
	var faithful := _new_save()
	faithful["soul"]["horror_lean"] = -50
	faithful["survival"]["stress"] = 60.0
	faithful["world"]["time"] = float(faithful["world"]["time"]) + 3 * Survival.DAY + 6 * 60.0
	var hunts := 0
	for i in 400:
		faithful["horror"]["next_hunt"] = 0.0
		if Combat.roll_hunt(faithful, rng) > 0:
			hunts += 1
	_check(hunts > 5, "drones hunt the faithful: %d of 400" % hunts)
	var sinner := _new_save()
	sinner["soul"]["horror_lean"] = 40
	sinner["world"]["time"] = float(sinner["world"]["time"]) + 3 * Survival.DAY
	var none := 0
	for i in 200:
		sinner["horror"]["next_hunt"] = 0.0
		none += Combat.roll_hunt(sinner, rng)
	_check(none == 0, "the state does not hunt sinners")
	faithful["survival"]["money"] = 500
	var price := Combat.compliance_price(faithful)
	_check(price > Combat.compliance_price(sinner), "the faithful pay more to be left alone")
	_check(Combat.pay_compliance(faithful) == "" and Survival.money(faithful) == 500 - price, "pay the contribution")
	_check(Combat.compliant(faithful), "left alone after paying")
	var quiet := 0
	for i in 400:
		faithful["horror"]["next_hunt"] = 0.0
		quiet += Combat.roll_hunt(faithful, rng)
	_check(quiet == 0, "no drone hunts while compliant")
	var context := {"in_church": false, "near_mirror": false, "hatch_open": true, "customers": true, "shutters_closed": false}
	var state_events := 0
	for i in 400:
		var event := Horror.roll(faithful, rng, context)
		if not event.is_empty() and event["side"] == "state":
			state_events += 1
	_check(state_events == 0, "no state events while compliant")
	Survival.advance(faithful, Combat.COMPLIANCE_DAYS * Survival.DAY + 10.0)
	_check(not Combat.compliant(faithful), "compliance runs out")
