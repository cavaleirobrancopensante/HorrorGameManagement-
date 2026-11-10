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
##
## PACING. Scares come in two sizes. Small ones (a whisper, a knock, a drone)
## build dread. Big ones (the lights dying, the mirror, the face, a blow, the
## waking) need dread first: at least DREAD_NEEDED small events since the last
## big one, so they always grow out of something. After a big scare there is a
## calm whose length is drawn at random, so you cannot count on it: about one
## to two days at full strength, longer when calmer. The face itself is rarer
## still: two to five days apart. Nothing big on the first day.

## How often the director rolls, in game minutes.
const ROLL_MINUTES := 20.0
const CHANCE_MIN := 0.02
const CHANCE_MAX := 0.10
const DREAD_NEEDED := 2
## Days of calm after a big scare at full strength, before randomness.
const BIG_GAP_DAYS := Vector2(0.8, 1.8)
## Days between faces, before randomness.
const FACE_GAP_DAYS := Vector2(2.0, 5.0)

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
	{"id": "lights_out", "big": true, "side": "demonic", "min": 0.3, "cooldown": 5.0, "stress": 10.0,
		"text": "The lights die. For a moment something stands in the hallway. Then the power comes back, and it is gone."},
	{"id": "mirror", "big": true, "side": "demonic", "min": 0.3, "cooldown": 6.0, "stress": 12.0, "near_mirror": true,
		"text": "In the mirror, someone stands behind you."},
	{"id": "smile", "side": "demonic", "min": 0.35, "cooldown": 8.0, "stress": 8.0, "hatch": true,
		"text": "The customer at the hatch smiles too wide. \"We know what you did.\" Then he is only a man again, asking for ketchup."},
	{"id": "watcher", "side": "demonic", "min": 0.4, "cooldown": 8.0, "stress": 6.0, "night": true, "window": true,
		"text": "Someone is standing across the street, facing your window. It does not move."},
	{"id": "jumpscare", "big": true, "side": "demonic", "min": 0.55, "cooldown": 10.0, "stress": 18.0, "night": true,
		"text": ""},
	{"id": "shove", "big": true, "side": "demonic", "min": 0.8, "cooldown": 16.0, "stress": 15.0, "health": -12.0,
		"text": "Something you cannot see throws you against the counter."},
	# The state ------------------------------------------------------------------
	{"id": "drone", "side": "state", "min": 0.05, "cooldown": 4.0, "stress": 3.0, "window": true,
		"text": "A Civic drone hovers at your window, its lens turning."},
	{"id": "tax", "side": "state", "min": 0.2, "cooldown": 24.0, "stress": 5.0, "money": -12,
		"text": "Civic Link: your business is reassessed as 'faith-affiliated'. Compliance surcharge: 12 credits."},
	{"id": "feeds_seized", "side": "state", "min": 0.25, "cooldown": 16.0, "stress": 5.0,
		"text": "Civic Link: your security cameras have been placed under public supervision. Your feeds are unavailable for the shift."},
	{"id": "inspector", "side": "state", "min": 0.3, "cooldown": 12.0, "stress": 8.0, "hatch": true, "day": true,
		"text": ""},
	{"id": "informant", "side": "state", "min": 0.4, "cooldown": 10.0, "stress": 5.0,
		"text": "The man in the grey coat stands across the street. He is writing something down."},
	{"id": "raid", "side": "state", "big": true, "min": 0.7, "cooldown": 96.0, "stress": 20.0, "night": true, "health": -8.0,
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
	for key in ["dread", "next_big", "next_face", "last_burglary"]:
		if not horror.has(key):
			horror[key] = 0.0


static func def(id: String) -> Dictionary:
	for event: Dictionary in EVENTS:
		if event["id"] == id:
			return event
	return {}


static func is_night(minutes: float) -> bool:
	return Survival.shift_index(minutes) >= 4


## 0 to 1: how strong the horror is right now. For one side, only leaning
## that way counts: the faithful get only the mildest of the demonic.
static func intensity(save: Dictionary, side := "") -> float:
	var signed := float(save["soul"]["horror_lean"])
	var lean := absf(signed)
	if side == "demonic":
		lean = maxf(signed, 0.0)
	elif side == "state":
		lean = maxf(-signed, 0.0)
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
	if intensity(save, event["side"]) < float(event["min"]):
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
	if event.get("window", false) and context.get("shutters_closed", false):
		return false
	if event.get("big", false) and not big_ready(save):
		return false
	if event["id"] == "jumpscare" and now < float(save["horror"]["next_face"]):
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
	# The strongest available events are a little likelier, and a face that is
	# due takes precedence over other big scares.
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
	return (1.0 + float(event["min"])) * (5.0 if event["id"] == "jumpscare" else 1.0)


## Whether a big scare may come now: past the first day, after the calm,
## and with dread built up.
static func big_ready(save: Dictionary) -> bool:
	var horror: Dictionary = save["horror"]
	var now := Survival.now(save)
	if now - Survival.START_MINUTE < Survival.DAY:
		return false
	return now >= float(horror["next_big"]) and int(horror["dread"]) >= DREAD_NEEDED


## Marks a big scare: dread resets, and the next calm is drawn at random.
static func mark_big(save: Dictionary, face: bool, rng: RandomNumberGenerator) -> void:
	var horror: Dictionary = save["horror"]
	var now := Survival.now(save)
	var level := intensity(save)
	horror["dread"] = 0
	var gap := lerpf(BIG_GAP_DAYS.y, BIG_GAP_DAYS.x, level) * rng.randf_range(0.7, 1.6)
	horror["next_big"] = now + gap * Survival.DAY
	if face:
		horror["next_face"] = now + rng.randf_range(FACE_GAP_DAYS.x, FACE_GAP_DAYS.y) * lerpf(1.3, 0.85, level) * Survival.DAY


## Nerve takes the edge off a scare.
static func scare_stress(event: Dictionary, nerve: int) -> float:
	var stress := float(event.get("stress", 0.0))
	return stress * clampf(1.0 - nerve * 0.04, 0.5, 1.0)


## What an event does to you. Returns the text to show ("" when the scene
## itself tells it). Marks the event so its cooldown starts.
static func apply(save: Dictionary, event: Dictionary, nerve := 0, rng: RandomNumberGenerator = null) -> String:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var now := Survival.now(save)
	save["horror"]["last"][event["id"]] = now
	if event.get("big", false):
		mark_big(save, event["id"] == "jumpscare", rng)
	else:
		save["horror"]["dread"] = int(save["horror"]["dread"]) + 1
	Survival.change_need(save, "stress", scare_stress(event, nerve))
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



# The night --------------------------------------------------------------------
# While you sleep: a burglar at the window, or, leaning toward sin, a waking
# you cannot move from. At most one a night.

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
## "paralysis" | "pry_marks", "after": minutes asleep before it happens}.
static func night(save: Dictionary, rng: RandomNumberGenerator, shutters_closed: bool, sleep_minutes: float) -> Dictionary:
	var horror: Dictionary = save["horror"]
	var now := Survival.now(save)
	var after := clampf(sleep_minutes * rng.randf_range(0.3, 0.7), 60.0, maxf(sleep_minutes - 30.0, 60.0))
	var lean := float(save["soul"]["horror_lean"])
	# The waking comes to those leaning toward sin, when a big scare is due.
	if lean > 0.0 and big_ready(save):
		var paralysis := clampf(lean / 50.0, 0.0, 1.0) * 0.45
		if rng.randf() < paralysis:
			return {"id": "paralysis", "after": after}
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


## The waking: you cannot move, and something comes closer. Returns
## {"text", "face"}: face is true when it ends in a face, if one is due.
static func paralysis(save: Dictionary, nerve: int, rng: RandomNumberGenerator) -> Dictionary:
	var event := {"id": "paralysis", "big": true, "stress": 18.0}
	var face := Survival.now(save) >= float(save["horror"]["next_face"])
	mark_big(save, face, rng)
	save["horror"]["last"]["paralysis"] = Survival.now(save)
	Survival.change_need(save, "stress", scare_stress(event, nerve))
	Survival.change_need(save, "tiredness", 12.0)
	return {"face": face, "text": "You wake and cannot move. Something stands at the foot of the bed, and comes closer, and you cannot even pray. Then the room is empty, and your heart will not slow."}
