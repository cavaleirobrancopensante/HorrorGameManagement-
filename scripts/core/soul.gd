class_name Soul
extends RefCounted
## Sin, confession, penance and Communion. Works on the save dictionary, like
## Survival, so the same rules run in the game and in the tests.
##
## Grave sins cost the state of grace. A full confession restores it. Holding a
## grave sin back makes the confession a bad one: nothing is forgiven, and it
## adds sacrilege. Communion in a state of grace strengthens you against
## temptation for the day; received in mortal sin it is another sacrilege.

const PRIEST := "Father Columba"
const SACRILEGE_LEAN := 8
const CONFESSION_LEAN := -4
const COMMUNION_LEAN := -3
const PENANCE_LEAN := -1


static func ensure(save: Dictionary) -> void:
	var soul: Dictionary = save["soul"]
	if not soul.has("state_of_grace"):
		soul["state_of_grace"] = true
	if not soul.has("horror_lean"):
		soul["horror_lean"] = 0
	if not (soul.get("sins") is Array):
		soul["sins"] = []
	if not soul.has("penance"):
		soul["penance"] = false
	if not soul.has("communion_day"):
		soul["communion_day"] = 0
	if not soul.has("confession_day"):
		soul["confession_day"] = 0
	if not soul.has("tempted_shift"):
		soul["tempted_shift"] = -1


static func in_grace(save: Dictionary) -> bool:
	return bool(save["soul"]["state_of_grace"])


static func sins(save: Dictionary) -> Array:
	return save["soul"]["sins"]


static func has_grave(save: Dictionary) -> bool:
	for entry: Dictionary in sins(save):
		if entry["grave"]:
			return true
	return false


## Remembers a sin until it is confessed. Grave matter costs the state of grace.
static func record(save: Dictionary, sin_id: String, text: String, grave: bool, lean: int) -> void:
	sins(save).append({"sin": sin_id, "text": text, "grave": grave, "day": int(save.get("day", 1))})
	if grave:
		save["soul"]["state_of_grace"] = false
	Survival.change_lean(save, lean)


## Fortified today by Communion or a good confession: resisting costs less.
static func fortified(save: Dictionary, day: int) -> bool:
	var soul: Dictionary = save["soul"]
	return int(soul["communion_day"]) == day or int(soul["confession_day"]) == day


# Confession -------------------------------------------------------------------

## Fr. Columba hears confessions in the evening shift every day, and on
## Saturday afternoon too.
static func confession_open(minutes: float) -> bool:
	var shift := Survival.shift_index(minutes)
	return shift == 3 or (Survival.weekday(minutes) == 6 and shift == 2)


## St. Brigid's is open from the morning to the end of the evening shift.
static func church_open(minutes: float) -> bool:
	return Survival.shift_index(minutes) <= 3


## What you would confess, worst first, as lines for the screen.
static func examination(save: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = []
	for grave in [true, false]:
		for entry: Dictionary in sins(save):
			if bool(entry["grave"]) == grave:
				lines.append(("Grave: " if grave else "") + str(entry["text"]))
	return lines


## full: everything is told. Otherwise the worst sin is held back out of shame.
## Returns what the priest says and what happens.
static func confess(save: Dictionary, full: bool) -> String:
	var soul: Dictionary = save["soul"]
	var day := int(save.get("day", 1))
	var hidden_grave := not full and has_grave(save)
	if hidden_grave:
		record(save, "sacrilege", "A bad confession: you held back a grave sin.", true, SACRILEGE_LEAN)
		Survival.change_need(save, "stress", 10.0)
		return "%s gives you absolution. The words slide off you. You knew what you left out, and so does something else." % PRIEST
	var had_sins := not sins(save).is_empty()
	sins(save).clear()
	soul["state_of_grace"] = true
	soul["confession_day"] = day
	Survival.change_lean(save, CONFESSION_LEAN)
	Survival.change_need(save, "stress", -25.0)
	if had_sins:
		soul["penance"] = true
		return "\"For your penance, pray once before the Blessed Sacrament or at your altar at home.\" %s raises his hand and absolves you. You walk out lighter." % PRIEST
	return "\"Go in peace.\" There was little to tell, but you leave lighter all the same."


## Prayer finishes a penance you were given. Returns true if it did.
static func do_penance(save: Dictionary) -> bool:
	var soul: Dictionary = save["soul"]
	if not bool(soul["penance"]):
		return false
	soul["penance"] = false
	Survival.change_lean(save, PENANCE_LEAN)
	return true


# Communion --------------------------------------------------------------------

static func receive_communion(save: Dictionary) -> String:
	var day := int(save.get("day", 1))
	if not in_grace(save):
		record(save, "sacrilege", "You received Communion in mortal sin.", true, SACRILEGE_LEAN)
		Survival.change_need(save, "stress", 12.0)
		return "You receive. It sits in your mouth like ash. You should have gone to confession first."
	save["soul"]["communion_day"] = day
	Survival.change_lean(save, COMMUNION_LEAN)
	Survival.change_need(save, "stress", -15.0)
	return "You receive Communion. For the rest of the day, temptation has less hold on you."


static func spiritual_communion(save: Dictionary) -> String:
	Survival.change_need(save, "stress", -5.0)
	return "You stay in the pew and make a spiritual communion. Confession first, then the altar."
