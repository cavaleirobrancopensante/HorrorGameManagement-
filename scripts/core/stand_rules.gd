class_name StandRules
extends RefCounted
## Rules for the food stand: what the items are, how meat cooks, how food is
## put together, what customers order, how they feel, and what they pay.
## Items are plain dictionaries so the rules can be tested without the 3D world.
## Times are in real seconds.

const COOK_SECONDS := 9.0
## Seconds cooked meat stays good before it burns, before skill.
const BURN_BASE := 9.0
const PATIENCE_BASE := 50.0
## The pro griddle cooks faster and forgives more.
const PRO_GRILL_SPEED := 1.35
const PRO_GRILL_WINDOW := 1.5
## Portions in a sauce bottle, and in a large one.
const BOTTLE_SIZE := 15
const LARGE_BOTTLE_SIZE := 40

## Customer mood, 0 to 100. They leave at 0.
const MOOD_START := 80.0
const MOOD_HAPPY := 60.0
const MOOD_ANGRY := 30.0
## The street TV slows how fast waiting wears them down.
const TV_DECAY := 0.65
## What upsets them.
const MOOD_SUBSTITUTE := 20.0
const MOOD_ODD_PLACE := 12.0
const MOOD_WRONG := 8.0
const MOOD_REFUSED := 15.0

const MEATS := ["sausage", "patty"]
const FOODS := ["hot_dog", "burger"]
const SAUCES := ["ketchup", "mustard", "mayo"]
const NAMES := {
	"sausage": "sausage",
	"patty": "burger patty",
	"bun": "bread roll",
	"hot_dog": "hot dog",
	"burger": "burger",
	"can": "can",
	"ketchup": "ketchup bottle",
	"mustard": "mustard bottle",
	"mayo": "mayonnaise bottle",
}
const SAUCE_NAMES := {"ketchup": "ketchup", "mustard": "mustard", "mayo": "mayo"}


static func burn_window(cooking: int, pro := false) -> float:
	return (BURN_BASE + cooking * 0.4) * (PRO_GRILL_WINDOW if pro else 1.0)


static func patience(charm: int) -> float:
	return PATIENCE_BASE + charm * 1.5


static func bottle_size(large: bool) -> int:
	return LARGE_BOTTLE_SIZE if large else BOTTLE_SIZE


## Real seconds between customers arriving in a given shift.
static func spawn_interval(shift: int, skill: float, neon := false) -> float:
	var per_shift: float = GameData.SHIFT_CUSTOMERS[shift] * (0.6 + 0.5 * skill)
	var shift_seconds := Survival.SHIFT_MINUTES / Survival.MINUTES_PER_SECOND
	return shift_seconds / maxf(per_shift, 0.5) * (0.75 if neon else 1.0)


# Items ------------------------------------------------------------------------

## dirty: it has touched the floor or a filthy surface; customers refuse it.
## odd: it sat somewhere food does not belong; customers mind.
static func new_item(kind: String) -> Dictionary:
	var item := {"kind": kind, "cook": 0.0, "burnt": false, "dirty": false, "odd": false}
	for sauce: String in SAUCES:
		item[sauce] = false
	return item


static func is_sauce(item: Dictionary) -> bool:
	return item["kind"] in SAUCES


## "raw", "cooked" or "burnt" for meat; "" for anything else.
static func cook_state(item: Dictionary, cooking: int, pro := false) -> String:
	if not item["kind"] in MEATS:
		return ""
	var seconds := float(item["cook"])
	if seconds < COOK_SECONDS:
		return "raw"
	if seconds < COOK_SECONDS + burn_window(cooking, pro):
		return "cooked"
	return "burnt"


static func sauces_on(item: Dictionary) -> PackedStringArray:
	var list: PackedStringArray = []
	for sauce: String in SAUCES:
		if item.get(sauce, false):
			list.append(SAUCE_NAMES[sauce])
	return list


static func describe(item: Dictionary, cooking: int, pro := false) -> String:
	var kind: String = item["kind"]
	var name: String = NAMES.get(kind, kind)
	var text := name
	if kind in MEATS:
		text = "%s %s" % [cook_state(item, cooking, pro), name]
	elif kind in FOODS:
		var sauces := sauces_on(item)
		text = ("burnt " if item["burnt"] else "") + name
		if not sauces.is_empty():
			text = "%s with %s" % [text, " and ".join(sauces)]
	if item.get("dirty", false):
		text = "dirty " + text
	return text


## Puts added onto base. Returns the new item, or a String saying why not.
## An empty String means the two simply do not go together. Meat and rolls go
## together whichever one you hold.
static func combine(base: Dictionary, added: Dictionary, cooking: int, pro := false) -> Variant:
	var base_kind: String = base["kind"]
	var added_kind: String = added["kind"]
	var meat: Dictionary = {}
	if base_kind == "bun" and added_kind in MEATS:
		meat = added
	elif base_kind in MEATS and added_kind == "bun":
		meat = base
	if not meat.is_empty():
		var state := cook_state(meat, cooking, pro)
		if state == "raw":
			return "Cook it first."
		var food := new_item("hot_dog" if meat["kind"] == "sausage" else "burger")
		food["burnt"] = state == "burnt"
		food["dirty"] = bool(base["dirty"]) or bool(added["dirty"])
		food["odd"] = bool(base["odd"]) or bool(added["odd"])
		return food
	if added_kind in SAUCES:
		var sauce := SAUCE_NAMES[added_kind] as String
		if base_kind in FOODS:
			if base[added_kind]:
				return "It already has %s." % sauce
			var sauced := base.duplicate()
			sauced[added_kind] = true
			return sauced
		if base_kind == "bun" or base_kind in MEATS:
			return "Make the hot dog or burger first."
		return "You can't put %s on that." % sauce
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


## What to do next with what you hold, given what customers are waiting for:
## {"id": the step, "text": what to say}, or {} when there is nothing to say.
## The game shows a step's hint only until you have done that step once.
static func hint(item: Dictionary, orders: Array, cooking: int, pro := false) -> Dictionary:
	var kind: String = item["kind"]
	if item.get("dirty", false):
		return {"id": "bin", "text": "Nobody will eat this now. Throw it in the bin."}
	if kind in SAUCES:
		return {"id": "sauce", "text": "Look at a hot dog or burger to add %s." % SAUCE_NAMES[kind]}
	if kind == "can":
		return {"id": "serve", "text": "Hand it to a customer who wants a can."}
	if kind == "bun":
		return {"id": "assemble", "text": "Look at cooked meat and use it, or put the roll down and add the meat."}
	if kind in MEATS:
		match cook_state(item, cooking, pro):
			"raw":
				return {"id": "grill", "text": "Put it on the grill to cook."}
			"burnt":
				return {"id": "bin", "text": "Burnt. Throw it in the bin."}
			_:
				return {"id": "assemble", "text": "Look at a bread roll and put the meat in."}
	if kind in FOODS:
		if item["burnt"]:
			return {"id": "bin", "text": "Burnt. Nobody will pay for it. Bin it or eat it."}
		var best := {}
		for order: Dictionary in orders:
			if order["food"] != kind:
				continue
			var needed: PackedStringArray = []
			var extra := false
			for sauce: String in SAUCES:
				if order[sauce] and not item[sauce]:
					needed.append(SAUCE_NAMES[sauce])
				elif item[sauce] and not order[sauce]:
					extra = true
			if extra:
				continue
			if needed.is_empty():
				return {"id": "serve", "text": "Give it to the customer who ordered it."}
			best = {"id": "sauce", "text": "Add %s: look at the bottle and use it." % " and ".join(needed)}
		if not best.is_empty():
			return best
		return {"id": "spare", "text": "Nobody is waiting for this one. Put it down anywhere for later."}
	return {}


# Customers --------------------------------------------------------------------

static func random_order(rng: RandomNumberGenerator) -> Dictionary:
	var burger := rng.randf() < 0.4
	return {
		"food": "burger" if burger else "hot_dog",
		"ketchup": rng.randf() < 0.6,
		"mustard": rng.randf() < (0.25 if burger else 0.45),
		"mayo": rng.randf() < (0.45 if burger else 0.12),
		"can": rng.randf() < 0.4,
	}


static func order_text(order: Dictionary) -> String:
	var sauces := sauces_on(order)
	var food: String = NAMES[order["food"]]
	var text := "%s: %s" % [food.left(1).to_upper() + food.substr(1), "plain" if sauces.is_empty() else ", ".join(sauces)]
	if order["can"]:
		text += "\n+ a can"
	return text


## Whether each part of an order can be made right now.
## available: {"hot_dog", "burger", "ketchup", "mustard", "mayo", "can"} -> bool.
static func missing(order: Dictionary, available: Dictionary) -> PackedStringArray:
	var list: PackedStringArray = []
	if not available.get(order["food"], false):
		list.append(NAMES[order["food"]] + "s")
	for sauce: String in SAUCES:
		if order[sauce] and not available.get(sauce, false):
			list.append(SAUCE_NAMES[sauce])
	if order["can"] and not available.get("can", false):
		list.append("cans")
	return list


## What they settle for when told you are out of something, or {} if there is
## nothing they will take and they leave.
static func substitute(order: Dictionary, available: Dictionary) -> Dictionary:
	var changed := order.duplicate()
	if not available.get(order["food"], false):
		var other := "burger" if order["food"] == "hot_dog" else "hot_dog"
		if not available.get(other, false):
			return {}
		changed["food"] = other
	for sauce: String in SAUCES:
		if changed[sauce] and not available.get(sauce, false):
			changed[sauce] = false
	if changed["can"] and not available.get("can", false):
		changed["can"] = false
	return changed


## What a customer says about being handed an item, or "" if they take it.
static func give_problem(order: Dictionary, item: Dictionary, has_food: bool, has_can: bool) -> String:
	var kind: String = item["kind"]
	if item.get("dirty", false):
		return "That's filthy. I'm not touching it."
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


static func start_mood(charm: int) -> float:
	return clampf(MOOD_START + charm * 1.0, 0.0, 100.0)


## Mood lost per real second of waiting.
static func mood_decay(charm: int, tv: bool) -> float:
	return start_mood(charm) / patience(charm) * (TV_DECAY if tv else 1.0)


## "happy", "neutral" or "angry".
static func face(mood: float) -> String:
	if mood >= MOOD_HAPPY:
		return "happy"
	if mood >= MOOD_ANGRY:
		return "neutral"
	return "angry"


## Happier customers tip more; charm helps. Angry ones tip nothing.
static func tip(mood: float, charm: int) -> int:
	if mood < MOOD_ANGRY:
		return 0
	return roundi(clampf(mood / 100.0, 0.0, 1.0) * (1.0 + charm / 8.0) * 3.0)
