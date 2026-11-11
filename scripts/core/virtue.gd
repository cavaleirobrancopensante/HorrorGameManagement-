class_name Virtue
extends RefCounted
## The moral life, built as Aquinas builds it: on habit. Each good act makes
## the next one a little easier, and the habit grows more slowly the further
## it has come. A failure takes a little away and leaves a regret: no reward,
## only the sadness of having done less than you could. There is nothing
## evil to unlock and no reason, ever, to choose the failure.
##
## Levels run from 0 to 100. Works on the save dictionary, so it can be tested.

## What an ordinary act adds to a habit at level 0.
const GAIN := 3.0
## A struggle grows at this rate until it reaches STRUGGLE_UNTIL.
const STRUGGLE_SLOW := 0.6
const STRUGGLE_UNTIL := 25.0
## What a failure takes away.
const LOSS := 2.5


static func ensure(save: Dictionary, character: PlayerCharacter = null) -> void:
	if not (save.get("virtues") is Dictionary):
		save["virtues"] = character.starting_virtues() if character != null else {}
	var virtues: Dictionary = save["virtues"]
	for def: Dictionary in GameData.VIRTUES:
		if not virtues.has(def["id"]):
			virtues[def["id"]] = 8.0
	if not (save.get("soul") is Dictionary):
		save["soul"] = {}
	if not (save["soul"].get("regrets") is Array):
		save["soul"]["regrets"] = []


static func level(save: Dictionary, id: String) -> float:
	return float(save["virtues"].get(id, 0.0))


## 0 to 1: how settled the habit is.
static func habit(save: Dictionary, id: String) -> float:
	return clampf(level(save, id) / 100.0, 0.0, 1.0)


static func rank(save: Dictionary, id: String) -> String:
	return GameData.virtue_rank(level(save, id))


## A good act. weight scales it (a small kindness 0.5, a hard one 1.5).
## Returns a line to show when the habit reaches a new rank, otherwise "".
static func act(save: Dictionary, id: String, character: PlayerCharacter = null, weight := 1.0) -> String:
	var before := level(save, id)
	var gain := GAIN * weight * (1.0 - before / 120.0)
	if character != null and character.struggles.has(id) and before < STRUGGLE_UNTIL:
		gain *= STRUGGLE_SLOW
	var after := minf(before + gain, 100.0)
	save["virtues"][id] = after
	var name: String = GameData.virtue_def(id)["name"]
	if GameData.virtue_rank(after) != GameData.virtue_rank(before):
		return "%s: %s. It comes a little more easily now." % [name, GameData.virtue_rank(after).to_lower()]
	return ""


## A failure: the habit weakens a little, and you carry the regret until
## you lay it down in confession.
static func fail(save: Dictionary, id: String, regret: String) -> void:
	save["virtues"][id] = maxf(level(save, id) - LOSS, 0.0)
	regrets(save).append({"text": regret, "virtue": id, "day": int(save.get("day", 1))})


static func regrets(save: Dictionary) -> Array:
	return save["soul"]["regrets"]


## Confession: every regret is laid down. Returns how many there were.
static func lift_regrets(save: Dictionary) -> int:
	var count := regrets(save).size()
	regrets(save).clear()
	return count


## Settled habits keep acting through ordinary days; ones that are barely
## begun fade without practice. Used when weeks pass in a summary.
static func drift(save: Dictionary, weeks: float) -> void:
	for id: String in save["virtues"]:
		var value := level(save, id)
		var change := 0.35 * weeks if value >= 40.0 else -0.15 * weeks
		save["virtues"][id] = clampf(value + change, 0.0, 100.0)


# What each virtue changes ---------------------------------------------------------

## An insult or a long wait: patience takes up to half of its sting.
static func insult_stress(save: Dictionary, stress: float) -> float:
	return stress * (1.0 - 0.5 * habit(save, "patience"))


## Fear and danger: fortitude takes up to 40% of it.
static func fear_stress(save: Dictionary, stress: float) -> float:
	return stress * (1.0 - 0.4 * habit(save, "fortitude"))


## Hunger, thirst and tiredness creep up more slowly with temperance.
static func need_rate(save: Dictionary) -> float:
	if not (save.get("virtues") is Dictionary):
		return 1.0
	return 1.0 - 0.15 * habit(save, "temperance")


## The chance a warning reaches you before trouble arrives.
static func warning_chance(save: Dictionary) -> float:
	return 0.15 + 0.7 * habit(save, "prudence")


## Trust grows faster with honesty.
static func trust_factor(save: Dictionary) -> float:
	return 1.0 + habit(save, "justice")


## What you give does more with charity.
static func charity_factor(save: Dictionary) -> float:
	return 1.0 + habit(save, "charity")
