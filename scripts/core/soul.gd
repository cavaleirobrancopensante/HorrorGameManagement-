class_name Soul
extends RefCounted
## The sacraments and the church's hours. Mass, Communion and confession are
## moments of quiet in the game, not mechanics: they give no bonuses, keep no
## meters and take nothing away. Confession is mercy: you are welcomed, and
## the regrets you carried are laid down, with no penalty and no counter.

const PRIEST := Parish.PRIEST


static func ensure(save: Dictionary) -> void:
	if not (save.get("soul") is Dictionary):
		save["soul"] = {}
	var soul: Dictionary = save["soul"]
	# Older saves kept a record of sins and a state of grace; neither is used.
	for old in ["state_of_grace", "sins", "penance", "communion_day", "confession_day", "tempted_shift", "horror_lean"]:
		soul.erase(old)
	if not (soul.get("regrets") is Array):
		soul["regrets"] = []
	Moments.ensure(save)


## Fr. Columba hears confessions in the evening shift every day, and on
## Saturday afternoon too, when he is free and the church is open.
static func confession_open(save: Dictionary, minutes: float) -> bool:
	if not Parish.sacraments_available(save):
		return false
	var shift := Survival.shift_index(minutes)
	return shift == 3 or (Survival.weekday(minutes) == 6 and shift == 2)


## St. Brigid's is open from the morning to the end of the evening shift,
## unless it has been closed.
static func church_open(save: Dictionary, minutes: float) -> bool:
	return not Parish.closed(save) and Survival.shift_index(minutes) <= 3


## What you bring to confession: the regrets you carry, as lines.
static func examination(save: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = []
	for regret: Dictionary in Virtue.regrets(save):
		lines.append(str(regret["text"]))
	return lines


## Confession: the priest welcomes you and absolves you. What you carried is
## laid down. Returns what he says.
static func confess(save: Dictionary) -> String:
	var carried := Virtue.lift_regrets(save)
	if carried == 0:
		return "\"There is always something, even when we cannot name it.\" He absolves you, and asks you to pray for him, which you would have done anyway. You go out into the evening quieter than you came."
	return "He listens to all of it without a sound. Then: \"You came. That is the part that matters.\" He raises his hand over the grille and absolves you, and it is gone, all of it, as if it had been carried out of the box ahead of you. For your penance, a single Hail Mary. You walk out into the evening lighter than you have been for a long time."


## Communion, received or made spiritually: a moment of quiet, nothing more
## to count.
static func communion_text(receive: bool) -> String:
	if receive:
		return "You go up with the others and receive, and go back to the pew, and for a while there is nothing to do but be still."
	return "You stay in the pew while the others go up, and make a spiritual communion, and are still."
