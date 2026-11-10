class_name Horror
extends RefCounted
## The horror director's rules. Which kind of horror comes, how strong, and
## when, from the state of your soul, your nerves and the hour.
##
## The soul's lean decides the kind: toward sin (positive) the demonic, toward
## faith (negative) the state. In between, a little of both. How far you lean,
## how stressed you are and how late it is decide how often and how bad.
## Every event has a level it needs, and a cooldown so it does not repeat.
## Works on the save dictionary, so it can be tested.

## How often the director rolls, in game minutes.
const ROLL_MINUTES := 20.0
const CHANCE_MIN := 0.04
const CHANCE_MAX := 0.30

## min: intensity needed (0 to 1). night: only in the night and dead shifts.
## day: only while the stand could be open (morning to evening).
## hatch: only with the hatch open. near_mirror: only near the bathroom mirror.
## cooldown: game hours before it can happen again.
const EVENTS := [
	# The demonic ----------------------------------------------------------------
	{"id": "whisper", "side": "demonic", "min": 0.05, "cooldown": 3.0, "stress": 4.0,
		"text": "Someone whispers your name, close behind you. Nobody is there."},
	{"id": "knock", "side": "demonic", "min": 0.15, "cooldown": 8.0, "stress": 6.0, "night": true,
		"text": "Three knocks at the door. Slow. When you look, the street is empty."},
	{"id": "camera_shape", "side": "demonic", "min": 0.2, "cooldown": 6.0, "stress": 3.0,
		"text": "Civic Link: motion detected on your street camera."},
	{"id": "lights_out", "side": "demonic", "min": 0.3, "cooldown": 5.0, "stress": 10.0,
		"text": "The lights die. For a moment something stands in the hallway. Then the power comes back, and it is gone."},
	{"id": "mirror", "side": "demonic", "min": 0.3, "cooldown": 6.0, "stress": 12.0, "near_mirror": true,
		"text": "In the mirror, someone stands behind you."},
	{"id": "smile", "side": "demonic", "min": 0.35, "cooldown": 8.0, "stress": 8.0, "hatch": true,
		"text": "The customer at the hatch smiles too wide. \"We know what you did.\" Then he is only a man again, asking for ketchup."},
	{"id": "watcher", "side": "demonic", "min": 0.4, "cooldown": 8.0, "stress": 6.0, "night": true,
		"text": "Someone is standing across the street, facing your window. It does not move."},
	{"id": "jumpscare", "side": "demonic", "min": 0.55, "cooldown": 10.0, "stress": 18.0, "night": true,
		"text": ""},
	{"id": "shove", "side": "demonic", "min": 0.8, "cooldown": 16.0, "stress": 15.0, "health": -12.0,
		"text": "Something you cannot see throws you against the counter."},
	# The state ------------------------------------------------------------------
	{"id": "drone", "side": "state", "min": 0.05, "cooldown": 4.0, "stress": 3.0,
		"text": "A Civic drone hovers at your window, its lens turning."},
	{"id": "tax", "side": "state", "min": 0.2, "cooldown": 24.0, "stress": 5.0, "money": -12,
		"text": "Civic Link: your business is reassessed as 'faith-affiliated'. Compliance surcharge: 12 credits."},
	{"id": "feeds_seized", "side": "state", "min": 0.25, "cooldown": 16.0, "stress": 5.0,
		"text": "Civic Link: your security cameras have been placed under public supervision. Your feeds are unavailable for the shift."},
	{"id": "inspector", "side": "state", "min": 0.3, "cooldown": 12.0, "stress": 8.0, "hatch": true, "day": true,
		"text": ""},
	{"id": "informant", "side": "state", "min": 0.4, "cooldown": 10.0, "stress": 5.0,
		"text": "The man in the grey coat stands across the street. He is writing something down."},
	{"id": "raid", "side": "state", "min": 0.7, "cooldown": 24.0, "stress": 20.0, "night": true, "health": -8.0,
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


static func def(id: String) -> Dictionary:
	for event: Dictionary in EVENTS:
		if event["id"] == id:
			return event
	return {}


static func is_night(minutes: float) -> bool:
	return Survival.shift_index(minutes) >= 4


## 0 to 1: how strong the horror is right now.
static func intensity(save: Dictionary) -> float:
	var lean := absf(float(save["soul"]["horror_lean"]))
	var level := clampf(lean / 50.0, 0.0, 1.0) * 0.6
	level += Survival.need(save, "stress") / float(GameData.NEED_MAX) * 0.25
	if is_night(Survival.now(save)):
		level += 0.15
	return clampf(level, 0.0, 1.0)


## Chance the demonic comes rather than the state: 0 to 1.
static func demonic_weight(save: Dictionary) -> float:
	return clampf(0.5 + float(save["soul"]["horror_lean"]) / 30.0, 0.05, 0.95)


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
	if event.get("near_mirror", false) and not context.get("near_mirror", false):
		return false
	var last := float(save["horror"]["last"].get(event["id"], -100000.0))
	return now - last >= float(event["cooldown"]) * 60.0


## One roll of the director. Returns an event, or {} if nothing happens.
static func roll(save: Dictionary, rng: RandomNumberGenerator, context: Dictionary) -> Dictionary:
	if context.get("in_church", false):
		return {}
	if rng.randf() >= chance(save):
		return {}
	var side := "demonic" if rng.randf() < demonic_weight(save) else "state"
	var options: Array = []
	for event: Dictionary in EVENTS:
		if event["side"] == side and available(save, event, context):
			options.append(event)
	if options.is_empty():
		return {}
	# The strongest available events are a little likelier.
	var total := 0.0
	for event: Dictionary in options:
		total += 1.0 + float(event["min"])
	var at := rng.randf() * total
	for event: Dictionary in options:
		at -= 1.0 + float(event["min"])
		if at <= 0.0:
			return event
	return options[-1]


## What an event does to you. Returns the text to show ("" when the scene
## itself tells it). Marks the event so its cooldown starts.
static func apply(save: Dictionary, event: Dictionary) -> String:
	var now := Survival.now(save)
	save["horror"]["last"][event["id"]] = now
	Survival.change_need(save, "stress", float(event.get("stress", 0.0)))
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
			return raid(save)
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


## Enforcers at the door at night: they take your candles and some of your stock.
static func raid(save: Dictionary) -> String:
	var stock: Dictionary = save["world"]["stock"]
	var taken: PackedStringArray = []
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
