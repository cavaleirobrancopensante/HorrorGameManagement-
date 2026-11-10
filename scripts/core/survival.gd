class_name Survival
extends RefCounted
## Time, needs, stock and deliveries. Works on the save dictionary, so the same
## rules run in the game and in the tests.

const MINUTES_PER_SECOND := 1.0
## Unix time of day 1: Saturday 15 January 2050.
const START_UNIX := 2525817600
const START_MINUTE := 20 * 60
const SHIFT_MINUTES := 240.0
const FIRST_SHIFT_MINUTE := 6 * 60
const WAKE_MINUTE := 7 * 60
const DAY := 1440.0
## Change per game hour while awake and while asleep.
const RATES := {"hunger": 3.0, "thirst": 5.0, "tiredness": 4.0, "stress": 1.0}
const SLEEP_RATES := {"hunger": 1.5, "thirst": 2.0, "tiredness": -12.0, "stress": -3.0}
## Health lost per game hour for each need at its limit.
const DAMAGE_PER_HOUR := 8.0


## Fills anything missing, so saves from older versions keep working.
static func ensure(save: Dictionary) -> void:
	if not (save.get("world") is Dictionary):
		save["world"] = {}
	var world: Dictionary = save["world"]
	if not world.has("time"):
		world["time"] = float(START_MINUTE) + (int(save.get("day", 1)) - 1) * DAY
	if not (world.get("stock") is Dictionary):
		world["stock"] = GameData.STARTING_STOCK.duplicate()
	if not (world.get("deliveries") is Array):
		world["deliveries"] = []
	if not (world.get("upgrades") is Dictionary):
		world["upgrades"] = {}
	if not (world.get("dirt") is Dictionary):
		world["dirt"] = {}
	if not world.has("shutters_closed"):
		world["shutters_closed"] = false
	if not (world.get("learned") is Dictionary):
		world["learned"] = {}
	if not (world.get("bottles") is Dictionary):
		world["bottles"] = {}
	for id: String in GameData.STARTING_STOCK:
		if not (world["stock"] as Dictionary).has(id):
			world["stock"][id] = 0 if id in ["sausages", "patties", "buns", "soda", "meals", "coffee", "candles"] else GameData.STARTING_STOCK[id]
	if not world.has("hatch_open"):
		world["hatch_open"] = false
	if not world.has("candle_day"):
		world["candle_day"] = 0
	if not (world.get("mass_days") is Array):
		world["mass_days"] = []
	if not (world.get("notices") is Array):
		world["notices"] = []
	if not (save.get("soul") is Dictionary):
		save["soul"] = {"state_of_grace": true, "horror_lean": 0}
	Soul.ensure(save)
	Horror.ensure(save)
	Combat.ensure(save)
	if not (save.get("survival") is Dictionary):
		var character := PlayerCharacter.from_dict(save.get("character", {}))
		var survival := {
			"money": character.starting_money(),
			"health": character.max_health(),
			"max_health": character.max_health(),
		}
		for need_def: Dictionary in GameData.NEEDS:
			survival[need_def["id"]] = need_def["start"]
		save["survival"] = survival
	save["day"] = day_of(now(save))


# Time -------------------------------------------------------------------------

static func now(save: Dictionary) -> float:
	return float(save["world"]["time"])


static func day_of(minutes: float) -> int:
	return int(floorf(minutes / DAY)) + 1


static func minute_of_day(minutes: float) -> int:
	return int(fposmod(minutes, DAY))


static func hour_of(minutes: float) -> int:
	return int(minute_of_day(minutes) / 60.0)


static func clock_text(minutes: float) -> String:
	var minute := minute_of_day(minutes)
	return "%02d:%02d" % [int(minute / 60.0), minute % 60]


## 0 at night, 1 in daylight, with dawn from 05:00 and dusk from 18:00.
static func daylight(minutes: float) -> float:
	var hour := minute_of_day(minutes) / 60.0
	if hour < 5.0 or hour >= 20.0:
		return 0.0
	if hour < 7.0:
		return (hour - 5.0) / 2.0
	if hour >= 18.0:
		return (20.0 - hour) / 2.0
	return 1.0


# Needs ------------------------------------------------------------------------

static func need(save: Dictionary, id: String) -> float:
	return float(save["survival"].get(id, 0.0))


static func change_need(save: Dictionary, id: String, delta: float) -> void:
	save["survival"][id] = clampf(need(save, id) + delta, 0.0, float(GameData.NEED_MAX))


static func health(save: Dictionary) -> float:
	return float(save["survival"].get("health", 0.0))


static func max_health(save: Dictionary) -> float:
	return float(save["survival"].get("max_health", 1.0))


static func change_health(save: Dictionary, delta: float) -> void:
	save["survival"]["health"] = clampf(health(save) + delta, 0.0, max_health(save))


static func money(save: Dictionary) -> int:
	return int(save["survival"].get("money", 0))


## Moves the clock on. Returns the cause of death, or "" if still alive.
static func advance(save: Dictionary, minutes: float, rates: Dictionary = RATES) -> String:
	var hours := minutes / 60.0
	var day_before := day_of(now(save))
	for id: String in rates:
		change_need(save, id, float(rates[id]) * hours)
	var cause := ""
	if need(save, "thirst") >= GameData.NEED_MAX:
		change_health(save, -DAMAGE_PER_HOUR * hours)
		cause = "Died of thirst."
	if need(save, "hunger") >= GameData.NEED_MAX:
		change_health(save, -DAMAGE_PER_HOUR * hours)
		if cause.is_empty():
			cause = "Starved to death."
	save["world"]["time"] = now(save) + minutes
	save["day"] = day_of(now(save))
	for day in range(day_before, int(save["day"])):
		_end_of_day(save, day)
	if health(save) <= 0.0:
		return cause if not cause.is_empty() else "Died."
	return ""


## Sleep runs to 07:00 when that is 4 to 11 hours away, otherwise 8 hours.
static func sleep_minutes(save: Dictionary) -> float:
	var until_wake := fposmod(WAKE_MINUTE - minute_of_day(now(save)), DAY)
	if until_wake >= 240.0 and until_wake <= 660.0:
		return until_wake
	return 480.0


static func sleep(save: Dictionary) -> String:
	return advance(save, sleep_minutes(save), SLEEP_RATES)


## A Sunday ending without Mass costs the state of grace.
static func _end_of_day(save: Dictionary, day: int) -> void:
	if weekday_of_day(day) != 0 or attended_mass(save, day):
		return
	Soul.record(save, "mass", "You missed Sunday Mass.", true, 3)
	notify(save, "You missed Sunday Mass. You are no longer in a state of grace.")


static func notify(save: Dictionary, text: String) -> void:
	(save["world"]["notices"] as Array).append(text)


## Messages from the rules for the game to show, oldest first.
static func take_notices(save: Dictionary) -> Array:
	var notices: Array = save["world"]["notices"]
	var copy := notices.duplicate()
	notices.clear()
	return copy


# Calendar ---------------------------------------------------------------------

static func date_of_day(day: int) -> Dictionary:
	return Time.get_datetime_dict_from_unix_time(START_UNIX + (day - 1) * 86400)


## 0 is Sunday.
static func weekday_of_day(day: int) -> int:
	return int(date_of_day(day)["weekday"])


static func weekday(minutes: float) -> int:
	return weekday_of_day(day_of(minutes))


static func date_text(minutes: float, long := false) -> String:
	var date := date_of_day(day_of(minutes))
	var weekday_name: String = GameData.WEEKDAYS[int(date["weekday"])]
	var month: String = GameData.MONTHS[int(date["month"]) - 1]
	if long:
		return "%s %d %s %d" % [weekday_name, date["day"], month, date["year"]]
	return "%s %d %s %d" % [weekday_name.left(3), date["day"], month.left(3), date["year"]]


## 0 morning, 1 noon, 2 afternoon, 3 evening, 4 night, 5 dead shift.
static func shift_index(minutes: float) -> int:
	return int(fposmod(minutes - FIRST_SHIFT_MINUTE, DAY) / SHIFT_MINUTES)


static func shift_name(minutes: float) -> String:
	return GameData.SHIFTS[shift_index(minutes)]


## When the current shift ends.
static func shift_end(minutes: float) -> float:
	return minutes - fposmod(minutes - FIRST_SHIFT_MINUTE, SHIFT_MINUTES) + SHIFT_MINUTES


static func shift_hours_text(index: int) -> String:
	var start := (FIRST_SHIFT_MINUTE + index * int(SHIFT_MINUTES)) % int(DAY)
	var end := (start + int(SHIFT_MINUTES)) % int(DAY)
	return "%02d:00 to %02d:00" % [start / 60, end / 60]


# Mass -------------------------------------------------------------------------

## The Sunday that Mass right now would count for, or -1 if there is no Mass.
## Saturday evening is the vigil of Sunday.
static func mass_sunday(minutes: float) -> int:
	var day := day_of(minutes)
	var shift := shift_index(minutes)
	var wd := weekday(minutes)
	if wd == 0 and shift in [0, 1, 3]:
		return day
	if wd == 6 and shift == 3:
		return day + 1
	return -1


static func attended_mass(save: Dictionary, sunday: int) -> bool:
	for day: Variant in save["world"]["mass_days"]:
		if int(day) == sunday:
			return true
	return false


# Spending a shift -------------------------------------------------------------

## Why an activity cannot be chosen now, or "" if it can.
static func activity_blocked(save: Dictionary, id: String) -> String:
	match id:
		"work":
			if stock(save, "sausages") <= 0 or stock(save, "buns") <= 0:
				return "No sausages or rolls in stock."
		"mass":
			var sunday := mass_sunday(now(save))
			if sunday < 0:
				return "No Mass now."
			if attended_mass(save, sunday):
				return "You have already been to Mass for this Sunday."
	return ""


## Spends the rest of the current shift on an activity. Returns
## {"cause": death cause or "", "text": what happened}.
static func spend_shift(save: Dictionary, id: String, character: PlayerCharacter, rng: RandomNumberGenerator) -> Dictionary:
	var start := now(save)
	var minutes := shift_end(start) - start
	var activity := GameData.activity_def(id)
	var shift_label: String = shift_name(start).to_lower()
	var text := ""
	match id:
		"work":
			text = _work(save, minutes, character, rng)
		"rest":
			text = "You rest through the %s." % shift_label
		"sleep":
			text = "You sleep through the %s." % shift_label
		"rosary":
			text = "You pray the rosary at the home altar."
		"mass":
			(save["world"]["mass_days"] as Array).append(mass_sunday(start))
			text = "You hear Mass at St. Brigid's. A state drone followed you there and back."
	if activity.has("lean"):
		change_lean(save, int(activity["lean"]))
	var cause := advance(save, minutes, activity["rates"])
	return {"cause": cause, "text": text}


static func _work(save: Dictionary, minutes: float, character: PlayerCharacter, rng: RandomNumberGenerator) -> String:
	var skill := (character.stat_value("cooking") + character.stat_value("charm") + character.stat_value("business")) / 30.0
	var base: float = GameData.SHIFT_CUSTOMERS[shift_index(now(save))]
	var customers := roundi(base * (minutes / SHIFT_MINUTES) * (0.6 + 0.5 * skill) * rng.randf_range(0.8, 1.2))
	var sold := mini(customers, mini(stock(save, "sausages"), stock(save, "buns")))
	take_stock(save, "sausages", sold)
	take_stock(save, "buns", sold)
	var cans := 0
	for i in sold:
		if rng.randf() < 0.4 and take_stock(save, "soda"):
			cans += 1
	var earned := sold * GameData.HOT_DOG_PRICE + cans * GameData.CAN_PRICE
	save["survival"]["money"] = money(save) + earned
	var text := "You sold %d hot dogs and %d cans for %d credits." % [sold, cans, earned]
	var turned_away := customers - sold
	if turned_away > 0:
		change_need(save, "stress", turned_away * 1.5)
		text += " %d customers left hungry: you ran out of stock." % turned_away
	return text


static func change_lean(save: Dictionary, delta: int) -> void:
	var soul: Dictionary = save["soul"]
	soul["horror_lean"] = clampi(int(soul.get("horror_lean", 0)) + delta, GameData.HORROR_LEAN_MIN, GameData.HORROR_LEAN_MAX)


# Stock ------------------------------------------------------------------------

static func stock(save: Dictionary, id: String) -> int:
	return int(save["world"]["stock"].get(id, 0))


static func add_stock(save: Dictionary, id: String, count: int) -> void:
	save["world"]["stock"][id] = stock(save, id) + count


static func take_stock(save: Dictionary, id: String, count := 1) -> bool:
	if stock(save, id) < count:
		return false
	add_stock(save, id, -count)
	return true


# Shop and deliveries ----------------------------------------------------------

## Drones fly at the start of each shift. An order lands at the start of the
## shift after next, so you have to plan a shift or two ahead.
static func delivery_time(minutes: float) -> float:
	return shift_end(minutes) + SHIFT_MINUTES


static func has_upgrade(save: Dictionary, id: String) -> bool:
	return bool(save["world"]["upgrades"].get(id, false))


## An upgrade you have paid for that has not been carried in yet.
static func upgrade_coming(save: Dictionary, id: String) -> bool:
	for delivery: Dictionary in save["world"]["deliveries"]:
		if (delivery["items"] as Dictionary).has(id):
			return true
	return false


## Pays for one pack, or one upgrade. Orders that land at the same time share
## a drone. Returns "" on success, or what went wrong.
static func order(save: Dictionary, product_id: String) -> String:
	var product := GameData.product_def(product_id)
	if product.is_empty():
		return "That product does not exist."
	var upgrade := not GameData.upgrade_def(product_id).is_empty()
	if upgrade and (has_upgrade(save, product_id) or upgrade_coming(save, product_id)):
		return "You already have that."
	var price: int = product["price"]
	if money(save) < price:
		return "Not enough money."
	save["survival"]["money"] = money(save) - price
	var deliveries: Array = save["world"]["deliveries"]
	var arrive := delivery_time(now(save))
	var pending := {}
	for delivery: Dictionary in deliveries:
		if is_equal_approx(float(delivery["arrive"]), arrive):
			pending = delivery
	if pending.is_empty():
		pending = {"arrive": arrive, "items": {}}
		deliveries.append(pending)
	var items: Dictionary = pending["items"]
	items[product_id] = int(items.get(product_id, 0)) + (1 if upgrade else int(product["units"]))
	return ""


## Deliveries waiting outside the door.
static func arrived(save: Dictionary) -> Array:
	return (save["world"]["deliveries"] as Array).filter(
		func(delivery: Dictionary) -> bool: return float(delivery["arrive"]) <= now(save)
	)


## When the next drone lands, or -1 if nothing is on the way.
static func next_arrival(save: Dictionary) -> float:
	var soonest := -1.0
	for delivery: Dictionary in save["world"]["deliveries"]:
		var arrive := float(delivery["arrive"])
		if arrive > now(save) and (soonest < 0.0 or arrive < soonest):
			soonest = arrive
	return soonest


## Carries every delivery waiting outside into stock. Returns what was added.
static func collect(save: Dictionary) -> Dictionary:
	var gathered := {}
	var remaining := []
	for delivery: Dictionary in save["world"]["deliveries"]:
		if float(delivery["arrive"]) > now(save):
			remaining.append(delivery)
			continue
		var items: Dictionary = delivery["items"]
		for id: String in items:
			gathered[id] = int(gathered.get(id, 0)) + int(items[id])
	save["world"]["deliveries"] = remaining
	for id: String in gathered:
		if GameData.upgrade_def(id).is_empty():
			add_stock(save, id, gathered[id])
		else:
			save["world"]["upgrades"][id] = true
	return gathered


# News -------------------------------------------------------------------------

## Five headlines for the day. Faithfulness brings persecution stories, sin
## brings stranger ones, and a balanced soul gets a little of either.
static func headlines(day: int, lean: int) -> Array[String]:
	var rng := RandomNumberGenerator.new()
	rng.seed = day * 7919 + 13
	var common := _shuffled(GameData.NEWS_COMMON, rng)
	var picked: Array[String] = []
	if lean <= -15:
		picked.append_array(_shuffled(GameData.NEWS_PERSECUTION, rng).slice(0, 2))
		picked.append_array(common.slice(0, 3))
	elif lean >= 15:
		picked.append_array(_shuffled(GameData.NEWS_DEMONIC, rng).slice(0, 2))
		picked.append_array(common.slice(0, 3))
	else:
		var pool: Array = GameData.NEWS_PERSECUTION if rng.randf() < 0.5 else GameData.NEWS_DEMONIC
		picked.append(_shuffled(pool, rng)[0])
		picked.append_array(common.slice(0, 4))
	return picked


static func _shuffled(list: Array, rng: RandomNumberGenerator) -> Array:
	var copy := list.duplicate()
	for i in range(copy.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var held: Variant = copy[i]
		copy[i] = copy[j]
		copy[j] = held
	return copy
