class_name StandRules
extends RefCounted
## Rules for serving at the hatch: orders, cooking times, patience and pay.
## Times are in real seconds.

const GRILL_SLOTS := 3
const COOK_SECONDS := 9.0
## Seconds a cooked sausage stays good before it burns, before skill.
const BURN_BASE := 9.0
const PATIENCE_BASE := 45.0


static func burn_window(cooking: int) -> float:
	return BURN_BASE + cooking * 0.4


static func patience(charm: int) -> float:
	return PATIENCE_BASE + charm * 1.5


## Real seconds between customers arriving in a given shift.
static func spawn_interval(shift: int, skill: float) -> float:
	var per_shift: float = GameData.SHIFT_CUSTOMERS[shift] * (0.6 + 0.5 * skill)
	var shift_seconds := Survival.SHIFT_MINUTES / Survival.MINUTES_PER_SECOND
	return shift_seconds / maxf(per_shift, 0.5)


static func random_order(rng: RandomNumberGenerator) -> Dictionary:
	return {"ketchup": rng.randf() < 0.6, "mustard": rng.randf() < 0.45, "can": rng.randf() < 0.4}


static func order_text(order: Dictionary) -> String:
	var sauces: PackedStringArray = []
	if order["ketchup"]:
		sauces.append("ketchup")
	if order["mustard"]:
		sauces.append("mustard")
	var text := "Plain hot dog" if sauces.is_empty() else "Hot dog with %s" % " and ".join(sauces)
	if order["can"]:
		text += "\nand a can"
	return text


static func empty_tray() -> Dictionary:
	return {"bun": false, "sausage": false, "ketchup": false, "mustard": false, "can": false}


static func tray_text(tray: Dictionary) -> String:
	if not tray["bun"] and not tray["can"]:
		return "Empty tray"
	var parts: PackedStringArray = []
	if tray["bun"]:
		parts.append("Bun")
	if tray["sausage"]:
		parts.append("sausage")
	if tray["ketchup"]:
		parts.append("ketchup")
	if tray["mustard"]:
		parts.append("mustard")
	if tray["can"]:
		parts.append("a can")
	return ", ".join(parts)


## What is wrong with the tray for this order, or "" when it is right.
static func problem(order: Dictionary, tray: Dictionary) -> String:
	if not tray["bun"] or not tray["sausage"]:
		return "That's not a hot dog yet."
	if tray["ketchup"] != order["ketchup"] or tray["mustard"] != order["mustard"]:
		return "That's not what I asked for."
	if tray["can"] != order["can"]:
		return "I wanted a can." if order["can"] else "I didn't ask for a can."
	return ""


static func price(order: Dictionary) -> int:
	return GameData.HOT_DOG_PRICE + (GameData.CAN_PRICE if order["can"] else 0)


## Faster service and more charm earn bigger tips.
static func tip(patience_left: float, charm: int) -> int:
	return roundi(clampf(patience_left, 0.0, 1.0) * (1.0 + charm / 8.0) * 2.0)
