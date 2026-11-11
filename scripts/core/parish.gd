class_name Parish
extends RefCounted
## St. Brigid's: its people, its priest, and whether it survives. Keeping it
## alive is half of the game's goal. Its strength (0 to 100) is the life of
## the community: who comes on Sunday, who gives, who stands by the priest.
## The persecution wears it down; your faithfulness, your gifts and your
## courage build it up. If it falls to nothing, the church is closed.
##
## The priest can be taken in for questioning when the parish is weak and the
## state is watching: for some weeks there is no Mass and no confession.

const START := 55.0
const PRIEST := "Father Columba"


static func ensure(save: Dictionary) -> void:
	if not (save.get("parish") is Dictionary):
		save["parish"] = {}
	var parish: Dictionary = save["parish"]
	if not parish.has("strength"):
		parish["strength"] = START
	if not parish.has("priest_back"):
		parish["priest_back"] = 0.0
	if not parish.has("closed"):
		parish["closed"] = false
	if not parish.has("given"):
		parish["given"] = 0


static func strength(save: Dictionary) -> float:
	return float(save["parish"]["strength"])


static func closed(save: Dictionary) -> bool:
	return bool(save["parish"]["closed"])


## The priest is free (not held by the state).
static func priest_free(save: Dictionary) -> bool:
	return Survival.now(save) >= float(save["parish"]["priest_back"])


## Mass and confession need both the church and the priest.
static func sacraments_available(save: Dictionary) -> bool:
	return not closed(save) and priest_free(save)


static func change(save: Dictionary, delta: float) -> void:
	if closed(save):
		return
	save["parish"]["strength"] = clampf(strength(save) + delta, 0.0, 100.0)


## Something given to the parish in money: charity makes it go further.
static func give(save: Dictionary, amount: int) -> String:
	if amount <= 0 or Survival.money(save) < amount:
		return "You do not have that much."
	save["survival"]["money"] = Survival.money(save) - amount
	save["parish"]["given"] = int(save["parish"]["given"]) + amount
	change(save, amount * 0.12 * Virtue.charity_factor(save))
	return "You put %d credits in the box by the door. Nobody sees, which is how it should be." % amount


## How the parish stands, in a sentence.
static func describe(save: Dictionary) -> String:
	if closed(save):
		return "St. Brigid's is closed. Its doors are chained."
	var value := strength(save)
	var people := "full on Sundays, with people standing at the back" if value >= 75.0 else (
		"well attended, though fewer than last year" if value >= 50.0 else (
		"thinning out: whole pews stand empty" if value >= 25.0 else "barely holding on: a handful of old women and you"))
	var priest := "" if priest_free(save) else " Father Columba is being held for questioning."
	return "St. Brigid's is %s.%s" % [people, priest]


## The end of a week. attended: you were at Mass on Sunday. attention: how
## hard the state is watching (0 to 1). Returns lines of news.
static func week(save: Dictionary, attended: bool, attention: float, rng: RandomNumberGenerator) -> Array[String]:
	var news: Array[String] = []
	if closed(save):
		return news
	var delta := rng.randf_range(-1.0, 1.5) - attention * 3.0
	delta += 1.0 if attended else -2.0
	change(save, delta)
	# A weak parish under a watchful state may lose its priest for a while.
	if priest_free(save) and strength(save) < 40.0 and rng.randf() < (0.4 - strength(save) / 100.0) * 0.3 + attention * 0.05:
		save["parish"]["priest_back"] = Survival.now(save) + rng.randf_range(2.0, 6.0) * 7.0 * Survival.DAY
		news.append("Father Columba has been taken in for questioning. There will be no Mass until he is back.")
	if strength(save) <= 0.0:
		save["parish"]["closed"] = true
		news.append("St. Brigid's has been closed 'for a safety review'. The doors are chained.")
	return news
