class_name Moments
extends RefCounted
## The moments that test you while you live and work in the trailer. Each is
## a real choice: between two goods, or between a hard good and an easy
## failure. The good grows a virtue. The failure never pays: it costs you
## something, brings no profit, and leaves a regret, the way losing your
## temper does. No option is evil-for-gain, and none is grave.
##
## RULES (checked by the tests):
## - A failure never gains money, stock, trust or parish, and never eases a
##   need. Whatever a failure saves, it loses more.
## - A provocation is always personal (an insult to you, your food, your
##   trailer, your pride), never an attack on the faith: holding firm for the
##   faith is never the "failure". Any moment with a failure must not name
##   the faith's symbols (FAITH_WORDS).

## Chance of a moment in a game hour, calm and fully stressed.
const CHANCE_CALM := 0.10
const CHANCE_STRESSED := 0.30

## Options: label, kind ("good" or "failure"), virtue, weight, text, effects
## and, for a failure, regret. Effects: money, stock, needs, minutes, trust,
## parish, attention (the state's), gang (days sooner a gang comes).
## Conditions: hatch (the stand is open with a customer), shifts, requires
## (stock), priest (the priest is free and the church open).
const LIST := [
	{
		"id": "drunk", "hatch": true,
		"text": "A drunk spits on the ground by the hatch. \"Worst joint on the street. You can't even cook a sausage.\" He grabs his hot dog and walks off without paying.",
		"options": [
			{"label": "Let him go", "kind": "good", "virtue": "patience", "weight": 1.2,
				"text": "You let him go, and pray for him through your teeth. Four credits gone. Your hands are steady.",
				"effects": {"money": -4, "needs": {"stress": 4.0}}},
			{"label": "Shout after him", "kind": "failure", "virtue": "patience",
				"text": "You shout things after him you would not say to a dog. He laughs. The woman next in the queue puts her money away and leaves. He still has the hot dog.",
				"regret": "You shouted after the drunk, and the whole street heard you.",
				"effects": {"money": -4, "needs": {"stress": 9.0}, "trust": -3.0}},
		],
	},
	{
		"id": "cold_burger", "hatch": true, "requires": {"patties": 1, "buns": 1},
		"text": "A regular slaps his burger down on the counter. \"Cold. Again. You're getting lazy.\" It was hot when you handed it over.",
		"options": [
			{"label": "Apologise and make another", "kind": "good", "virtue": "patience",
				"text": "You make him another, hotter than the sun. He grunts, which from him is thanks.",
				"effects": {"stock": {"patties": -1, "buns": -1}, "needs": {"stress": 3.0}, "trust": 2.0}},
			{"label": "Tell him to eat somewhere else", "kind": "failure", "virtue": "patience",
				"text": "\"Fine,\" he says, and does. He was here every Tuesday for two years.",
				"regret": "You drove away a regular over a burger.",
				"effects": {"needs": {"stress": 7.0}, "trust": -5.0}},
		],
	},
	{
		"id": "price", "hatch": true,
		"text": "The price board has fallen behind the counter. A tourist with an expensive coat asks what a hot dog costs.",
		"options": [
			{"label": "Tell him the real price", "kind": "good", "virtue": "justice",
				"text": "\"Four credits.\" He looks surprised, and tips you two for the honesty.",
				"effects": {"money": 2, "trust": 2.0}},
			{"label": "Say eight, he'll never know", "kind": "failure", "virtue": "justice",
				"text": "He pays. Then the woman behind him reads the price off your till screen, out loud. He takes his money back and tells the queue, and two of them leave with him.",
				"regret": "You tried to charge a stranger double.",
				"effects": {"money": -8, "needs": {"stress": 6.0}, "trust": -6.0}},
		],
	},
	{
		"id": "change", "hatch": true,
		"text": "A man paid with a twenty and walked off without his change. He is already halfway down the street.",
		"options": [
			{"label": "Run after him", "kind": "good", "virtue": "justice",
				"text": "You catch him at the corner, out of breath. He stares at the coins, then at you, and promises to come back. He does.",
				"effects": {"minutes": 10.0, "needs": {"tiredness": 3.0}, "trust": 3.0}},
			{"label": "Keep serving", "kind": "failure", "virtue": "justice",
				"text": "You tell yourself he will be back. He is not. The twelve credits sit in a corner of the tin, and you cannot make yourself spend them.",
				"regret": "You let a man walk off without his change.",
				"effects": {"needs": {"stress": 5.0}}},
		],
	},
	{
		"id": "hungry_boy", "hatch": true, "requires": {"sausages": 1, "buns": 1},
		"text": "A thin boy has stood by the hatch for ten minutes, watching the grill. When you look at him he asks if you have anything going spare. He has no credits.",
		"options": [
			{"label": "Give him a hot dog", "kind": "good", "virtue": "charity",
				"text": "He eats it in four bites, standing right there, and says thank you with his mouth full. The woman behind him in the queue smiles at you.",
				"effects": {"stock": {"sausages": -1, "buns": -1}, "trust": 2.0, "parish": 0.5}},
			{"label": "Tell him to move along", "kind": "failure", "virtue": "charity",
				"text": "He goes without a word. You see him later, across the street, going through a bin. The woman who saw it all does not come back.",
				"regret": "You sent a hungry boy away from the hatch.",
				"effects": {"needs": {"stress": 7.0}, "trust": -3.0}},
		],
	},
	{
		"id": "widow", "hatch": true,
		"text": "Old Mrs. Duffy counts her coins out on the counter, twice. She is two credits short, and she knows it.",
		"options": [
			{"label": "\"That's right, Mrs. Duffy\"", "kind": "good", "virtue": "charity",
				"text": "She looks at you for a moment, and says nothing, and pats your hand.",
				"effects": {"money": -2, "trust": 1.0}},
			{"label": "\"Bring the rest tomorrow, no rush\"", "kind": "good", "virtue": "justice",
				"text": "She brings it the next morning, wrapped in a twist of paper, with a bun she baked herself.",
				"effects": {"trust": 1.5}},
		],
	},
	{
		"id": "nurses", "shifts": [3],
		"text": "Two night-shift nurses arrive just as you were going to close, grey in the face. \"Are you still open? Please?\"",
		"options": [
			{"label": "Stay open another hour", "kind": "good", "virtue": "charity",
				"text": "You keep the grill on. They eat in silence and leave a tip they cannot afford. You are tired to the bone.",
				"effects": {"money": 9, "minutes": 60.0, "needs": {"tiredness": 8.0}, "trust": 2.0}},
			{"label": "Close, and rest as you planned", "kind": "good", "virtue": "temperance",
				"text": "You tell them about the all-night place on Harbour Street and give them a coffee each for the walk. Then you rest, as you should.",
				"effects": {"needs": {"tiredness": -4.0}, "trust": 1.0}},
		],
	},
	{
		"id": "protection", "shifts": [3, 4],
		"text": "A man in a leather jacket leans on your counter. \"Nice trailer. Be a shame if it burned. Twenty credits a week and nothing happens to it.\"",
		"options": [
			{"label": "Refuse him", "kind": "good", "virtue": "fortitude", "weight": 1.5,
				"text": "\"No.\" Your voice shakes, but it says no. He smiles, and taps the counter twice, and goes. He will be back, with friends.",
				"effects": {"needs": {"stress": 8.0}, "gang": 1.5}},
			{"label": "Pay him", "kind": "failure", "virtue": "fortitude",
				"text": "You pay. He counts it in front of you. \"Same time next week.\" You know that it will not stop at twenty.",
				"regret": "You paid the man in the leather jacket out of fear.",
				"effects": {"money": -20, "needs": {"stress": 9.0}}},
		],
	},
	{
		"id": "kit", "priest": true, "shifts": [0, 1, 2, 3],
		"text": "Father Columba stops by the hatch with a heavy bag. \"They are searching the presbytery again. Could the Mass kit stay somewhere safe for a week?\"",
		"options": [
			{"label": "Hide it in your storage", "kind": "good", "virtue": "fortitude",
				"text": "You put it behind the sauce boxes. If they search the trailer, you will have some explaining to do. He blesses you and goes.",
				"effects": {"attention": 8.0, "parish": 3.0}},
			{"label": "Suggest the Murphys' cellar, where nobody looks", "kind": "good", "virtue": "prudence",
				"text": "He thinks about it, and nods. \"Better than the trailer of a man they already watch.\" It is there by evening.",
				"effects": {"parish": 1.5}},
		],
	},
	{
		"id": "second_supper", "requires": {"sausages": 2, "buns": 2},
		"text": "The grill smells too good. You already ate, but one more would not hurt. Then another.",
		"options": [
			{"label": "Close the drawer", "kind": "good", "virtue": "temperance",
				"text": "You close the drawer and drink a glass of water instead.",
				"effects": {}},
			{"label": "Eat two", "kind": "failure", "virtue": "temperance",
				"text": "Two hot dogs, standing over the grill, too fast. You feel heavy and a little sick, and the stock is gone.",
				"regret": "You ate standing over the grill until you felt sick.",
				"effects": {"stock": {"sausages": -2, "buns": -2}, "needs": {"tiredness": 8.0, "stress": 4.0}}},
		],
	},
	{
		"id": "stay_in_bed", "shifts": [0, 1],
		"text": "The alarm goes again. The bed is warm and the hatch can wait. Just two more hours.",
		"options": [
			{"label": "Get up", "kind": "good", "virtue": "fortitude", "weight": 0.8,
				"text": "You get up. Your eyes sting, but you are on your feet.",
				"effects": {}},
			{"label": "Stay in bed", "kind": "failure", "virtue": "fortitude",
				"text": "You lie there and do not sleep, listening to the regulars try the hatch and walk away.",
				"regret": "You lay in bed while your regulars stood at a closed hatch.",
				"effects": {"minutes": 120.0, "needs": {"stress": 6.0}, "trust": -2.0}},
		],
	},
	{
		"id": "feed", "shifts": [3, 4],
		"text": "You meant to pray tonight. The news feed is right there, and it never ends.",
		"options": [
			{"label": "Turn it off and pray", "kind": "good", "virtue": "temperance",
				"text": "You turn the screen face down and say your prayers, badly, but you say them.",
				"effects": {}},
			{"label": "Scroll", "kind": "failure", "virtue": "temperance",
				"text": "An hour gone. You could not say what you watched, and you feel worse than before.",
				"regret": "You lost the evening to the feed.",
				"effects": {"minutes": 60.0, "needs": {"stress": 6.0, "tiredness": 5.0}}},
		],
	},
	{
		"id": "streamer", "hatch": true,
		"text": "A food streamer will feature you, if you say on camera that you are the best cook in the city and the kiosk workers serve slop.",
		"options": [
			{"label": "Just talk about the food", "kind": "good", "virtue": "temperance",
				"text": "You talk about bread and sausages and your grandmother's mustard. The streamer cuts most of it. A few people come by because of what was left.",
				"effects": {"trust": 2.0}},
			{"label": "Say it", "kind": "failure", "virtue": "temperance",
				"text": "The clip spreads, but not the way you hoped. People come to jeer at the arrogant cook, and the kiosk girl from the corner stops saying hello.",
				"regret": "You boasted on camera and sneered at the kiosk workers.",
				"effects": {"needs": {"stress": 6.0}, "trust": -6.0}},
		],
	},
]

## Words a moment with a failure must never use: holding firm for the faith
## must never be the failure.
const FAITH_WORDS := ["crucifix", "cross", "rosary", "altar", "church", "faith", "priest", "mass", "jesus", "christ", "mary", "saint", "bible", "catholic", "holy"]


static func def(id: String) -> Dictionary:
	for entry: Dictionary in LIST:
		if entry["id"] == id:
			return entry
	return {}


static func ensure(save: Dictionary) -> void:
	if not save["soul"].has("moment_shift"):
		save["soul"]["moment_shift"] = -1


## Shifts counted from the start of the game, so one moment per shift at most.
static func shift_number(minutes: float) -> int:
	return int(floorf((minutes - Survival.FIRST_SHIFT_MINUTE) / Survival.SHIFT_MINUTES))


static func chance_per_hour(save: Dictionary) -> float:
	return lerpf(CHANCE_CALM, CHANCE_STRESSED, Survival.need(save, "stress") / float(GameData.NEED_MAX))


static func available(save: Dictionary, entry: Dictionary, customers := true) -> bool:
	var now := Survival.now(save)
	if entry.has("shifts") and not Survival.shift_index(now) in entry["shifts"]:
		return false
	if entry.get("hatch", false) and not (bool(save["world"]["hatch_open"]) and customers):
		return false
	if entry.get("priest", false) and not Parish.sacraments_available(save):
		return false
	var requires: Dictionary = entry.get("requires", {})
	for id: String in requires:
		if Survival.stock(save, id) < int(requires[id]):
			return false
	return true


## Rolls for an hour of game time. Returns a moment, or {} if none comes.
static func roll(save: Dictionary, rng: RandomNumberGenerator, hours: float, customers := true) -> Dictionary:
	var now := Survival.now(save)
	if int(save["soul"]["moment_shift"]) == shift_number(now):
		return {}
	if rng.randf() >= chance_per_hour(save) * hours:
		return {}
	var options: Array = []
	for entry: Dictionary in LIST:
		if available(save, entry, customers):
			options.append(entry)
	if options.is_empty():
		return {}
	save["soul"]["moment_shift"] = shift_number(now)
	return options[rng.randi_range(0, options.size() - 1)]


## Applies a choice. Returns {"text", "growth" (a line or ""), "cause"}.
static func choose(save: Dictionary, option: Dictionary, character: PlayerCharacter) -> Dictionary:
	var effects: Dictionary = option.get("effects", {})
	var growth := ""
	if option["kind"] == "good":
		growth = Virtue.act(save, option["virtue"], character, float(option.get("weight", 1.0)))
	else:
		Virtue.fail(save, option["virtue"], option["regret"])
	_apply(save, effects)
	var cause := ""
	var minutes := float(effects.get("minutes", 0.0))
	if minutes > 0.0:
		cause = Survival.advance(save, minutes)
	return {"text": option["text"], "growth": growth, "cause": cause}


static func _apply(save: Dictionary, effects: Dictionary) -> void:
	if effects.has("money"):
		save["survival"]["money"] = maxi(Survival.money(save) + int(effects["money"]), 0)
	var needs: Dictionary = effects.get("needs", {})
	for id: String in needs:
		var amount := float(needs[id])
		if id == "stress" and amount > 0.0:
			amount = Virtue.insult_stress(save, amount)
		Survival.change_need(save, id, amount)
	var stock: Dictionary = effects.get("stock", {})
	for id: String in stock:
		Survival.add_stock(save, id, int(stock[id]))
	if effects.has("trust"):
		Life.change_trust(save, float(effects["trust"]))
	if effects.has("parish"):
		Parish.change(save, float(effects["parish"]) * Virtue.charity_factor(save))
	if effects.has("attention"):
		Horror.notice(save, float(effects["attention"]))
	if effects.has("gang"):
		var horror: Dictionary = save["horror"]
		horror["next_gang"] = minf(float(horror.get("next_gang", 0.0)), Survival.now(save) + float(effects["gang"]) * Survival.DAY)
