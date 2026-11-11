extends Node
## Ten independent save files, one JSON file each. Dead is dead: a dead
## character's file stays as a memorial and can never be loaded again.

const SLOT_COUNT := 10
const FORMAT_VERSION := 1

var base_dir := "user://saves"
var current_slot := -1
var current := {}


func slot_path(slot: int) -> String:
	return "%s/slot_%02d.json" % [base_dir, slot + 1]


## Returns {} for an empty slot, {"damaged": true} for an unreadable one,
## otherwise the whole save.
func read_slot(slot: int) -> Dictionary:
	var path := slot_path(slot)
	if not FileAccess.file_exists(path):
		return {}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		return {"damaged": true}
	var data: Variant = parser.data
	if not data is Dictionary or not data.has("character") or not data["character"] is Dictionary:
		return {"damaged": true}
	return data


func first_empty_slot() -> int:
	for slot in SLOT_COUNT:
		if not FileAccess.file_exists(slot_path(slot)):
			return slot
	return -1


func any_saves() -> bool:
	return first_empty_slot() != 0 or _count_files() > 0


func _count_files() -> int:
	var count := 0
	for slot in SLOT_COUNT:
		if FileAccess.file_exists(slot_path(slot)):
			count += 1
	return count


## The most recently played living character, or -1.
func most_recent_living_slot() -> int:
	var best := -1
	var best_time := -1.0
	for slot in SLOT_COUNT:
		var data := read_slot(slot)
		if data.is_empty() or data.has("damaged") or not data.get("alive", false):
			continue
		var updated := float(data.get("updated", 0.0))
		if updated > best_time:
			best_time = updated
			best = slot
	return best


func start_new(character: PlayerCharacter, slot: int) -> bool:
	var now := Time.get_unix_time_from_system()
	current_slot = slot
	current = {
		"version": FORMAT_VERSION,
		"created": now,
		"updated": now,
		"alive": true,
		"death_cause": "",
		"day": 1,
		"location": "trailer",
		"character": character.to_dict(),
	}
	# Money, health, needs, soul, clock and stock all start from the rules.
	Survival.ensure(current)
	return save_current()


func load_slot(slot: int) -> bool:
	var data := read_slot(slot)
	if data.is_empty() or data.has("damaged") or not data.get("alive", false):
		return false
	current_slot = slot
	current = data
	Survival.ensure(current)
	return true


func current_character() -> PlayerCharacter:
	return PlayerCharacter.from_dict(current.get("character", {}))


func save_current() -> bool:
	if current_slot < 0 or current.is_empty():
		return false
	GameLog.mark("saving")
	current["updated"] = Time.get_unix_time_from_system()
	return _write(current_slot, current)


## Ends the current life and writes it straight to disk, so closing the game
## at the moment of death cannot undo it.
func kill_current(cause: String) -> bool:
	if current_slot < 0 or current.is_empty():
		return false
	current["alive"] = false
	current["death_cause"] = cause
	return save_current()


func delete_slot(slot: int) -> bool:
	var path := slot_path(slot)
	if not FileAccess.file_exists(path):
		return true
	if slot == current_slot:
		current_slot = -1
		current = {}
	return DirAccess.remove_absolute(path) == OK


## Writes beside the real file and then swaps it in, so a crash halfway
## through cannot destroy the existing save.
func _write(slot: int, data: Dictionary) -> bool:
	if DirAccess.make_dir_recursive_absolute(base_dir) != OK:
		return false
	var path := slot_path(slot)
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	var written := file.store_string(JSON.stringify(data, "\t"))
	file.close()
	if not written:
		DirAccess.remove_absolute(temporary)
		return false
	return DirAccess.rename_absolute(temporary, path) == OK
