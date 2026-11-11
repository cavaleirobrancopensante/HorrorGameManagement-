class_name GameData
extends RefCounted
## All character-creation rules live here, so balance can be changed in one file.

const BASE_STAT := 5
const FREE_POINTS := 6
const MAX_FREE_PER_STAT := 3
## Struggles: the virtues that come hard. At least one, at most this many.
const MAX_STRUGGLES := 2

## Survival. Needs run from 0 (fine) to 100 (critical).
const NEEDS := [
	{"id": "hunger", "name": "Hunger", "start": 15},
	{"id": "thirst", "name": "Thirst", "start": 15},
	{"id": "tiredness", "name": "Tiredness", "start": 10},
	{"id": "stress", "name": "Stress", "start": 10},
]
const NEED_MAX := 100
const HEALTH_BASE := 60
const HEALTH_PER_ENDURANCE := 4
const MONEY_BASE := 40
const MONEY_PER_BUSINESS := 3

## Calendar. Day 1 is Saturday 15 January 2050.
const WEEKDAYS := ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
const MONTHS := ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
## Six four-hour shifts, starting at 06:00.
const SHIFTS := ["Morning", "Noon", "Afternoon", "Evening", "Night", "Dead shift"]
## Customers in a full shift at the stand, before skills.
const SHIFT_CUSTOMERS := [6, 12, 8, 12, 5, 2]
const HOT_DOG_PRICE := 4
const BURGER_PRICE := 6
const CAN_PRICE := 2

## What a shift can be spent on. Rates are per game hour, like the awake rates.
const ACTIVITIES := [
	{
		"id": "work", "name": "Work the stand",
		"desc": "Serve through the hatch, using your stock.",
		"rates": {"hunger": 3.0, "thirst": 4.5, "tiredness": 4.0, "stress": 2.5},
	},
	{
		"id": "rest", "name": "Rest at home",
		"desc": "Sit down, read, let the day go by.",
		"rates": {"hunger": 2.0, "thirst": 3.0, "tiredness": -3.0, "stress": -3.0},
	},
	{
		"id": "sleep", "name": "Sleep",
		"desc": "Sleep through the shift.",
		"rates": {"hunger": 1.5, "thirst": 2.0, "tiredness": -12.0, "stress": -3.0},
	},
	{
		"id": "rosary", "name": "Pray the rosary",
		"desc": "At the home altar.",
		"rates": {"hunger": 2.0, "thirst": 3.0, "tiredness": 1.0, "stress": -3.0},
	},
	{
		"id": "mass", "name": "Go to Mass",
		"desc": "At St. Brigid's, across the city.",
		"rates": {"hunger": 2.0, "thirst": 3.0, "tiredness": 1.5, "stress": -3.0},
	},
]

## Shop. Units are what one order adds to your stock.
const PRODUCTS := [
	{"id": "sausages", "name": "Sausages", "pack": "Pack of 10", "units": 10, "price": 12, "desc": "For the grill."},
	{"id": "patties", "name": "Burger patties", "pack": "Pack of 10", "units": 10, "price": 15, "desc": "For the grill."},
	{"id": "buns", "name": "Bread rolls", "pack": "Pack of 10", "units": 10, "price": 6, "desc": "For the grill."},
	{"id": "soda", "name": "Fizzy drinks", "pack": "Case of 12 cans", "units": 12, "price": 10, "desc": "To sell, or to drink."},
	{"id": "meals", "name": "Ready meals", "pack": "Pack of 3", "units": 3, "price": 9, "desc": "Your own food. Kept in the fridge."},
	{"id": "coffee", "name": "Coffee", "pack": "Bag for 10 cups", "units": 10, "price": 5, "desc": "Keeps you awake."},
	{"id": "ketchup", "name": "Ketchup refill", "pack": "2 refills", "units": 2, "price": 4, "desc": "Fills the ketchup bottle."},
	{"id": "mustard", "name": "Mustard refill", "pack": "2 refills", "units": 2, "price": 4, "desc": "Fills the mustard bottle."},
	{"id": "mayo", "name": "Mayonnaise refill", "pack": "2 refills", "units": 2, "price": 5, "desc": "Fills the mayonnaise bottle."},
	{"id": "cleaner", "name": "Cleaning spray", "pack": "Bottle for 20 wipes", "units": 20, "price": 5, "desc": "Customers refuse food from a filthy counter."},
	{"id": "candles", "name": "Candles", "pack": "Pack of 3", "units": 3, "price": 4, "desc": "For prayer at home."},
	{"id": "shot", "name": "Steel shot", "pack": "Bag of 20", "units": 20, "price": 3, "desc": "Ammunition for the slingshot."},
	{"id": "bandages", "name": "Bandages", "pack": "Box of 3", "units": 3, "price": 6, "desc": "For the first aid box in the bathroom. Each heals a wound."},
]
const STARTING_STOCK := {
	"sausages": 12, "patties": 8, "buns": 18, "soda": 8, "meals": 2, "coffee": 3, "candles": 1,
	"ketchup": 1, "mustard": 1, "mayo": 1, "cleaner": 10, "shot": 15, "bandages": 2,
}

## Bought once, delivered like stock, installed when you carry them in.
const UPGRADES := [
	{"id": "tv", "name": "Street TV", "price": 60, "desc": "A screen under the awning. Customers lose patience a third slower."},
	{"id": "grill", "name": "Pro griddle", "price": 80, "desc": "Cooks faster, and cooked meat takes longer to burn."},
	{"id": "bottles", "name": "Large sauce bottles", "price": 25, "desc": "Bottles hold 40 portions instead of 15."},
	{"id": "neon", "name": "Neon sign", "price": 45, "desc": "Seen from the end of the street. More customers come."},
]

## State news on the computer. Which pool feeds the day's headlines depends on
## where the horror leans.
const NEWS_COMMON := [
	"Consolidated Logistics: drones now reach every registered address.",
	"Kitchen robots cut fast food wages for a third year.",
	"Ministry of Harmony: citizens with nothing to hide have nothing to fear.",
	"Civic Scores will now update every hour.",
	"Night curfew extended across the eastern districts.",
	"Street food licence fees rise again.",
	"AI clerks replace the last staffed town hall.",
	"Power cuts expected across the city tonight.",
	"New cameras fitted to every second lamp post.",
	"Food prices up nine percent since spring.",
	"Unemployment reaches another record.",
	"Score bonus for citizens who report suspicious neighbours.",
]
const NEWS_PERSECUTION := [
	"Unregistered religious gatherings to be fined from Monday.",
	"Ministry asks citizens to report 'extremist' prayer groups.",
	"St. Brigid's parish placed under review by the Harmony Office.",
	"Priest questioned over a Sunday homily on marriage.",
	"Inspectors to visit vendors who refuse the Civic app.",
	"Parishes that reject the new guidelines lose tax relief.",
	"Religious symbols in shop windows to be reviewed.",
	"Score penalty for regular church attendance announced.",
]
const STATS := [
	{"id": "cooking", "name": "Cooking", "desc": "Better food brings more customers."},
	{"id": "business", "name": "Business", "desc": "Better prices, margins and deals."},
	{"id": "charm", "name": "Charm", "desc": "Tips, gossip, talking your way out."},
	{"id": "marksmanship", "name": "Marksmanship", "desc": "Steadier aim, faster reloads."},
	{"id": "endurance", "name": "Endurance", "desc": "More health, longer shifts."},
	{"id": "nerve", "name": "Nerve", "desc": "Stress builds slower. Scares hit softer."},
	{"id": "vigilance", "name": "Vigilance", "desc": "Spot spies and thieves sooner."},
]

## A temperament gives natural abilities, one virtue that comes easily, and
## one that usually comes hard (offered first as a struggle).
const TEMPERAMENTS := [
	{
		"id": "choleric",
		"name": "Choleric",
		"tagline": "Quick to act, quick to command.",
		"stats": {"marksmanship": 3, "business": 2, "nerve": 1, "charm": -2},
		"gift": "fortitude",
		"hard": "patience",
	},
	{
		"id": "melancholic",
		"name": "Melancholic",
		"tagline": "Deep, exacting, slow to forgive itself.",
		"stats": {"cooking": 3, "vigilance": 2, "business": 1, "charm": -1, "nerve": -1},
		"gift": "prudence",
		"hard": "charity",
	},
	{
		"id": "sanguine",
		"name": "Sanguine",
		"tagline": "Warm, quick to laugh, quick to forget.",
		"stats": {"charm": 3, "endurance": 2, "business": 1, "vigilance": -2},
		"gift": "charity",
		"hard": "temperance",
	},
	{
		"id": "phlegmatic",
		"name": "Phlegmatic",
		"tagline": "Steady, gentle, hard to move.",
		"stats": {"nerve": 3, "endurance": 2, "cooking": 1, "business": -2},
		"gift": "patience",
		"hard": "fortitude",
	},
]

## The virtues the moral life is built on. Each grows by habit: every act
## makes the next one easier. What a virtue gives is that ease, never power
## over others: effect says what it changes in the game.
const VIRTUES := [
	{"id": "patience", "name": "Patience", "desc": "Bearing insults, delays and other people's bad days without striking back.",
		"effect": "Insults and long waits cost you less stress."},
	{"id": "justice", "name": "Honesty", "desc": "Giving everyone their due: the right price, the right change, the truth.",
		"effect": "People trust you sooner: more regulars, better tips."},
	{"id": "charity", "name": "Charity", "desc": "Love of God, and of the neighbour in front of you.",
		"effect": "What you give does more for the parish and the street."},
	{"id": "fortitude", "name": "Fortitude", "desc": "Holding firm, and doing right, while you are afraid.",
		"effect": "Threats and danger shake you less."},
	{"id": "temperance", "name": "Temperance", "desc": "Measure in food, drink, rest, screens and pride.",
		"effect": "Hunger, thirst and tiredness creep up more slowly."},
	{"id": "prudence", "name": "Prudence", "desc": "Seeing what the moment asks, and choosing it well.",
		"effect": "You notice danger coming sooner, and hear warnings in time."},
]
## How a habit stands, by level (0 to 100).
const VIRTUE_RANKS := [[0, "Beginning"], [15, "Growing"], [40, "Steady"], [70, "Strong"], [90, "Second nature"]]
## Your age when the story starts, by the Age look.
const START_AGES := {"young": 24, "grown": 38, "old": 56}

const SKIN_TONES := {
	"porcelain": "#f0d2bb", "fair": "#e2b796", "olive": "#c79a6e",
	"tan": "#ab7b52", "brown": "#7f5436", "dark": "#533522",
}

const HAIR_COLOURS := {
	"black": "#1c1719", "brown": "#46301f", "auburn": "#73351f",
	"blonde": "#b98f4c", "grey": "#85808a", "white": "#d6d1d3",
}

const EYE_COLOURS := {
	"brown": "#442a18", "hazel": "#6b5a24", "green": "#3d6a48",
	"blue": "#3d6288", "grey": "#6d7883",
}

const APRON_COLOURS := {
	"white": "#b9b3a4", "butcher": "#6d2a2d", "navy": "#27344f",
	"mustard": "#8f7026", "black": "#29252c",
}

const APPEARANCE := [
	{"id": "sex", "label": "Sex", "options": [["man", "Man"], ["woman", "Woman"]]},
	{"id": "age", "label": "Age", "options": [["young", "Young"], ["grown", "Grown"], ["old", "Old"]]},
	{"id": "build", "label": "Build", "options": [["lean", "Lean"], ["average", "Average"], ["heavy", "Heavy"]]},
	{"id": "skin", "label": "Skin", "options": [
		["porcelain", "Porcelain"], ["fair", "Fair"], ["olive", "Olive"],
		["tan", "Tan"], ["brown", "Brown"], ["dark", "Dark"],
	]},
	{"id": "hair", "label": "Hair", "options": [
		["bald", "Bald"], ["short", "Short"], ["messy", "Messy"],
		["long", "Long"], ["tied", "Tied up"], ["curly", "Curly"],
	]},
	{"id": "hair_colour", "label": "Hair colour", "options": [
		["black", "Black"], ["brown", "Brown"], ["auburn", "Auburn"],
		["blonde", "Blonde"], ["grey", "Grey"], ["white", "White"],
	]},
	{"id": "eyes", "label": "Eyes", "options": [
		["brown", "Brown"], ["hazel", "Hazel"], ["green", "Green"],
		["blue", "Blue"], ["grey", "Grey"],
	]},
	{"id": "facial", "label": "Facial hair", "options": [
		["none", "None"], ["stubble", "Stubble"], ["moustache", "Moustache"], ["beard", "Beard"],
	]},
	{"id": "mark", "label": "Mark", "options": [
		["none", "None"], ["scar", "Scar"], ["mole", "Mole"], ["tired", "Tired eyes"],
	]},
	{"id": "apron", "label": "Apron", "options": [
		["white", "White"], ["butcher", "Butcher red"], ["navy", "Navy"],
		["mustard", "Mustard"], ["black", "Black"],
	]},
	# The 3D body. Faces and clothes depend on sex: see options_for().
	{"id": "head", "label": "Face", "options": [["Casual", "Face 1"]]},
	{"id": "top", "label": "Top", "options": [["Casual2", "T-shirt"]]},
	{"id": "legs", "label": "Trousers", "options": [["Casual", "Jeans"]]},
	{"id": "feet", "label": "Shoes", "options": [["Casual", "Trainers"]]},
	{"id": "top_colour", "label": "Top colour", "options": [
		["charcoal", "Charcoal"], ["navy", "Navy"], ["brown", "Brown"], ["green", "Bottle green"],
		["maroon", "Maroon"], ["grey", "Grey"], ["mustard", "Mustard"], ["cream", "Cream"], ["as_made", "As made"],
	]},
]

const TOP_COLOURS := {
	"charcoal": "#4b4a55", "navy": "#2a344f", "brown": "#4a3b32", "green": "#2f4a3a",
	"maroon": "#5a2f2f", "grey": "#6b6b70", "mustard": "#7a6a4a", "cream": "#a49c8a",
}

## The body parts you can wear, by sex: [outfit file, name for each part].
const BODY_PARTS := {
	"man": {
		"head": ["Casual", "Casual2", "Suit", "Punk", "Adventurer", "Worker", "Farmer"],
		"top": [["Casual2", "T-shirt"], ["Casual", "Jumper"], ["Adventurer", "Outdoor jacket"], ["Worker", "Hi-vis vest"], ["Farmer", "Work shirt"], ["Suit", "Suit jacket"], ["Punk", "Punk vest"]],
		"legs": [["Casual", "Jeans"], ["Casual2", "Light jeans"], ["Suit", "Suit trousers"], ["Worker", "Work trousers"], ["Farmer", "Overalls"], ["Adventurer", "Cargo trousers"], ["Punk", "Ripped jeans"]],
		"feet": [["Casual", "Trainers"], ["Casual2", "White trainers"], ["Suit", "Dress shoes"], ["Worker", "Work boots"], ["Farmer", "Wellies"], ["Adventurer", "Hiking boots"], ["Punk", "Combat boots"]],
	},
	"woman": {
		"head": ["Casual", "Formal", "Suit", "Punk", "Adventurer", "Worker", "SciFi", "Soldier"],
		"top": [["Casual", "T-shirt"], ["Formal", "Blouse"], ["Suit", "Suit jacket"], ["Adventurer", "Outdoor jacket"], ["Worker", "Hi-vis vest"], ["SciFi", "Techwear"], ["Punk", "Punk top"]],
		"legs": [["Casual", "Trousers"], ["Formal", "Skirt"], ["Suit", "Suit trousers"], ["Adventurer", "Cargo trousers"], ["Worker", "Work trousers"], ["SciFi", "Techwear"], ["Punk", "Punk trousers"]],
		"feet": [["Casual", "Sandals"], ["Formal", "Heels"], ["Suit", "Dress shoes"], ["Adventurer", "Boots"], ["Worker", "Work boots"], ["SciFi", "Tech boots"], ["Punk", "Combat boots"]],
	},
}

const NAMES_MAN := [
	"Anselm", "Tomás", "Benedict", "Sebastian", "Patrick", "Joaquim",
	"Dominic", "Augustine", "Francis", "Matteo", "Declan", "Inácio",
]
const NAMES_WOMAN := [
	"Brigid", "Teresa", "Clare", "Monica", "Agnes", "Lúcia",
	"Bernadette", "Cecilia", "Rita", "Catarina", "Siobhán", "Perpetua",
]
const SURNAMES := [
	"Moreira", "Byrne", "Ferraro", "Kowalski", "Walsh", "Oliveira",
	"Rossi", "Nolan", "Santos", "Dunne", "Bianchi", "Novak",
]


static func stat_def(id: String) -> Dictionary:
	return _find(STATS, id)


static func temperament_def(id: String) -> Dictionary:
	return _find(TEMPERAMENTS, id)


static func virtue_def(id: String) -> Dictionary:
	return _find(VIRTUES, id)


static func virtue_rank(level: float) -> String:
	var name: String = VIRTUE_RANKS[0][1]
	for rank: Array in VIRTUE_RANKS:
		if level >= float(rank[0]):
			name = rank[1]
	return name


static func appearance_def(id: String) -> Dictionary:
	return _find(APPEARANCE, id)


static func activity_def(id: String) -> Dictionary:
	return _find(ACTIVITIES, id)


static func product_def(id: String) -> Dictionary:
	var found := _find(PRODUCTS, id)
	if found.is_empty():
		found = upgrade_def(id)
	return found


static func upgrade_def(id: String) -> Dictionary:
	return _find(UPGRADES, id)


## The choices for one part of your looks. Faces and clothes depend on sex.
static func options_for(appearance_id: String, sex: String) -> Array:
	var parts: Dictionary = BODY_PARTS.get(sex, BODY_PARTS["man"])
	if appearance_id == "head":
		var faces := []
		for i in parts["head"].size():
			faces.append([parts["head"][i], "Face %d" % (i + 1)])
		return faces
	if parts.has(appearance_id):
		return parts[appearance_id]
	return appearance_def(appearance_id)["options"]


static func option_name(appearance_id: String, option_id: String, sex := "man") -> String:
	for option: Array in options_for(appearance_id, sex):
		if option[0] == option_id:
			return option[1]
	for option: Array in appearance_def(appearance_id)["options"]:
		if option[0] == option_id:
			return option[1]
	return option_id


static func _find(list: Array, id: String) -> Dictionary:
	for entry: Dictionary in list:
		if entry["id"] == id:
			return entry
	return {}
