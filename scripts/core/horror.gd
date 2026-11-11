class_name Horror
extends RefCounted
## The horror director's rules. The horror is human: a state that watches and
## persecutes, informants, inspectors, drones, raids and the knock at night,
## and the street's own gangs and thieves. What draws it is how visible your
## faith is to the state (attention, 0 to 100), how stressed you are, and
## the hour. Nothing supernatural is shown.
## Works on the save dictionary, so it can be tested.
##
## PACING. Small events (a drone, a fine, a man watching) build dread. Big
## ones (a raid, a power cut) need dread first: at least DREAD_NEEDED small
## events since the last big one. After a big one comes a calm of random
## length, so it cannot be counted on. Nothing big on the first day.

## How often the director rolls, in game minutes.
const ROLL_MINUTES := 20.0
const CHANCE_MIN := 0.02
const CHANCE_MAX := 0.10
const DREAD_NEEDED := 2
## Days of calm after a big event at full strength, before randomness.
const BIG_GAP_DAYS := Vector2(0.8, 1.8)
## Attention fades by this much a day when nothing feeds it.
const ATTENTION_FADE := 1.5

## min: intensity needed (0 to 1). night: only in the night and dead shifts.
## day: only while the stand could be open (morning to evening).
## hatch: only with the hatch open and a customer. window: only when the
## shutters are open. cooldown: game hours before it can happen again.
const EVENTS := [
	{"id": "drone", "min": 0.05, "cooldown": 4.0, "stress": 3.0, "window": true,
		"text": "A Civic drone hovers at your window, its lens turning."},
	{"id": "camera_shape", "min": 0.15, "cooldown": 8.0, "stress": 3.0,
		"text": "Civic Link: motion detected on your street camera. Someone is going through your bins."},
	{"id": "tax", "min": 0.2, "cooldown": 24.0, "stress": 5.0, "money": -12,
		"text": "Civic Link: your business is reassessed as 'faith-affiliated'. Compliance surcharge: 12 credits."},
	{"id": "knock", "min": 0.2, "cooldown": 12.0, "stress": 6.0, "night": true,
		"text": "Three knocks at the door, late. When you open it there is nobody, only a Civic notice taped at eye level: YOUR ASSOCIATIONS HAVE BEEN NOTED."},
	{"id": "feeds_seized", "min": 0.25, "cooldown": 16.0, "stress": 5.0,
		"text": "Civic Link: your security cameras have been placed under public supervision. Your feeds are unavailable for the shift."},
	{"id": "inspector", "min": 0.3, "cooldown": 12.0, "stress": 8.0, "hatch": true, "day": true,
		"text": ""},
	{"id": "power_cut", "big": true, "min": 0.3, "cooldown": 10.0, "stress": 8.0,
		"text": "Civic Grid: power to your address is 'rationed' for the good of the district. The trailer goes dark."},
	{"id": "watcher", "min": 0.35, "cooldown": 8.0, "stress": 5.0, "night": true, "window": true,
		"text": "A man is standing under the street lamp across the road, facing your window. He does not move."},
	{"id": "informant", "min": 0.4, "cooldown": 10.0, "stress": 5.0,
		"text": "The man in the grey coat stands across the street. He is writing something down."},
	{"id": "raid", "big": true, "min": 0.65, "cooldown": 96.0, "stress": 20.0, "night": true, "health": -8.0,
		"text": ""},
]


static func ensure(save: Dictionary) -> void:
	if not (save.get("horror") is Dictionary):
		save["horror"] = {}
	var horror: Dictionary = save["horror"]
	if not (horror.get("last") is Dictionary):
		horror["last"] = {}
	if not horror.has("feeds_off_until"):
		horror["feeds_off_until"] = 0.0
	for key in ["dread", "next_big", "last_burglary"]:
		if not horror.has(key):
			horror[key] = 0.0
	if not horror.has("attention"):
		horror["attention"] = 10.0
	horror.erase("next_face")


static func def(id: String) -> Dictionary:
	for event: Dictionary in EVENTS:
		if event["id"] == id:
			return event
	return {}


static func is_night(minutes: float) -> bool:
	return Survival.shift_index(minutes) >= 4


## 0 to 1: how hard the state is watching you.
static func attention(save: Dictionary) -> float:
	return clampf(float(save["horror"]["attention"]) / 100.0, 0.0, 1.0)


## Your faith being seen: Mass, confession, helping the priest. Faithfulness
## is never made the wrong choice; it simply has a price in this world.
static func notice(save: Dictionary, amount: float) -> void:
	save["horror"]["attention"] = clampf(float(save["horror"]["attention"]) + amount, 0.0, 100.0)


## A day without anything new: attention fades a little.
static func fade(save: Dictionary, days := 1.0) -> void:
	notice(save, -ATTENTION_FADE * days)


## 0 to 1: how strong the horror is right now. The persecution also hardens
## slowly over the years.
static func intensity(save: Dictionary, _side := "") -> float:
	var years := maxf(Survival.now(save) - Survival.START_MINUTE, 0.0) / (365.0 * Survival.DAY)
	var level := attention(save) * 0.55 + minf(years * 0.04, 0.2)
	level += Survival.need(save, "stress") / float(GameData.NEED_MAX) * 0.2
	if is_night(Survival.now(save)):
		level += 0.15
	return clampf(level, 0.0, 1.0)


static func chance(save: Dictionary) -> float:
	return lerpf(CHANCE_MIN, CHANCE_MAX, intensity(save))


## context: {"in_church", "near_mirror", "hatch_open", "customers"} -> bool.
static func available(save: Dictionary, event: Dictionary, context: Dictionary) -> bool:
	var now := Survival.now(save)
	if intensity(save) < float(event["min"]):
		return false
	if context.get("in_church", false):
		return false
	if event.get("night", false) and not is_night(now):
		return false
	if event.get("day", false) and is_night(now):
		return false
	if event.get("hatch", false) and not (context.get("hatch_open", false) and context.get("customers", false)):
		return false
	if event.get("window", false) and context.get("shutters_closed", false):
		return false
	if event.get("big", false) and not big_ready(save):
		return false
	var last := float(save["horror"]["last"].get(event["id"], -100000.0))
	return now - last >= float(event["cooldown"]) * 60.0


## One roll of the director. Returns an event, or {} if nothing happens.
static func roll(save: Dictionary, rng: RandomNumberGenerator, context: Dictionary) -> Dictionary:
	if context.get("in_church", false):
		return {}
	if rng.randf() >= chance(save):
		return {}
	# A compliance contribution buys a few days without the state.
	if Survival.now(save) < float(save["horror"].get("compliance_until", 0.0)):
		return {}
	var options: Array = []
	for event: Dictionary in EVENTS:
		if available(save, event, context):
			options.append(event)
	if options.is_empty():
		return {}
	# The strongest available events are a little likelier.
	var total := 0.0
	for event: Dictionary in options:
		total += _weight(event)
	var at := rng.randf() * total
	for event: Dictionary in options:
		at -= _weight(event)
		if at <= 0.0:
			return event
	return options[-1]


static func _weight(event: Dictionary) -> float:
	return 1.0 + float(event["min"])


## Whether a big scare may come now: past the first day, after the calm,
## and with dread built up.
static func big_ready(save: Dictionary) -> bool:
	var horror: Dictionary = save["horror"]
	var now := Survival.now(save)
	if now - Survival.START_MINUTE < Survival.DAY:
		return false
	return now >= float(horror["next_big"]) and int(horror["dread"]) >= DREAD_NEEDED


## Marks a big event: dread resets, and the next calm is drawn at random.
static func mark_big(save: Dictionary, rng: RandomNumberGenerator) -> void:
	var horror: Dictionary = save["horror"]
	var now := Survival.now(save)
	var level := intensity(save)
	horror["dread"] = 0
	var gap := lerpf(BIG_GAP_DAYS.y, BIG_GAP_DAYS.x, level) * rng.randf_range(0.7, 1.6)
	horror["next_big"] = now + gap * Survival.DAY


## Nerve takes the edge off fear, and fortitude more.
static func scare_stress(event: Dictionary, nerve: int, save: Dictionary = {}) -> float:
	var stress := float(event.get("stress", 0.0)) * clampf(1.0 - nerve * 0.04, 0.5, 1.0)
	return Virtue.fear_stress(save, stress) if save.has("virtues") else stress


## What an event does to you. Returns the text to show ("" when the scene
## itself tells it). Marks the event so its cooldown starts.
static func apply(save: Dictionary, event: Dictionary, nerve := 0, rng: RandomNumberGenerator = null) -> String:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var now := Survival.now(save)
	save["horror"]["last"][event["id"]] = now
	if event.get("big", false):
		mark_big(save, rng)
	else:
		save["horror"]["dread"] = int(save["horror"]["dread"]) + 1
	Survival.change_need(save, "stress", scare_stress(event, nerve, save))
	if event.has("health"):
		Survival.change_health(save, float(event["health"]))
	if event.has("money"):
		save["survival"]["money"] = maxi(Survival.money(save) + int(event["money"]), 0)
	match event["id"]:
		"feeds_seized":
			save["horror"]["feeds_off_until"] = Survival.shift_end(now)
		"inspector":
			return inspect(save)
		"raid":
			return raid(save, bool(event.get("warned", false)))
	return event["text"]


## The inspector fines you, more for a filthy counter, and shuts the hatch.
static func inspect(save: Dictionary) -> String:
	var dirt := 0.0
	for key: String in save["world"]["dirt"]:
		dirt = maxf(dirt, float(save["world"]["dirt"][key]))
	var fine := 8 + (12 if dirt >= 0.6 else 0)
	save["survival"]["money"] = maxi(Survival.money(save) - fine, 0)
	save["world"]["hatch_open"] = false
	if dirt >= 0.6:
		return "A Civic hygiene inspector looks at your counters and smiles. Fined %d credits. Your hatch is closed for inspection." % fine
	return "A Civic hygiene inspector finds nothing wrong, and fines you %d credits anyway. Your hatch is closed for inspection." % fine


## Enforcers at the door at night: they take your candles and some of your
## stock. Warned in time, you had hidden the candles and most of the stock.
static func raid(save: Dictionary, warned := false) -> String:
	var stock: Dictionary = save["world"]["stock"]
	var taken: PackedStringArray = []
	if warned:
		for id: String in ["sausages", "patties"]:
			var lost := int(stock.get(id, 0)) / 5
			if lost > 0:
				stock[id] = int(stock[id]) - lost
				taken.append("%d %s" % [lost, id])
		var little := "nothing" if taken.is_empty() else ", ".join(taken)
		return "CIVIC ENFORCEMENT. They push past you and search the trailer for 'unregistered religious material'. Thanks to the warning, the candles were hidden, and they take only %s." % little
	if int(stock.get("candles", 0)) > 0:
		taken.append("your candles")
		stock["candles"] = 0
	for id: String in ["sausages", "patties"]:
		var lost := int(stock.get(id, 0)) / 2
		if lost > 0:
			stock[id] = int(stock[id]) - lost
			taken.append("%d %s" % [lost, id])
	var what := "nothing worth taking" if taken.is_empty() else ", ".join(taken)
	return "CIVIC ENFORCEMENT. They push past you and search the trailer for 'unregistered religious material'. They take %s." % what


static func feeds_off(save: Dictionary) -> bool:
	return Survival.now(save) < float(save["horror"]["feeds_off_until"])



# The night --------------------------------------------------------------------
# While you sleep, a burglar may come through the window. At most one a night.

const BURGLAR_BASE := 0.07
## Shutters closed: most give up at the shutter.
const SHUTTER_GUARD := 0.25
const BURGLAR_GAP_DAYS := 3.0


static func burglar_chance(save: Dictionary, shutters_closed: bool) -> float:
	var chance := BURGLAR_BASE + minf(Survival.money(save) / 400.0, 0.12)
	if shutters_closed:
		chance *= SHUTTER_GUARD
	return chance


## Rolls the night before you sleep. Returns {} or {"id": "burglar" |
## "pry_marks", "after": minutes asleep before it happens}.
static func night(save: Dictionary, rng: RandomNumberGenerator, shutters_closed: bool, sleep_minutes: float) -> Dictionary:
	var horror: Dictionary = save["horror"]
	var now := Survival.now(save)
	var after := clampf(sleep_minutes * rng.randf_range(0.3, 0.7), 60.0, maxf(sleep_minutes - 30.0, 60.0))
	if now - float(horror["last_burglary"]) < BURGLAR_GAP_DAYS * Survival.DAY:
		return {}
	var open_chance := BURGLAR_BASE + minf(Survival.money(save) / 400.0, 0.12)
	var roll := rng.randf()
	if roll < burglar_chance(save, shutters_closed):
		horror["last_burglary"] = now
		return {"id": "burglar", "after": after}
	if shutters_closed and roll < open_chance:
		# Someone tried, and the shutter held.
		horror["last_burglary"] = now
		return {"id": "pry_marks", "after": sleep_minutes}
	return {}


## Chance to win a fight with a burglar, bare-handed in the dark.
static func fight_chance(endurance: int, vigilance: int) -> float:
	return clampf(0.3 + endurance * 0.04 + vigilance * 0.015, 0.2, 0.85)


## Returns {"text", "won"}. Losing hurts and he takes the money anyway.
static func fight_burglar(save: Dictionary, endurance: int, vigilance: int, rng: RandomNumberGenerator) -> Dictionary:
	if rng.randf() < fight_chance(endurance, vigilance):
		Survival.change_health(save, -rng.randf_range(3.0, 8.0))
		Survival.change_need(save, "stress", 10.0)
		return {"won": true, "text": "You go for him. He goes back out of the window faster than he came in. Your knuckles are split and your hands will not stop shaking."}
	Survival.change_health(save, -rng.randf_range(18.0, 34.0))
	Survival.change_need(save, "stress", 22.0)
	var stolen := _steal(save, rng, 0.6)
	return {"won": false, "text": "He is faster. Something heavy catches you across the head, and when you can see again he is gone, with %d credits." % stolen}


## Doing nothing: he takes money and goes.
static func let_burglar(save: Dictionary, rng: RandomNumberGenerator) -> String:
	Survival.change_need(save, "stress", 12.0)
	var stolen := _steal(save, rng, 0.45)
	return "You lie still. He finds the cash tin, takes %d credits and goes back out the way he came. You do not sleep again." % stolen


static func _steal(save: Dictionary, rng: RandomNumberGenerator, share: float) -> int:
	var stolen := mini(roundi(Survival.money(save) * share * rng.randf_range(0.8, 1.2)), 80)
	save["survival"]["money"] = Survival.money(save) - stolen
	return stolen


## A day passing in a summary: maybe some trouble from the state or the
## street. Returns a line, or "".
static func quiet_trouble(save: Dictionary, rng: RandomNumberGenerator) -> String:
	fade(save)
	if rng.randf() >= 0.015 + intensity(save) * 0.04:
		return ""
	var roll := rng.randf()
	if roll < 0.4:
		var fine := mini(rng.randi_range(8, 25), Survival.money(save))
		save["survival"]["money"] = Survival.money(save) - fine
		return "A Civic inspector fines you %d credits for something nobody can explain." % fine
	if roll < 0.7:
		var stolen := _steal(save, rng, 0.2)
		return "Someone gets in through the window one night and takes %d credits." % stolen
	if roll < 0.9:
		return raid(save, rng.randf() < Virtue.warning_chance(save))
	Survival.change_need(save, "stress", 6.0)
	return "For a week a man in a grey coat sits across the street every evening, writing."
