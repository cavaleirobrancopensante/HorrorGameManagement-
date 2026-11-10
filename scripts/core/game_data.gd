class_name GameData
extends RefCounted
## All character-creation rules live here, so balance can be changed in one file.

const BASE_STAT := 5
const FREE_POINTS := 6
const MAX_FREE_PER_STAT := 3
const MIN_SIN_LEVEL := -2  # Strong virtue.
const MAX_SIN_LEVEL := 2  # Besetting sin.

const TEMPTATION_PER_VICE_LEVEL := 0.30
const TEMPTATION_PER_VIRTUE_LEVEL := 0.20
const TEMPTATION_INCLINATION := 0.15

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
		"rates": {"hunger": 2.0, "thirst": 3.0, "tiredness": 1.0, "stress": -4.5},
		"lean": -2,
	},
	{
		"id": "mass", "name": "Go to Mass",
		"desc": "At St. Brigid's, across the city.",
		"rates": {"hunger": 2.0, "thirst": 3.0, "tiredness": 1.5, "stress": -6.0},
		"lean": -3,
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
const NEWS_DEMONIC := [
	"Third street vendor missing this month. Police see no link.",
	"Residents report tall figures standing under streetlamps at night.",
	"Animals found dead in a circle near the old rail yard.",
	"Pharmacies report record sales of sleeping pills.",
	"Night shift workers describe the same dream.",
	"Man says something looked in his second floor window.",
	"Whispering heard on police radios for a second night.",
	"Missing vendor's trailer found with its lights still on.",
]

## Where the horror leans, from -100 to 100. Sin pushes it up toward the
## demonic: easier survival, a compromised soul. Faithfulness pushes it down
## toward the dystopian state: persecution and harder material survival.
const HORROR_LEAN_MIN := -100
const HORROR_LEAN_MAX := 100

const LEVEL_NAMES := {
	-2: "Strong virtue",
	-1: "Steady",
	0: "Ordinary",
	1: "Struggling",
	2: "Besetting",
}

const STATS := [
	{"id": "cooking", "name": "Cooking", "desc": "Better food brings more customers."},
	{"id": "business", "name": "Business", "desc": "Better prices, margins and deals."},
	{"id": "charm", "name": "Charm", "desc": "Tips, gossip, talking your way out."},
	{"id": "marksmanship", "name": "Marksmanship", "desc": "Steadier aim, faster reloads."},
	{"id": "endurance", "name": "Endurance", "desc": "More health, longer shifts."},
	{"id": "nerve", "name": "Nerve", "desc": "Stress builds slower. Scares hit softer."},
	{"id": "vigilance", "name": "Vigilance", "desc": "Spot spies, thieves and worse."},
	{"id": "devotion", "name": "Devotion", "desc": "Prayer goes deeper and lasts longer."},
]

const TEMPERAMENTS := [
	{
		"id": "choleric",
		"name": "Choleric",
		"tagline": "Quick to act, quick to command.",
		"stats": {"marksmanship": 3, "business": 2, "nerve": 1, "charm": -2},
		"inclined": ["pride", "anger"],
	},
	{
		"id": "melancholic",
		"name": "Melancholic",
		"tagline": "Deep, exacting, slow to forgive itself.",
		"stats": {"cooking": 3, "vigilance": 2, "devotion": 1, "charm": -1, "nerve": -1},
		"inclined": ["envy", "sloth"],
	},
	{
		"id": "sanguine",
		"name": "Sanguine",
		"tagline": "Warm, quick to laugh, quick to forget.",
		"stats": {"charm": 3, "endurance": 2, "business": 1, "vigilance": -2},
		"inclined": ["lust", "gluttony"],
	},
	{
		"id": "phlegmatic",
		"name": "Phlegmatic",
		"tagline": "Steady, gentle, hard to move.",
		"stats": {"nerve": 3, "endurance": 2, "devotion": 1, "business": -2},
		"inclined": ["sloth", "greed"],
	},
]

## Every step toward a sin pays out vice_bonus. Every step toward its virtue pays
## out virtue_bonus and costs one strength earned from a struggle elsewhere.
const SINS := [
	{
		"id": "pride", "sin": "Pride", "virtue": "Humility",
		"vice_bonus": {"nerve": 2, "marksmanship": 1},
		"virtue_bonus": {"devotion": 2},
	},
	{
		"id": "greed", "sin": "Greed", "virtue": "Generosity",
		"vice_bonus": {"business": 3},
		"virtue_bonus": {"charm": 2},
	},
	{
		"id": "lust", "sin": "Lust", "virtue": "Chastity",
		"vice_bonus": {"charm": 3},
		"virtue_bonus": {"devotion": 1, "nerve": 1},
	},
	{
		"id": "anger", "sin": "Anger", "virtue": "Meekness and Patience",
		"vice_bonus": {"marksmanship": 3},
		"virtue_bonus": {"nerve": 2},
	},
	{
		"id": "gluttony", "sin": "Gluttony", "virtue": "Temperance",
		"vice_bonus": {"cooking": 3},
		"virtue_bonus": {"endurance": 2},
	},
	{
		"id": "envy", "sin": "Envy", "virtue": "Kindness",
		"vice_bonus": {"vigilance": 3},
		"virtue_bonus": {"charm": 1, "devotion": 1},
	},
	{
		"id": "sloth", "sin": "Sloth", "virtue": "Diligence",
		"vice_bonus": {"endurance": 3},
		"virtue_bonus": {"cooking": 1, "business": 1},
	},
]

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
]

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


static func sin_def(id: String) -> Dictionary:
	return _find(SINS, id)


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


static func option_name(appearance_id: String, option_id: String) -> String:
	for option: Array in appearance_def(appearance_id)["options"]:
		if option[0] == option_id:
			return option[1]
	return option_id


static func _find(list: Array, id: String) -> Dictionary:
	for entry: Dictionary in list:
		if entry["id"] == id:
			return entry
	return {}
