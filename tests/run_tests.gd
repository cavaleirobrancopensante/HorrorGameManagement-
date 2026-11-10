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
	_test_music()
	_test_two_fingers()
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
	Survival.advance(save, float(GameData.DELIVERY_MINUTES))
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
	var ketchup := StandRules.new_item("ketchup")
	hot_dog = StandRules.combine(hot_dog, ketchup, 5)
	_check(hot_dog["ketchup"], "ketchup added")
	_check(str(StandRules.combine(hot_dog, ketchup, 5)) == "It already has ketchup.", "no double ketchup")
	_check(str(StandRules.combine(bun, ketchup, 5)) == "Put the meat in first.", "sauce needs meat")
	_check(StandRules.describe(hot_dog, 5) == "hot dog with ketchup", "describe: %s" % StandRules.describe(hot_dog, 5))
	var patty := StandRules.new_item("patty")
	patty["cook"] = 500.0
	_check(StandRules.cook_state(patty, 5) == "burnt", "burns")
	var burger: Dictionary = StandRules.combine(bun, patty, 5)
	_check(burger["kind"] == "burger" and burger["burnt"], "burnt burger")
	_check(str(StandRules.combine(sausage, bun, 5)) == "", "roll onto sausage does nothing")

	var order := {"food": "hot_dog", "ketchup": true, "mustard": false, "can": true}
	_check(StandRules.give_problem(order, hot_dog, false, false) == "", "right hot dog")
	_check(StandRules.give_problem(order, burger, false, false) == "This is burnt!", "burnt refused")
	burger["burnt"] = false
	_check(StandRules.give_problem(order, burger, false, false) == "I wanted a hot dog.", "wrong food")
	_check(StandRules.give_problem(order, hot_dog, true, false) == "I already have my food.", "no second food")
	var can := StandRules.new_item("can")
	_check(StandRules.give_problem(order, can, true, false) == "", "can accepted")
	order["can"] = false
	_check(StandRules.give_problem(order, can, true, false) == "I didn't ask for a can.", "unwanted can")
	_check(StandRules.price({"food": "burger", "ketchup": false, "mustard": false, "can": true}) == GameData.BURGER_PRICE + GameData.CAN_PRICE, "burger price")
	_check(StandRules.tip(1.0, 8) > StandRules.tip(0.2, 8), "faster serving tips more")
	_check(StandRules.tip(0.0, 20) == 0, "no tip at the last second")
	_check(StandRules.spawn_interval(1, 1.0) < StandRules.spawn_interval(5, 1.0), "noon busier than the dead shift")
	_check(StandRules.eat_effect(StandRules.new_item("sausage"), 5).size() == 1, "raw meat is not eaten")
	_check(float(StandRules.eat_effect(hot_dog, 5)["hunger"]) < 0.0, "hot dogs feed you")
	_check(StandRules.order_text({"food": "burger", "ketchup": false, "mustard": true, "can": true}) == "Burger: mustard\n+ a can", "order text")


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
