class_name Combat
extends RefCounted
## Weapons, enemies and the encounters that bring them. Pure rules on the save
## dictionary and the character's stats, so they can be tested.
##
## The bat is for whoever gets inside. The slingshot is for everything else:
## through the window, the hatch or the open door at the gang outside, or at
## the drones hunting you. Marksmanship tightens its spread and adds damage;
## Endurance puts weight behind the bat.

const WEAPONS := {
	"bat": {"name": "bat", "range": 1.9, "damage": 30.0, "cooldown": 0.75},
	"slingshot": {"name": "slingshot", "range": 40.0, "damage": 18.0, "cooldown": 0.9},
}
## Holstered, then each weapon in turn.
const CYCLE := ["", "bat", "slingshot"]

const ENEMIES := {
	"thug": {"health": 60.0, "speed": 2.6, "damage": 12.0, "reach": 1.3, "cooldown": 1.3, "loot": [2, 9]},
	"burglar": {"health": 45.0, "speed": 2.8, "damage": 10.0, "reach": 1.3, "cooldown": 1.2, "loot": [0, 0]},
	"shooter": {"health": 50.0, "speed": 2.4, "damage": 8.0, "reach": 14.0, "cooldown": 2.4, "loot": [4, 12]},
	"drone": {"health": 30.0, "speed": 3.4, "damage": 7.0, "reach": 7.0, "cooldown": 1.9, "loot": [0, 0]},
}
## A door takes this much bashing before it gives; a shutter less.
const DOOR_HEALTH := 100.0
const SHUTTER_HEALTH := 60.0
## Enemies that can hurt you from a distance, through any opening they can
## see you through. Closed shutters and a shut hatch take that away from both
## sides, and force them to break in and fight up close.
const RANGED := ["shooter", "drone"]

## Gangs come at night, some nights. The first two days are quiet.
const GANG_CHANCE := 0.06
const GANG_GAP_DAYS := Vector2(3.0, 6.0)
## Drone hunts come for the faithful; a compliance contribution stops them.
const HUNT_GAP_DAYS := Vector2(2.0, 4.0)
const COMPLIANCE_DAYS := 3.0


static func ensure(save: Dictionary) -> void:
	var horror: Dictionary = save["horror"]
	for key in ["next_gang", "next_hunt", "compliance_until"]:
		if not horror.has(key):
			horror[key] = 0.0


static func next(id: String) -> String:
	var at := CYCLE.find(id)
	return CYCLE[(at + 1) % CYCLE.size()]


static func damage(weapon: String, character: PlayerCharacter) -> float:
	var base: float = WEAPONS[weapon]["damage"]
	if weapon == "bat":
		return base + character.stat_value("endurance") * 2.0
	return base + character.stat_value("marksmanship") * 1.5


## Degrees of spread for the slingshot: wide when unskilled, tight when not.
static func spread(character: PlayerCharacter) -> float:
	return lerpf(5.0, 0.6, clampf((character.stat_value("marksmanship") - 1) / 13.0, 0.0, 1.0))


## Stress shakes your aim.
static func aim_spread(character: PlayerCharacter, stress: float) -> float:
	return spread(character) * (1.0 + stress / 100.0 * 0.8)


## Damage you take, softened a little by Endurance.
static func taken(amount: float, character: PlayerCharacter) -> float:
	return amount * clampf(1.0 - character.stat_value("endurance") * 0.03, 0.6, 1.0)


# Encounters -------------------------------------------------------------------

static func compliant(save: Dictionary) -> bool:
	return Survival.now(save) < float(save["horror"]["compliance_until"])


## What the Civic Link asks: more the more faithful you look.
static func compliance_price(save: Dictionary) -> int:
	return 20 + roundi(maxf(-float(save["soul"]["horror_lean"]), 0.0) * 0.8)


## Pays for three days of being left alone. Returns "" or what went wrong.
static func pay_compliance(save: Dictionary) -> String:
	var price := compliance_price(save)
	if Survival.money(save) < price:
		return "Not enough money."
	save["survival"]["money"] = Survival.money(save) - price
	var start := maxf(Survival.now(save), float(save["horror"]["compliance_until"]))
	save["horror"]["compliance_until"] = start + COMPLIANCE_DAYS * Survival.DAY
	return ""


## A gang tonight? Returns the number of thugs, or 0.
static func roll_gang(save: Dictionary, rng: RandomNumberGenerator) -> int:
	var now := Survival.now(save)
	if now - Survival.START_MINUTE < 2.0 * Survival.DAY or not Horror.is_night(now):
		return 0
	if now < float(save["horror"]["next_gang"]):
		return 0
	# Cash and stock draw them; the neon sign does too.
	var chance := GANG_CHANCE + minf(Survival.money(save) / 1500.0, 0.06)
	if Survival.has_upgrade(save, "neon"):
		chance += 0.02
	if rng.randf() >= chance:
		return 0
	save["horror"]["next_gang"] = now + rng.randf_range(GANG_GAP_DAYS.x, GANG_GAP_DAYS.y) * Survival.DAY
	var day := int((now - Survival.START_MINUTE) / Survival.DAY)
	return clampi(2 + day / 6 + rng.randi_range(0, 1), 2, 5)


## Who is in a gang of n: some throw and shoot from range, the rest come in.
static func gang_members(n: int, rng: RandomNumberGenerator) -> Array:
	var members := []
	for i in n:
		members.append("shooter" if i > 0 and rng.randf() < 0.4 else "thug")
	return members


## A drone hunt? Returns the number of drones, or 0.
static func roll_hunt(save: Dictionary, rng: RandomNumberGenerator) -> int:
	var now := Survival.now(save)
	if compliant(save) or now - Survival.START_MINUTE < 2.0 * Survival.DAY:
		return 0
	if now < float(save["horror"]["next_hunt"]):
		return 0
	var level := Horror.intensity(save, "state")
	if level < 0.45 or rng.randf() >= (level - 0.4) * 0.12:
		return 0
	save["horror"]["next_hunt"] = now + rng.randf_range(HUNT_GAP_DAYS.x, HUNT_GAP_DAYS.y) * Survival.DAY
	return clampi(1 + roundi(level * 3.0), 2, 4)


static func loot(kind: String, rng: RandomNumberGenerator) -> int:
	var range_: Array = ENEMIES[kind]["loot"]
	return rng.randi_range(range_[0], range_[1])
