class_name StandRules
extends RefCounted
## Rules for the food stand: what the items are, how meat cooks, how food is
## put together, what customers order, and what they pay. Items are plain
## dictionaries so the rules can be tested without the 3D world.
## Times are in real seconds.

const COOK_SECONDS := 9.0
## Seconds cooked meat stays good before it burns, before skill.
const BURN_BASE := 9.0
const PATIENCE_BASE := 45.0

const MEATS := ["sausage", "patty"]
const FOODS := ["hot_dog", "burger"]
const SAUCES := ["ketchup", "mustard"]
const NAMES := {
	"sausage": "sausage",
	"patty": "burger patty",
	"bun": "bread roll",
	"hot_dog": "hot dog",
	"burger": "burger",
	"can": "can",
	"ketchup": "ketchup bottle",
	"mustard": "mustard bottle",
}


static func burn_window(cooking: int) -> float:
	return BURN_BASE + cooking * 0.4


static func patience(charm: int) -> float:
	return PATIENCE_BASE + charm * 1.5


## Real seconds between customers arriving in a given shift.
static func spawn_interval(shift: int, skill: float) -> float:
	var per_shift: float = GameData.SHIFT_CUSTOMERS[shift] * (0.6 + 0.5 * skill)
	var shift_seconds := Survival.SHIFT_MINUTES / Survival.MINUTES_PER_SECOND
	return shift_seconds / maxf(per_shift, 0.5)


# Items ------------------------------------------------------------------------

static func new_item(kind: String) -> Dictionary:
	return {"kind": kind, "cook": 0.0, "ketchup": false, "mustard": false, "burnt": false}


## "raw", "cooked" or "burnt" for meat; "" for anything else.
static func cook_state(item: Dictionary, cooking: int) -> String:
	if not item["kind"] in MEATS:
		return ""
	var seconds := float(item["cook"])
	if seconds < COOK_SECONDS:
		return "raw"
	if seconds < COOK_SECONDS + burn_window(cooking):
		return "cooked"
	return "burnt"


static func describe(item: Dictionary, cooking: int) -> String:
	var kind: String = item["kind"]
	var name: String = NAMES.get(kind, kind)
	if kind in MEATS:
		return "%s %s" % [cook_state(item, cooking), name]
	if kind in FOODS:
		var sauces: PackedStringArray = []
		for sauce: String in SAUCES:
			if item[sauce]:
				sauces.append(sauce)
		var text := ("burnt " if item["burnt"] else "") + name
		return text if sauces.is_empty() else "%s with %s" % [text, " and ".join(sauces)]
	return name


## Puts added onto base. Returns the new item, or a String saying why not.
## An empty String means the two simply do not go together.
static func combine(base: Dictionary, added: Dictionary, cooking: int) -> Variant:
	var base_kind: String = base["kind"]
	var added_kind: String = added["kind"]
	if base_kind == "bun" and added_kind in MEATS:
		var state := cook_state(added, cooking)
		if state == "raw":
			return "Cook it first."
		var food := new_item("hot_dog" if added_kind == "sausage" else "burger")
		food["burnt"] = state == "burnt"
		return food
	if added_kind in SAUCES:
		if base_kind in FOODS:
			if base[added_kind]:
				return "It already has %s." % added_kind
			var sauced := base.duplicate()
			sauced[added_kind] = true
			return sauced
		if base_kind == "bun":
			return "Put the meat in first."
		return "You can't put sauce on that."
	return ""


## Hunger and thirst change for eating or drinking an item, plus what to say.
## An empty dictionary means it cannot be eaten.
static func eat_effect(item: Dictionary, cooking: int) -> Dictionary:
	match item["kind"]:
		"can":
			return {"thirst": -30.0, "stress": -3.0, "text": "You drink a can of your own stock."}
		"bun":
			return {"hunger": -8.0, "text": "You eat a dry bread roll."}
		"hot_dog", "burger":
			if item["burnt"]:
				return {"hunger": -20.0, "stress": 2.0, "text": "You eat it anyway. It tastes of ash."}
			return {"hunger": -30.0, "stress": -4.0, "text": "You eat the %s meant for a customer." % NAMES[item["kind"]]}
		"sausage", "patty":
			match cook_state(item, cooking):
				"raw":
					return {"text": "You can't eat that raw."}
				"burnt":
					return {"hunger": -12.0, "stress": 2.0, "text": "You eat it anyway. It tastes of ash."}
				_:
					return {"hunger": -18.0, "text": "You eat it straight off the grill."}
	return {}


# Customers --------------------------------------------------------------------

static func random_order(rng: RandomNumberGenerator) -> Dictionary:
	return {
		"food": "burger" if rng.randf() < 0.4 else "hot_dog",
		"ketchup": rng.randf() < 0.6,
		"mustard": rng.randf() < 0.45,
		"can": rng.randf() < 0.4,
	}


static func order_text(order: Dictionary) -> String:
	var sauces: PackedStringArray = []
	for sauce: String in SAUCES:
		if order[sauce]:
			sauces.append(sauce)
	var food: String = NAMES[order["food"]]
	var text := "%s: %s" % [food.left(1).to_upper() + food.substr(1), "plain" if sauces.is_empty() else ", ".join(sauces)]
	if order["can"]:
		text += "\n+ a can"
	return text


## What a customer says about being handed an item, or "" if they take it.
static func give_problem(order: Dictionary, item: Dictionary, has_food: bool, has_can: bool) -> String:
	var kind: String = item["kind"]
	if kind == "can":
		if not order["can"]:
			return "I didn't ask for a can."
		return "I already have a can." if has_can else ""
	if kind in FOODS:
		if has_food:
			return "I already have my food."
		if item["burnt"]:
			return "This is burnt!"
		if kind != order["food"]:
			return "I wanted a %s." % NAMES[order["food"]]
		for sauce: String in SAUCES:
			if item[sauce] != order[sauce]:
				return "That's not what I asked for."
		return ""
	return "What am I meant to do with that?"


static func price(order: Dictionary) -> int:
	var food: int = GameData.BURGER_PRICE if order["food"] == "burger" else GameData.HOT_DOG_PRICE
	return food + (GameData.CAN_PRICE if order["can"] else 0)


## Faster service and more charm earn bigger tips.
static func tip(patience_left: float, charm: int) -> int:
	return roundi(clampf(patience_left, 0.0, 1.0) * (1.0 + charm / 8.0) * 2.0)
