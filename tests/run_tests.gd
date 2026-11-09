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
	saves.current["day"] = 9
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


func _test_damaged_file() -> void:
	_clean()
	DirAccess.make_dir_recursive_absolute(saves.base_dir)
	var file := FileAccess.open(saves.slot_path(3), FileAccess.WRITE)
	file.store_string("{ not json")
	file.close()
	_check(saves.read_slot(3).has("damaged"), "damaged detected")
	_check(not saves.load_slot(3), "damaged cannot load")
	_check(saves.most_recent_living_slot() == -1, "damaged cannot continue")
