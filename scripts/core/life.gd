class_name Life
extends RefCounted
## A whole life: your age, the trust of the street, the years passing, and
## how it ends. The game goes on until you die. From your sixties, age itself
## may bring the end: first an illness, then death, and the hope of a good
## death, with the priest at your side and the sacraments.
##
## So that a life can be lived in a game, weeks can pass in a summary: your
## habits carry on, the parish has its Sundays, the street its troubles.

const YEAR := 365.0 * Survival.DAY
## Old age begins to count from this age.
const OLD_AGE := 62.0
## Days an illness lasts, at the end.
const ILLNESS_DAYS := Vector2(3.0, 9.0)


static func ensure(save: Dictionary, character: PlayerCharacter) -> void:
	if not (save.get("life") is Dictionary):
		save["life"] = {}
	var life: Dictionary = save["life"]
	if not life.has("born"):
		var age := character.start_age() if character != null else 38
		life["born"] = Survival.START_MINUTE - (float(age) + 0.37) * YEAR
	for key in ["served", "masses", "anointed"]:
		if not life.has(key):
			life[key] = 0
	if not life.has("trust"):
		life["trust"] = 40.0
	if not life.has("ill_until"):
		life["ill_until"] = -1.0


static func age(save: Dictionary) -> int:
	return int(floorf((Survival.now(save) - float(save["life"]["born"])) / YEAR))


static func trust(save: Dictionary) -> float:
	return float(save["life"]["trust"])


## Trust is how the street sees you. Honesty makes it grow faster.
static func change_trust(save: Dictionary, delta: float) -> void:
	if delta > 0.0:
		delta *= Virtue.trust_factor(save)
	save["life"]["trust"] = clampf(trust(save) + delta, 0.0, 100.0)


static func count(save: Dictionary, key: String, amount := 1) -> void:
	save["life"][key] = int(save["life"].get(key, 0)) + amount


# Old age --------------------------------------------------------------------------

## The chance, on any one day, that the last illness begins.
static func illness_chance(age_years: float) -> float:
	if age_years < OLD_AGE:
		return 0.0
	var over := (age_years - OLD_AGE) / 28.0
	return over * over * 0.006


static func ill(save: Dictionary) -> bool:
	return float(save["life"]["ill_until"]) > 0.0


## Called each day. Returns a line if the last illness begins today.
static func roll_illness(save: Dictionary, rng: RandomNumberGenerator) -> String:
	if ill(save) or rng.randf() >= illness_chance(age(save)):
		return ""
	save["life"]["ill_until"] = Survival.now(save) + rng.randf_range(ILLNESS_DAYS.x, ILLNESS_DAYS.y) * Survival.DAY
	return "You wake with a weight on your chest that does not lift. The doctor at the clinic listens a long time and says, gently, that you should put your affairs in order. You are %d." % age(save)


## True once the illness has run its course.
static func illness_over(save: Dictionary) -> bool:
	return ill(save) and Survival.now(save) >= float(save["life"]["ill_until"])


## The priest comes to the dying: confession, anointing, Viaticum. Returns
## what happens, or why he cannot come.
static func send_for_priest(save: Dictionary) -> String:
	if int(save["life"]["anointed"]) > 0:
		return "Father Columba has already been. There is nothing left undone."
	if not Parish.sacraments_available(save):
		return "There is no priest to send for. You pray as you can, and trust the rest to God."
	save["life"]["anointed"] = 1
	Virtue.lift_regrets(save)
	return "Father Columba comes after dark, past the cameras, with the oils and the Blessed Sacrament under his coat. He hears your confession, anoints your forehead and your hands, and gives you Communion for the journey. \"Go forth, Christian soul.\" He stays a long while."


# The weeks passing ------------------------------------------------------------------

## Lets days go by in a summary, as your habits would live them: work most
## days, Mass on Sundays. Stops early if the last illness begins. Returns
## {"lines": what happened, "days": how many passed}.
static func pass_days(save: Dictionary, character: PlayerCharacter, days: int, rng: RandomNumberGenerator) -> Dictionary:
	var lines: Array[String] = []
	var earned := 0
	var passed := 0
	var skill := (character.stat_value("cooking") + character.stat_value("charm") + character.stat_value("business")) / 30.0
	for i in days:
		passed += 1
		var now := Survival.now(save)
		save["world"]["time"] = now + Survival.DAY
		save["day"] = Survival.day_of(Survival.now(save))
		var weekday := Survival.weekday(Survival.now(save))
		if weekday != 0:
			var customers := 26.0 * (0.6 + 0.5 * skill) * (0.75 + 0.5 * trust(save) / 100.0) * rng.randf_range(0.8, 1.2)
			var takings := roundi(customers * 2.4) - 9
			earned += takings
			count(save, "served", roundi(customers))
			change_trust(save, 0.12)
		else:
			var at_mass := Parish.sacraments_available(save)
			if at_mass:
				count(save, "masses")
			for line in Parish.week(save, at_mass, Horror.attention(save), rng):
				lines.append(line)
			Virtue.drift(save, 1.0)
		var trouble := Horror.quiet_trouble(save, rng)
		if not trouble.is_empty():
			lines.append(trouble)
		var illness := roll_illness(save, rng)
		if not illness.is_empty():
			lines.append(illness)
			break
	save["survival"]["money"] = maxi(Survival.money(save) + earned, 0)
	for need_def: Dictionary in GameData.NEEDS:
		save["survival"][need_def["id"]] = need_def["start"] + 5
	lines.push_front("%d days pass. You work, you go to Mass on Sundays, you get by. You take %d credits after costs." % [passed, earned])
	return {"lines": lines, "days": passed}


# The end --------------------------------------------------------------------------

## How a life is remembered. cause: how it ended.
static func ending(save: Dictionary, character: PlayerCharacter, cause: String) -> Dictionary:
	var good_death := int(save["life"]["anointed"]) > 0
	var parish_lives := not Parish.closed(save)
	var lines: Array[String] = []
	lines.append("%s died at %d. %s" % [character.full_name, age(save), cause])
	if good_death:
		lines.append("A good death: Father Columba was there, with the sacraments.")
	else:
		lines.append("There was no priest at the end. The parish prays for you all the same.")
	lines.append(Parish.describe(save) + (" It outlives you." if parish_lives else ""))
	var grown: PackedStringArray = []
	for def: Dictionary in GameData.VIRTUES:
		grown.append("%s: %s" % [def["name"], Virtue.rank(save, def["id"]).to_lower()])
	lines.append("What you built: " + ", ".join(grown) + ".")
	lines.append("You served %d people at the hatch and heard Mass %d times." % [int(save["life"]["served"]), int(save["life"]["masses"])])
	var title := "Requiescat in pace"
	if good_death and parish_lives:
		title = "A good death, and a parish that lives"
	elif good_death:
		title = "A good death"
	elif parish_lives:
		title = "The parish lives on"
	return {"title": title, "lines": lines, "good_death": good_death, "parish_lives": parish_lives}
