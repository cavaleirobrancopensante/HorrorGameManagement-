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
