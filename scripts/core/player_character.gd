class_name PlayerCharacter
extends RefCounted
## The person the player creates. Pure data and rules, with no UI.

var full_name := ""
var temperament := "choleric"
var appearance := {}
var sins := {}  # sin id -> level, from MIN_SIN_LEVEL to MAX_SIN_LEVEL.
var free_points := {}  # stat id -> points placed by the player.


func _init() -> void:
	reset()


func reset() -> void:
	full_name = ""
	temperament = "choleric"
	appearance = {}
	for def: Dictionary in GameData.APPEARANCE:
		appearance[def["id"]] = def["options"][0][0]
	sins = {}
	for def: Dictionary in GameData.SINS:
		sins[def["id"]] = 0
	free_points = {}
	for def: Dictionary in GameData.STATS:
		free_points[def["id"]] = 0


# Stats ------------------------------------------------------------------------

func stat_value(stat_id: String) -> int:
	var total: int = GameData.BASE_STAT + int(free_points.get(stat_id, 0))
	total += int(GameData.temperament_def(temperament)["stats"].get(stat_id, 0))
	for def: Dictionary in GameData.SINS:
		var level: int = sins[def["id"]]
		if level > 0:
			total += level * int(def["vice_bonus"].get(stat_id, 0))
		elif level < 0:
			total += -level * int(def["virtue_bonus"].get(stat_id, 0))
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


# Sins and virtues -------------------------------------------------------------

## How many more steps toward virtue the character can still take.
func strengths_left() -> int:
	var total := 0
	for level: int in sins.values():
		total += level
	return total


func set_sin_level(sin_id: String, level: int) -> bool:
	if level < GameData.MIN_SIN_LEVEL or level > GameData.MAX_SIN_LEVEL:
		return false
	var previous: int = sins[sin_id]
	sins[sin_id] = level
	if strengths_left() < 0:
		sins[sin_id] = previous
		return false
	return true


func has_struggle() -> bool:
	for level: int in sins.values():
		if level > 0:
			return true
	return false


## Multiplier for how hard this sin tempts the character. 1.0 is ordinary.
func temptation_strength(sin_id: String) -> float:
	var level: int = sins[sin_id]
	var strength := 1.0
	if level > 0:
		strength += level * GameData.TEMPTATION_PER_VICE_LEVEL
	else:
		strength += level * GameData.TEMPTATION_PER_VIRTUE_LEVEL
	if sin_id in GameData.temperament_def(temperament)["inclined"]:
		strength += GameData.TEMPTATION_INCLINATION
	return strength


## The worst struggle, which is the tradition's "predominant fault". Empty if none.
func predominant_fault() -> String:
	var worst := ""
	var worst_level := 0
	for def: Dictionary in GameData.SINS:
		if sins[def["id"]] > worst_level:
			worst_level = sins[def["id"]]
			worst = def["id"]
	return worst


# Validation -------------------------------------------------------------------

## Returns an empty string when the character can start, or the problem to show.
func validation_error() -> String:
	if full_name.strip_edges().is_empty():
		return "Give your character a name."
	if not has_struggle():
		return "Choose at least one struggle. Nobody starts without a fault."
	if strengths_left() < 0:
		return "Too many virtues for the struggles chosen."
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


func randomize_sins(rng: RandomNumberGenerator) -> void:
	for id: String in sins:
		sins[id] = 0
	var order: Array = sins.keys()
	_shuffle(order, rng)
	var struggles := rng.randi_range(1, 4)
	for i in struggles:
		sins[order[i]] = rng.randi_range(1, GameData.MAX_SIN_LEVEL)
	var remaining: Array = order.slice(struggles)
	for id: String in remaining:
		var budget := mini(strengths_left(), -GameData.MIN_SIN_LEVEL)
		if budget > 0:
			sins[id] = -rng.randi_range(0, budget)


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
	randomize_sins(rng)
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
		"sins": sins.duplicate(),
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
	var saved_sins: Dictionary = data.get("sins", {})
	for id: String in character.sins:
		character.sins[id] = int(saved_sins.get(id, 0))
	var saved_points: Dictionary = data.get("free_points", {})
	for id: String in character.free_points:
		character.free_points[id] = int(saved_points.get(id, 0))
	return character
