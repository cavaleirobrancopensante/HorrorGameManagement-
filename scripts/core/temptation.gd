class_name Temptation
extends RefCounted
## Temptations come while you live in the trailer. Each belongs to one of the
## capital sins. Giving in always helps you materially and eases stress, which is
## why it tempts; it goes on your soul's record and pushes the horror toward the
## demonic. Resisting costs stress, more for the sins you struggle with and less
## on a day you received Communion or went to confession.
##
## Stress feeds it: the more stressed you are, the more often you are tempted.

## Chance of a temptation in a game hour, at no stress and at full stress.
const CHANCE_CALM := 0.10
const CHANCE_STRESSED := 0.45
const RESIST_STRESS := 10.0

## effects: money, needs (change), stock (change), minutes (time spent).
## requires: stock needed. hatch: the stand is open. shifts: when it can happen.
const LIST := [
	{
		"id": "change", "sin": "greed",
		"text": "A man paid with a twenty and walked off without his change. He is already halfway down the street.",
		"give": "Keep it", "resist": "Run after him",
		"give_text": "Twelve credits richer. Nobody saw.",
		"resist_text": "You catch him at the corner. He looks at you as if you were mad.",
		"grave": false, "lean": 2,
		"effects": {"money": 12, "needs": {"stress": -6.0}},
		"hatch": true,
	},
	{
		"id": "double_delivery", "sin": "greed",
		"text": "The Civic shop glitched. A pack of patties shows as paid by the depot, not by you. Logistics will never check.",
		"give": "Keep quiet", "resist": "Report the error",
		"give_text": "Ten patties for nothing. The app thanks you for your custom.",
		"resist_text": "You report it. An automated reply thanks you for your honesty, and fines you a processing fee of 2 credits.",
		"grave": true, "lean": 3,
		"effects": {"stock": {"patties": 10}, "needs": {"stress": -6.0}},
		"resist_effects": {"money": -2},
	},
	{
		"id": "second_supper", "sin": "gluttony",
		"text": "The grill smells too good. You already ate, but one more would not hurt. Then another.",
		"give": "Eat two", "resist": "Close the drawer",
		"give_text": "Two hot dogs, standing over the grill. Stock you will have to buy again.",
		"resist_text": "You close the drawer and drink a glass of water instead.",
		"grave": false, "lean": 1,
		"effects": {"stock": {"sausages": -2, "buns": -2}, "needs": {"hunger": -35.0, "stress": -12.0, "tiredness": 6.0}},
		"requires": {"sausages": 2, "buns": 2},
	},
	{
		"id": "stay_in_bed", "sin": "sloth",
		"text": "The alarm goes again. The bed is warm and the hatch can wait. Just two more hours.",
		"give": "Stay in bed", "resist": "Get up",
		"give_text": "You sleep through the morning rush.",
		"resist_text": "You get up. Your eyes sting, but you are on your feet.",
		"grave": false, "lean": 1,
		"effects": {"needs": {"tiredness": -25.0, "stress": -8.0}, "minutes": 120.0},
		"shifts": [0, 1],
	},
	{
		"id": "feed", "sin": "sloth",
		"text": "You meant to pray tonight. The news feed is right there, and it never ends.",
		"give": "Scroll", "resist": "Turn it off and pray",
		"give_text": "An hour gone. You could not say what you watched.",
		"resist_text": "You turn the screen face down and say your prayers, badly but you say them.",
		"grave": false, "lean": 1,
		"effects": {"needs": {"stress": -10.0}, "minutes": 60.0},
		"resist_effects": {"lean": -1},
		"shifts": [3, 4],
	},
	{
		"id": "drunk", "sin": "anger",
		"text": "A drunk spits at the crucifix by the till, laughs, and grabs his hot dog without paying.",
		"give": "Grab his wrist and twist", "resist": "Let him go",
		"give_text": "He drops the credits and runs, holding his arm. Your hands shake for a long time.",
		"resist_text": "You let him go. You pray for him through your teeth.",
		"grave": true, "lean": 4,
		"effects": {"money": 6, "needs": {"stress": -20.0}},
		"resist_effects": {"money": -4},
		"hatch": true,
	},
	{
		"id": "companion", "sin": "lust",
		"text": "The Civic app pushes a 'Companion' stream to your screen. Free tonight, the first one. Nobody would know.",
		"give": "Watch", "resist": "Delete the app",
		"give_text": "Afterwards the trailer feels emptier than before.",
		"resist_text": "You delete it. It reinstalls itself an hour later, as it always does.",
		"grave": true, "lean": 4,
		"effects": {"needs": {"stress": -30.0, "tiredness": 8.0}, "minutes": 30.0},
		"shifts": [4, 5],
	},
	{
		"id": "report", "sin": "envy",
		"text": "The old couple's soup stand two streets over is busier than you. The Civic app pays 15 credits for reports of 'unlicensed vendors'.",
		"give": "Report them", "resist": "Leave them be",
		"give_text": "Fifteen credits. Tomorrow their corner will be empty.",
		"resist_text": "You close the app. Their soup is better than your coffee anyway.",
		"grave": true, "lean": 4,
		"effects": {"money": 15, "needs": {"stress": -8.0}},
	},
	{
		"id": "blogger", "sin": "pride",
		"text": "A food streamer will feature you, if you say on camera that you are the best cook in the city and the kiosk robots serve slop for slaves.",
		"give": "Say it", "resist": "Just talk about the food",
		"give_text": "The clip does well. People come to see the arrogant cook.",
		"resist_text": "You talk about bread and sausages. The streamer cuts most of it.",
		"grave": false, "lean": 2,
		"effects": {"money": 10, "needs": {"stress": -10.0}},
		"hatch": true,
	},
]


static func def(id: String) -> Dictionary:
	for entry: Dictionary in LIST:
		if entry["id"] == id:
			return entry
	return {}


## Shifts counted from the start of the game, so one temptation per shift at most.
static func shift_number(minutes: float) -> int:
	return int(floorf((minutes - Survival.FIRST_SHIFT_MINUTE) / Survival.SHIFT_MINUTES))


static func chance_per_hour(save: Dictionary) -> float:
	return lerpf(CHANCE_CALM, CHANCE_STRESSED, Survival.need(save, "stress") / float(GameData.NEED_MAX))


static func available(save: Dictionary, entry: Dictionary) -> bool:
	var now := Survival.now(save)
	if entry.has("shifts") and not Survival.shift_index(now) in entry["shifts"]:
		return false
	if entry.get("hatch", false) and not bool(save["world"]["hatch_open"]):
		return false
	var requires: Dictionary = entry.get("requires", {})
	for id: String in requires:
		if Survival.stock(save, id) < int(requires[id]):
			return false
	return true


## Rolls for an hour of game time. Returns a temptation, or {} if none comes.
static func roll(save: Dictionary, character: PlayerCharacter, rng: RandomNumberGenerator, hours: float) -> Dictionary:
	var now := Survival.now(save)
	var soul: Dictionary = save["soul"]
	if int(soul["tempted_shift"]) == shift_number(now):
		return {}
	if rng.randf() >= chance_per_hour(save) * hours:
		return {}
	var picked := pick(save, character, rng)
	if not picked.is_empty():
		soul["tempted_shift"] = shift_number(now)
	return picked


## Weighted by how strongly this character is tempted by each sin.
static func pick(save: Dictionary, character: PlayerCharacter, rng: RandomNumberGenerator) -> Dictionary:
	var options: Array = []
	var total := 0.0
	for entry: Dictionary in LIST:
		if not available(save, entry):
			continue
		var weight := maxf(character.temptation_strength(entry["sin"]), 0.2)
		weight *= weight
		options.append([entry, weight])
		total += weight
	if options.is_empty():
		return {}
	var at := rng.randf() * total
	for option: Array in options:
		at -= float(option[1])
		if at <= 0.0:
			return option[0]
	return options[-1][0]


## Applies giving in. Returns {"text", "cause"}; cause is a death or "".
static func give_in(save: Dictionary, entry: Dictionary) -> Dictionary:
	_apply(save, entry["effects"])
	var sin_name: String = GameData.sin_def(entry["sin"])["sin"]
	Soul.record(save, entry["sin"], "%s: %s" % [sin_name, entry["give_text"]], entry["grave"], int(entry["lean"]))
	var cause := ""
	var minutes := float(entry["effects"].get("minutes", 0.0))
	if minutes > 0.0:
		cause = Survival.advance(save, minutes)
	return {"text": entry["give_text"], "cause": cause}


## How much stress resisting costs this character today.
static func resist_cost(save: Dictionary, entry: Dictionary, character: PlayerCharacter) -> float:
	var cost := RESIST_STRESS * character.temptation_strength(entry["sin"])
	if Soul.fortified(save, int(save.get("day", 1))):
		cost *= 0.5
	return cost


static func resist(save: Dictionary, entry: Dictionary, character: PlayerCharacter) -> String:
	Survival.change_need(save, "stress", resist_cost(save, entry, character))
	Survival.change_lean(save, -1)
	_apply(save, entry.get("resist_effects", {}))
	return entry["resist_text"]


static func _apply(save: Dictionary, effects: Dictionary) -> void:
	if effects.has("money"):
		save["survival"]["money"] = maxi(Survival.money(save) + int(effects["money"]), 0)
	var needs: Dictionary = effects.get("needs", {})
	for id: String in needs:
		Survival.change_need(save, id, float(needs[id]))
	var stock: Dictionary = effects.get("stock", {})
	for id: String in stock:
		Survival.add_stock(save, id, int(stock[id]))
	if effects.has("lean"):
		Survival.change_lean(save, int(effects["lean"]))
