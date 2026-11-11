class_name PlayerCharacter
extends RefCounted
## The person the player creates. Pure data and rules, with no UI.

var full_name := ""
var temperament := "choleric"
var appearance := {}
## The virtues that come hard to this person, by id: one or two. A struggle
## gives nothing; it only means that virtue starts low and grows slowly at first.
var struggles: Array[String] = []
var free_points := {}  # stat id -> points placed by the player.


func _init() -> void:
	reset()


func reset() -> void:
	full_name = ""
	temperament = "choleric"
	appearance = {}
	for def: Dictionary in GameData.APPEARANCE:
		appearance[def["id"]] = def["options"][0][0]
	struggles = []
	free_points = {}
	for def: Dictionary in GameData.STATS:
		free_points[def["id"]] = 0


# Stats ------------------------------------------------------------------------

func stat_value(stat_id: String) -> int:
	var total: int = GameData.BASE_STAT + int(free_points.get(stat_id, 0))
	total += int(GameData.temperament_def(temperament)["stats"].get(stat_id, 0))
	return maxi(total, 0)


func max_health() -> int:
	return GameData.HEALTH_BASE + stat_value("endurance") * GameData.HEALTH_PER_ENDURANCE


func starting_money() -> int:
	return GameData.MONEY_BASE + stat_value("business") * GameData.MONEY_PER_BUSINESS


func free_points_left() -> int:
	var spent := 0
	for value: int in free_points.values():
		spent += value
	return GameData.FREE_POINTS - spent


func change_free_point(stat_id: String, delta: int) -> bool:
	var next: int = free_points[stat_id] + delta
	if next < 0 or next > GameData.MAX_FREE_PER_STAT:
		return false
	if delta > 0 and free_points_left() < delta:
		return false
	free_points[stat_id] = next
	return true


# Virtues ----------------------------------------------------------------------

## The virtue this temperament finds easy.
func gift() -> String:
	return GameData.temperament_def(temperament)["gift"]


## Marks a virtue as a struggle, or unmarks it. Returns false if that would
## make more than MAX_STRUGGLES, or mark the temperament's gift.
func toggle_struggle(virtue_id: String) -> bool:
	if struggles.has(virtue_id):
		struggles.erase(virtue_id)
		return true
	if struggles.size() >= GameData.MAX_STRUGGLES or virtue_id == gift():
		return false
	struggles.append(virtue_id)
	return true


## Where each virtue starts: the gift well on its way, struggles at nothing,
## the rest a little begun.
func starting_virtues() -> Dictionary:
	var levels := {}
	for def: Dictionary in GameData.VIRTUES:
		var id: String = def["id"]
		levels[id] = 0.0 if struggles.has(id) else (22.0 if id == gift() else 8.0)
	return levels


## How old they are when the story begins.
func start_age() -> int:
	return int(GameData.START_AGES.get(appearance.get("age", "grown"), 38))


# Validation -------------------------------------------------------------------

## Returns an empty string when the character can start, or the problem to show.
func validation_error() -> String:
	if full_name.strip_edges().is_empty():
		return "Give your character a name."
	if struggles.is_empty():
		return "Choose at least one struggle: a virtue that comes hard to you."
	if free_points_left() < 0:
		return "Too many ability points spent."
	return ""


# Randomizing ------------------------------------------------------------------

func randomize_name(rng: RandomNumberGenerator) -> void:
	var pool: Array = GameData.NAMES_WOMAN if appearance["sex"] == "woman" else GameData.NAMES_MAN
	full_name = "%s %s" % [_pick(pool, rng), _pick(GameData.SURNAMES, rng)]


func randomize_appearance(rng: RandomNumberGenerator) -> void:
	for def: Dictionary in GameData.APPEARANCE:
		appearance[def["id"]] = _pick(GameData.options_for(def["id"], "man"), rng)[0]
	for id in ["head", "top", "legs", "feet"]:
		appearance[id] = _pick(GameData.options_for(id, appearance["sex"]), rng)[0]
	normalize_appearance()


## Keeps appearance options that depend on each other consistent: a choice
## that does not exist for this sex falls back to the first that does.
func normalize_appearance() -> void:
	if appearance["sex"] == "woman":
		appearance["facial"] = "none"
	for id in ["head", "top", "legs", "feet"]:
		var options := GameData.options_for(id, appearance["sex"])
		var found := false
		for option: Array in options:
			if option[0] == appearance.get(id, ""):
				found = true
		if not found:
			appearance[id] = options[0][0]


func randomize_temperament(rng: RandomNumberGenerator) -> void:
	temperament = _pick(GameData.TEMPERAMENTS, rng)["id"]


func randomize_struggles(rng: RandomNumberGenerator) -> void:
	struggles = []
	var hard: String = GameData.temperament_def(temperament)["hard"]
	if rng.randf() < 0.6:
		struggles.append(hard)
	var ids: Array = GameData.VIRTUES.map(func(def: Dictionary) -> String: return def["id"])
	_shuffle(ids, rng)
	var wanted := rng.randi_range(1, GameData.MAX_STRUGGLES)
	for id: String in ids:
		if struggles.size() >= wanted:
			break
		if id != gift() and not struggles.has(id):
			struggles.append(id)


func randomize_free_points(rng: RandomNumberGenerator) -> void:
	for id: String in free_points:
		free_points[id] = 0
	var ids: Array = free_points.keys()
	while free_points_left() > 0:
		change_free_point(_pick(ids, rng), 1)


func randomize_all(rng: RandomNumberGenerator) -> void:
	randomize_appearance(rng)
	randomize_name(rng)
	randomize_temperament(rng)
	randomize_struggles(rng)
	randomize_free_points(rng)


func _pick(list: Array, rng: RandomNumberGenerator) -> Variant:
	return list[rng.randi_range(0, list.size() - 1)]


func _shuffle(list: Array, rng: RandomNumberGenerator) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var held: Variant = list[i]
		list[i] = list[j]
		list[j] = held


# Saving -----------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"full_name": full_name,
		"temperament": temperament,
		"appearance": appearance.duplicate(),
		"struggles": struggles.duplicate(),
		"free_points": free_points.duplicate(),
	}


## JSON turns every number into a float and old saves may lack newer fields,
## so only known keys are copied and numbers are converted back.
static func from_dict(data: Dictionary) -> PlayerCharacter:
	var character := PlayerCharacter.new()
	character.full_name = str(data.get("full_name", ""))
	var saved_temperament := str(data.get("temperament", "choleric"))
	if not GameData.temperament_def(saved_temperament).is_empty():
		character.temperament = saved_temperament
	var saved_look: Dictionary = data.get("appearance", {})
	for id: String in character.appearance:
		if saved_look.has(id):
			character.appearance[id] = str(saved_look[id])
	character.normalize_appearance()
	for id in data.get("struggles", []):
		if not GameData.virtue_def(str(id)).is_empty() and character.struggles.size() < GameData.MAX_STRUGGLES:
			character.struggles.append(str(id))
	# Characters made before virtues came in had sins marked instead: each
	# struggle with a sin becomes a struggle with the virtue against it.
	if character.struggles.is_empty() and data.get("sins") is Dictionary:
		var against := {"anger": "patience", "greed": "justice", "envy": "charity", "sloth": "fortitude", "gluttony": "temperance", "lust": "temperance", "pride": "prudence"}
		var old: Dictionary = data["sins"]
		for sin_id: String in old:
			var virtue_id: String = against.get(sin_id, "")
			if float(old[sin_id]) > 0.0 and not virtue_id.is_empty() and virtue_id != character.gift() and not character.struggles.has(virtue_id) and character.struggles.size() < GameData.MAX_STRUGGLES:
				character.struggles.append(virtue_id)
	if character.struggles.is_empty():
		character.struggles.append(GameData.temperament_def(character.temperament)["hard"])
	var saved_points: Dictionary = data.get("free_points", {})
	for id: String in character.free_points:
		character.free_points[id] = int(saved_points.get(id, 0))
	return character
