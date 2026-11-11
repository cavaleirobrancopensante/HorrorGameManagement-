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
	_test_struggles()
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
	_test_moments()
	_test_virtue_habits()
	_test_parish()
	_test_life()
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
		_check(character.struggles.size() >= 1 and character.struggles.size() <= GameData.MAX_STRUGGLES, "one or two struggles")
		_check(not character.struggles.has(character.gift()), "the gift is never a struggle")
		if character.appearance["sex"] == "woman":
			_check(character.appearance["facial"] == "none", "no facial hair on women")
		seen_temperaments[character.temperament] = true
		seen_skin[character.appearance["skin"]] = true
	_check(seen_temperaments.size() == 4, "all temperaments appear")
	_check(seen_skin.size() == 6, "all skin tones appear")


func _test_struggles() -> void:
	var character := PlayerCharacter.new()
	character.full_name = "Test"
	character.temperament = "choleric"
	_check(character.validation_error() != "", "no struggle is rejected")
	_check(not character.toggle_struggle("fortitude"), "the gift cannot be a struggle")
	_check(character.toggle_struggle("patience"), "can mark a struggle")
	_check(character.toggle_struggle("charity"), "can mark a second")
	_check(not character.toggle_struggle("justice"), "not a third")
	_check(character.validation_error() == "", "a character with struggles is valid")
	_check(character.toggle_struggle("charity") and character.struggles == ["patience"], "a struggle can be unmarked")
	var start := character.starting_virtues()
	_check(start["patience"] == 0.0 and start["fortitude"] > start["justice"], "struggles start at nothing, the gift ahead")
	# A struggle gives no bonus of any kind.
	var plain := PlayerCharacter.new()
	plain.temperament = "choleric"
	for def: Dictionary in GameData.STATS:
		_check(plain.stat_value(def["id"]) == character.stat_value(def["id"]), "struggles change no stat: %s" % def["id"])
	# Old saves with sins become struggles.
	var old := PlayerCharacter.from_dict({"full_name": "Old", "temperament": "sanguine", "sins": {"anger": 2, "greed": 1, "pride": -1}})
	_check(old.struggles == ["patience", "justice"] or old.struggles == ["justice", "patience"], "old sins become struggles: %s" % str(old.struggles))


func _test_stats() -> void:
	var character := PlayerCharacter.new()
	character.temperament = "melancholic"
	character.change_free_point("cooking", 2)
	_check(character.stat_value("cooking") == 5 + 3 + 2, "cooking stacks base, temperament, points")
	for i in 3:
		character.change_free_point("nerve", 1)
	_check(not character.change_free_point("nerve", 1), "per-stat limit")
	character.change_free_point("charm", 1)
	_check(not character.change_free_point("vigilance", 1), "total point limit")
	_check(GameData.stat_def("devotion").is_empty(), "prayer is not a stat")


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
	_check(loaded.struggles == character.struggles, "struggles round trip")
	_check(not FileAccess.file_exists(saves.slot_path(0) + ".tmp"), "no temp file left")
	var survival: Dictionary = saves.current["survival"]
	_check(int(survival["health"]) == character.max_health(), "starts at full health")
	_check(int(survival["money"]) == character.starting_money(), "starting money from business")
	for need: Dictionary in GameData.NEEDS:
		_check(survival.has(need["id"]), "need stored: %s" % need["id"])
	_check(saves.current["virtues"] is Dictionary and saves.current["virtues"].size() == GameData.VIRTUES.size(), "virtues start in the save")
	_check(Life.age(saves.current) == character.start_age(), "age from the look: %d" % Life.age(saves.current))
	_check(not saves.current["soul"].has("state_of_grace"), "no state-of-grace meter")


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
	_check(is_equal_approx(Survival.need(save, "hunger"), hunger + 3.0 * Virtue.need_rate(save)), "hunger rises per hour, a little slower with temperance")
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
	_check(Survival.headlines(3, 0.0).size() == 5, "five headlines")
	_check(Survival.headlines(3, 0.0) == Survival.headlines(3, 0.0), "same day same news")
	var watched := Survival.headlines(4, 0.6)
	var count := 0
	for line in watched:
		if GameData.NEWS_PERSECUTION.has(line):
			count += 1
	_check(count == 2, "the watched read more about the persecution")


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
	var attention := Horror.attention(save)
	Survival.spend_shift(save, "mass", character, _rng(1))
	_check(Survival.attended_mass(save, 2), "vigil counts for Sunday")
	_check(Horror.attention(save) > attention, "Mass is seen by the state")
	_check(Survival.activity_blocked(save, "mass") != "", "no Mass at night")
	Survival.take_notices(save)
	Survival.advance(save, 2.0 * Survival.DAY)
	_check(Virtue.regrets(save).is_empty(), "kept Sunday: nothing to regret")
	# A second character misses Mass: a regret, not a meter.
	var lazy := _new_save()
	Survival.advance(lazy, 2.0 * Survival.DAY)
	_check(Virtue.regrets(lazy).size() == 1, "missing Mass is a regret")
	var notices := Survival.take_notices(lazy)
	_check(notices.size() >= 1, "missed Mass notice")
	_check(Survival.take_notices(lazy).is_empty(), "notices are taken once")
	# No priest, no Mass: nothing to regret.
	var held := _new_save()
	held["parish"]["priest_back"] = Survival.now(held) + 30.0 * Survival.DAY
	Survival.spend_shift(held, "mass", PlayerCharacter.from_dict(held["character"]), _rng(1))
	_check(not Survival.attended_mass(held, 2), "no Mass without a priest")
	Survival.advance(held, 2.0 * Survival.DAY)
	_check(Virtue.regrets(held).is_empty(), "no regret when there was no Mass to go to")


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
	_check(Soul.examination(save).is_empty(), "nothing carried at first")
	Virtue.fail(save, "patience", "You shouted at the drunk.")
	Virtue.fail(save, "charity", "You sent the boy away.")
	_check(Soul.examination(save).size() == 2, "regrets are what you bring")
	var stress := Survival.need(save, "stress")
	var money := Survival.money(save)
	var virtues: Dictionary = save["virtues"].duplicate()
	var text := Soul.confess(save)
	_check(Virtue.regrets(save).is_empty(), "confession lays every regret down")
	_check(text.contains("absolves"), "absolution")
	_check(Survival.need(save, "stress") == stress and Survival.money(save) == money, "no meters move: mercy, not a reset")
	_check(save["virtues"] == virtues, "confession is not a virtue buff")
	_check(not save["soul"].has("penance"), "no penance counter")
	_check(not Soul.confess(save).is_empty(), "confession with nothing to tell is welcomed too")
	# Hours: evenings every day, Saturday afternoon too; not without a priest.
	var saturday_afternoon := float(Survival.FIRST_SHIFT_MINUTE + 2 * 240 + 30)
	_check(Soul.confession_open(save, saturday_afternoon), "confession on Saturday afternoon")
	_check(not Soul.confession_open(save, saturday_afternoon + Survival.DAY * 2.0), "no confession Monday afternoon")
	_check(Soul.confession_open(save, saturday_afternoon + Survival.DAY * 2.0 + 240.0), "confession Monday evening")
	_check(not Soul.church_open(save, saturday_afternoon + 600.0), "church locked at night")
	save["parish"]["priest_back"] = Survival.now(save) + 100.0 * Survival.DAY
	_check(not Soul.confession_open(save, saturday_afternoon + Survival.DAY * 2.0 + 240.0), "no confession while the priest is held")


func _test_communion() -> void:
	var save := _new_save()
	var before := JSON.stringify(save)
	_check(not Soul.communion_text(true).is_empty() and not Soul.communion_text(false).is_empty(), "communion is a quiet scene")
	_check(JSON.stringify(save) == before, "communion changes no numbers")


func _test_moments() -> void:
	var save := _new_save()
	var character := PlayerCharacter.from_dict(save["character"])
	_check(Moments.LIST.size() >= 10, "plenty of moments")
	var virtues_seen := {}
	for entry: Dictionary in Moments.LIST:
		var options: Array = entry["options"]
		_check(options.size() >= 2, "moment %s is a real choice" % entry["id"])
		var has_failure := false
		var best_good_money := -1000
		for option: Dictionary in options:
			_check(not GameData.virtue_def(option["virtue"]).is_empty(), "moment %s names a real virtue" % entry["id"])
			virtues_seen[option["virtue"]] = true
			var effects: Dictionary = option.get("effects", {})
			if option["kind"] == "good":
				best_good_money = maxi(best_good_money, int(effects.get("money", 0)))
		for option: Dictionary in options:
			if option["kind"] != "failure":
				continue
			has_failure = true
			var effects: Dictionary = option.get("effects", {})
			_check(not str(option.get("regret", "")).is_empty(), "failure %s leaves a regret" % entry["id"])
			_check(int(effects.get("money", 0)) <= 0 and int(effects.get("money", 0)) <= best_good_money, "failure %s never pays" % entry["id"])
			for id: String in effects.get("stock", {}):
				_check(int(effects["stock"][id]) <= 0, "failure %s gains no stock" % entry["id"])
			for id: String in effects.get("needs", {}):
				_check(float(effects["needs"][id]) >= 0.0, "failure %s eases no need" % entry["id"])
			_check(float(effects.get("trust", 0.0)) <= 0.0 and float(effects.get("parish", 0.0)) <= 0.0, "failure %s wins no trust" % entry["id"])
		# Any moment with a failure is personal, never about the faith.
		if has_failure:
			var words := str(entry["text"]).to_lower()
			for option: Dictionary in options:
				words += " " + str(option["label"]).to_lower() + " " + str(option["text"]).to_lower()
			for banned: String in Moments.FAITH_WORDS:
				_check(not (" " + banned) in (" " + words.replace(".", " ").replace(",", " ").replace("\"", " ")), "moment %s keeps the faith out of the failure: %s" % [entry["id"], banned])
	_check(virtues_seen.size() == GameData.VIRTUES.size(), "every virtue is tested somewhere")
	# Stress brings moments more often; hatch moments need the hatch.
	Survival.change_need(save, "stress", -100.0)
	var calm := Moments.chance_per_hour(save)
	Survival.change_need(save, "stress", 100.0)
	_check(Moments.chance_per_hour(save) > calm * 2.0, "stress brings moments")
	save["world"]["hatch_open"] = false
	_check(not Moments.available(save, Moments.def("drunk")), "no hatch moment with the hatch shut")
	save["world"]["hatch_open"] = true
	_check(Moments.available(save, Moments.def("drunk")), "hatch moment with the hatch open")
	var rng := _rng(3)
	var first := {}
	for i in 200:
		first = Moments.roll(save, rng, 1.0)
		if not first.is_empty():
			break
	_check(not first.is_empty(), "a moment comes")
	_check(Moments.roll(save, rng, 50.0).is_empty(), "only one moment per shift")
	# The good grows a virtue; the failure costs and leaves a regret.
	var drunk: Dictionary = Moments.def("drunk")
	var patience := Virtue.level(save, "patience")
	Moments.choose(save, drunk["options"][0], character)
	_check(Virtue.level(save, "patience") > patience, "letting him go grows patience")
	var good_money := Survival.money(save)
	var good_stress := Survival.need(save, "stress")
	var other := _new_save()
	other["survival"]["stress"] = save["survival"]["stress"]
	other["survival"]["money"] = save["survival"]["money"] + 4
	var trust := Life.trust(other)
	var other_patience := Virtue.level(other, "patience")
	Moments.choose(other, drunk["options"][1], character)
	_check(Virtue.level(other, "patience") < other_patience or other_patience == 0.0, "shouting weakens patience")
	_check(Virtue.regrets(other).size() == 1, "and leaves a regret")
	_check(Life.trust(other) < trust, "and the street saw it")
	_check(Survival.money(other) <= good_money, "the failure is never the better strategy")


func _test_virtue_habits() -> void:
	var save := _new_save()
	var character := PlayerCharacter.from_dict(save["character"])
	var id := "charity" if not character.struggles.has("charity") and character.gift() != "charity" else "justice"
	save["virtues"][id] = 0.0
	var first := Virtue.level(save, id)
	Virtue.act(save, id, null)
	var gain_low := Virtue.level(save, id) - first
	save["virtues"][id] = 80.0
	Virtue.act(save, id, null)
	var gain_high := Virtue.level(save, id) - 80.0
	_check(gain_low > gain_high * 2.0, "habits grow more slowly as they settle")
	# A struggle grows slowly at first.
	var struggler := PlayerCharacter.new()
	struggler.temperament = "choleric"
	struggler.struggles = ["patience"]
	save["virtues"]["patience"] = 0.0
	Virtue.act(save, "patience", struggler)
	_check(Virtue.level(save, "patience") < gain_low, "a struggle comes harder at first")
	# Reaching a new rank says so.
	save["virtues"]["justice"] = 14.0
	_check(not Virtue.act(save, "justice", null).is_empty(), "a new rank is announced")
	# Many small acts make a strong habit.
	save["virtues"]["temperance"] = 0.0
	for i in 60:
		Virtue.act(save, "temperance", null)
	_check(Virtue.level(save, "temperance") >= 70.0, "sixty acts build a strong habit: %s" % Virtue.rank(save, "temperance"))
	# Effects are ease, never power over others.
	save["virtues"]["patience"] = 100.0
	_check(is_equal_approx(Virtue.insult_stress(save, 10.0), 5.0), "full patience halves an insult")
	save["virtues"]["temperance"] = 100.0
	_check(Virtue.need_rate(save) < 1.0, "temperance slows the needs")
	# Settled habits keep growing in ordinary weeks; barely begun ones fade.
	save["virtues"]["charity"] = 50.0
	save["virtues"]["justice"] = 10.0
	Virtue.drift(save, 4.0)
	_check(Virtue.level(save, "charity") > 50.0 and Virtue.level(save, "justice") < 10.0, "habits settle or fade")


func _test_parish() -> void:
	var save := _new_save()
	_check(Parish.sacraments_available(save), "a priest and a church at first")
	var strength := Parish.strength(save)
	save["survival"]["money"] = 50
	Parish.give(save, 10)
	_check(Parish.strength(save) > strength and Survival.money(save) == 40, "giving builds the parish")
	_check(Parish.give(save, 1000).begins_with("You do not"), "cannot give what you do not have")
	# Weeks without you, under a watchful state, wear it down.
	var rng := _rng(4)
	var weak := _new_save()
	var arrested := false
	for week in 80:
		weak["world"]["time"] = Survival.now(weak) + 7.0 * Survival.DAY
		Parish.week(weak, false, 0.9, rng)
		if not Parish.priest_free(weak):
			arrested = true
	_check(arrested, "a weak parish can lose its priest for a while")
	_check(Parish.closed(weak), "a parish nobody comes to is closed in the end")
	_check(not Parish.sacraments_available(weak), "no sacraments in a closed church")
	_check(not Soul.church_open(weak, 12 * 60.0), "a closed church stays closed")
	# Faithful weeks keep it alive.
	var strong := _new_save()
	for week in 80:
		strong["world"]["time"] = Survival.now(strong) + 7.0 * Survival.DAY
		Parish.week(strong, true, 0.1, rng)
	_check(not Parish.closed(strong), "a faithful parish survives")


func _test_life() -> void:
	var save := _new_save()
	var character := PlayerCharacter.from_dict(save["character"])
	_check(Life.illness_chance(40.0) == 0.0 and Life.illness_chance(70.0) > 0.0, "old age counts from the sixties")
	_check(Life.illness_chance(85.0) > Life.illness_chance(70.0) * 3.0, "and more each year")
	# Weeks pass in a summary.
	var day := Survival.day_of(Survival.now(save))
	var result := Life.pass_days(save, character, 28, _rng(2))
	_check(Survival.day_of(Survival.now(save)) == day + int(result["days"]), "days pass: %d" % int(result["days"]))
	_check(int(save["life"]["masses"]) >= 3, "Sundays at Mass while the weeks pass")
	_check(int(save["life"]["served"]) > 100, "and work")
	# Old: the last illness, the priest, a good death.
	var old := _new_save()
	old["life"]["born"] = Survival.now(old) - 88.0 * Life.YEAR
	var rng := _rng(8)
	var text := ""
	for i in 2000:
		text = Life.roll_illness(old, rng)
		if not text.is_empty():
			break
	_check(Life.ill(old), "an old life comes to its end: %s" % text)
	Virtue.fail(old, "patience", "Something small.")
	var priest := Life.send_for_priest(old)
	_check(priest.contains("anoints"), "the priest comes with the sacraments")
	_check(Virtue.regrets(old).is_empty(), "and lays down what you carried")
	var ending := Life.ending(old, character, "Died of old age.")
	_check(ending["good_death"] and ending["parish_lives"], "a good death and a living parish")
	_check(str(ending["title"]).contains("good death"), "the ending says so: %s" % ending["title"])
	# Without a priest, no anointing.
	var alone := _new_save()
	alone["parish"]["closed"] = true
	Life.send_for_priest(alone)
	_check(not Life.ending(alone, character, "Died.")["good_death"], "no priest, no last sacraments")


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
	for event: Dictionary in Horror.EVENTS:
		_check(not event.has("side"), "nothing demonic: %s" % event["id"])
	for gone in ["whisper", "mirror", "jumpscare", "shove", "smile", "lights_out"]:
		_check(Horror.def(gone).is_empty(), "demonic event removed: %s" % gone)
	# Calm, unnoticed, daytime: weak.
	save["horror"]["attention"] = 0.0
	save["survival"]["stress"] = 0.0
	save["world"]["time"] = Survival.now(save) - fmod(Survival.now(save), Survival.DAY) + 12 * 60.0
	var calm := Horror.intensity(save)
	_check(calm < 0.1, "calm noon is quiet: %f" % calm)
	# Watched, stressed, at night: strong.
	save["horror"]["attention"] = 90.0
	save["survival"]["stress"] = 80.0
	save["world"]["time"] = float(save["world"]["time"]) + 14 * 60.0
	_check(Horror.is_night(Survival.now(save)), "2am is night")
	_check(Horror.intensity(save) > 0.8, "attention, stress and night: strong: %f" % Horror.intensity(save))
	_check(Horror.chance(save) > Horror.CHANCE_MIN * 4.0, "strong horror comes often")
	Horror.fade(save, 10.0)
	_check(float(save["horror"]["attention"]) < 90.0, "attention fades")
	save["horror"]["attention"] = 90.0
	var context := {"in_church": false, "hatch_open": false, "customers": false}
	save["horror"]["dread"] = Horror.DREAD_NEEDED
	save["world"]["time"] = float(save["world"]["time"]) + Survival.DAY
	_check(not Horror.available(save, Horror.def("inspector"), context), "no inspector at night")
	context["in_church"] = true
	_check(Horror.roll(save, _rng(1), context).is_empty(), "the church is safe")
	context["in_church"] = false
	Horror.apply(save, Horror.def("drone"))
	_check(not Horror.available(save, Horror.def("drone"), context), "drone cools down")
	Survival.advance(save, 5 * 60.0)
	_check(Horror.available(save, Horror.def("drone"), context), "drone can come back")
	var rng := _rng(5)
	var happened := 0
	for i in 200:
		if not Horror.roll(save, rng, context).is_empty():
			happened += 1
	_check(happened > 10, "a strong director acts: %d" % happened)
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
	save["world"]["stock"]["candles"] = 3
	save["world"]["stock"]["sausages"] = 10
	var warned := Horror.def("raid").duplicate()
	warned["warned"] = true
	Horror.apply(save, warned)
	_check(Survival.stock(save, "candles") == 3 and Survival.stock(save, "sausages") >= 8, "a warning saves the candles and most of the stock")
	# Prudence hears warnings sooner; fortitude takes fear's edge off.
	var wise := _new_save()
	wise["virtues"]["prudence"] = 90.0
	wise["virtues"]["fortitude"] = 90.0
	_check(Virtue.warning_chance(wise) > Virtue.warning_chance(save) + 0.3, "prudence brings warnings")
	_check(Horror.scare_stress({"stress": 20.0}, 0, wise) < Horror.scare_stress({"stress": 20.0}, 0, save), "fortitude steadies you")


func _test_scripts_compile() -> void:
	for folder in ["res://scripts/core", "res://scripts/world", "res://scripts/ui", "res://scripts/screens", "res://scripts/autoload"]:
		for file in DirAccess.get_files_at(folder):
			if not file.ends_with(".gd"):
				continue
			var script: GDScript = load(folder + "/" + file)
			_check(script != null and script.can_instantiate(), "compiles: %s/%s" % [folder, file])


## Big events grow out of small ones, are spread out, and are not regular.
func _test_scare_pacing() -> void:
	var save := _new_save()
	var context := {"in_church": false, "hatch_open": false, "customers": false, "shutters_closed": false}
	_check(not Horror.big_ready(save), "nothing big on the first day")
	var rng := _rng(11)
	var bigs: Array = []
	var smalls := 0
	for step in int(30 * Survival.DAY / Horror.ROLL_MINUTES):
		save["horror"]["attention"] = 95.0
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
		if event.get("big", false):
			bigs.append(Survival.now(save))
		else:
			smalls += 1
	print("pacing: big %d, small %d" % [bigs.size(), smalls])
	_check(bigs.size() >= 3 and bigs.size() <= 30, "big events over 30 worst-case days: %d" % bigs.size())
	_check(smalls > bigs.size() * 2, "small events outnumber big ones: %d to %d" % [smalls, bigs.size()])
	var gaps: Array = []
	for i in range(1, bigs.size()):
		gaps.append((bigs[i] - bigs[i - 1]) / Survival.DAY)
	if gaps.size() >= 2:
		_check(absf(gaps.max() - gaps.min()) > 0.5, "big events are not on a schedule")
	# Someone the state ignores, calm, sees nothing big.
	var calm := _new_save()
	var quiet := 0
	for step in int(10 * Survival.DAY / Horror.ROLL_MINUTES):
		Survival.advance(calm, Horror.ROLL_MINUTES)
		calm["survival"]["health"] = 100.0
		calm["survival"]["hunger"] = 0.0
		calm["survival"]["thirst"] = 0.0
		calm["survival"]["tiredness"] = 0.0
		calm["survival"]["stress"] = 0.0
		calm["horror"]["attention"] = 0.0
		var event := Horror.roll(calm, rng, context)
		if not event.is_empty():
			Horror.apply(calm, event, 0, rng)
			if event.get("big", false):
				quiet += 1
	_check(quiet == 0, "no big events for the unnoticed: %d" % quiet)
	_check(Horror.scare_stress({"stress": 20.0}, 10) < Horror.scare_stress({"stress": 20.0}, 0), "nerve softens fear")


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
	faithful["horror"]["attention"] = 95.0
	faithful["survival"]["stress"] = 60.0
	faithful["world"]["time"] = float(faithful["world"]["time"]) + 3 * Survival.DAY + 6 * 60.0
	var hunts := 0
	for i in 400:
		faithful["horror"]["next_hunt"] = 0.0
		if Combat.roll_hunt(faithful, rng) > 0:
			hunts += 1
	_check(hunts > 5, "drones hunt the watched: %d of 400" % hunts)
	var sinner := _new_save()
	sinner["horror"]["attention"] = 0.0
	sinner["world"]["time"] = float(sinner["world"]["time"]) + 3 * Survival.DAY
	var none := 0
	for i in 200:
		sinner["horror"]["next_hunt"] = 0.0
		none += Combat.roll_hunt(sinner, rng)
	_check(none == 0, "the state does not hunt those it ignores")
	faithful["survival"]["money"] = 500
	var price := Combat.compliance_price(faithful)
	_check(price > Combat.compliance_price(sinner), "the watched pay more to be left alone")
	_check(Combat.pay_compliance(faithful) == "" and Survival.money(faithful) == 500 - price, "pay the contribution")
	_check(Combat.compliant(faithful), "left alone after paying")
	var quiet := 0
	for i in 400:
		faithful["horror"]["next_hunt"] = 0.0
		quiet += Combat.roll_hunt(faithful, rng)
	_check(quiet == 0, "no drone hunts while compliant")
	var context := {"in_church": false, "hatch_open": true, "customers": true, "shutters_closed": false}
	var state_events := 0
	for i in 400:
		var event := Horror.roll(faithful, rng, context)
		if not event.is_empty():
			state_events += 1
	_check(state_events == 0, "no state events while compliant")
	Survival.advance(faithful, Combat.COMPLIANCE_DAYS * Survival.DAY + 10.0)
	_check(not Combat.compliant(faithful), "compliance runs out")
