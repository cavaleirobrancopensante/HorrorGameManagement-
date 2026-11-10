class_name Changelog
extends RefCounted
## Every patch, newest first. The first entry is the version shown on the main
## menu; project.godot's config/version must match it (a test checks).

const PATCHES := [
	{
		"version": "0.7.0", "date": "10 Nov 2026", "title": "Something outside",
		"changes": [
			"The horror director. Your soul's lean decides what comes: toward sin, the demonic; toward faith, the state; in between, a little of both. How far you lean, how stressed you are and how late it is decide how often and how bad. Night is worst. St. Brigid's is safe.",
			"The demonic: whispers, three slow knocks at night, a shape on your street camera, the lights dying with something in the room, someone behind you in the mirror, a customer who smiles too wide, a watcher across the street that is gone once you have looked at it, a face in your face, and at the worst, a blow from something you cannot see.",
			"The state: a Civic drone at your window, a 'faith-affiliated' surcharge, your camera feeds seized for a shift, a hygiene inspector who fines you (more for a filthy counter) and shuts your hatch, the man in the grey coat across the street, and at night, an enforcement raid that takes your candles and half your meat.",
			"Health matters now: the worst of it can hurt you, and dead is dead.",
			"New sounds: knocks, a scare, the Civic drone and a siren.",
		],
	},
	{
		"version": "0.6.0", "date": "10 Nov 2026", "title": "A smoother kitchen",
		"changes": [
			"Put anything down anywhere: look at a counter, a shelf or the floor and press use. Two rolls fit side by side on the prep board.",
			"Meat cooks wherever it sits on the grill. Put meat and rolls together where they lie, whichever one you are holding.",
			"Food belongs on the grill, the serving counter and the prep board. Set down anywhere else, customers mind. On the floor or a filthy counter, they refuse it.",
			"Counters get greasy with use and show it. Wipe them with cleaning spray.",
			"A big green bin by the end of the serving counter, labelled.",
			"Sauce bottles hold 15 portions and run out. Refill them from stock. Mayonnaise joins ketchup and mustard.",
			"With food in your hand, look at a sauce bottle to add sauce without putting anything down.",
			"Customers show how they feel: a happy, flat or angry face and a mood bar. Waiting wears them down; happier customers tip more; at the end they walk off.",
			"Out of something? Look at the customer and tell them. They settle for something else, unhappier, or leave.",
			"Deliveries now land at the start of the shift after next. Plan ahead.",
			"Upgrades: a street TV keeps customers patient, a pro griddle cooks faster and burns slower, large sauce bottles, and a neon sign brings more customers. They are delivered and installed when you carry them in.",
			"Hints for the next step, shown only until you have done that step once.",
			"Temptations are personal: the angry drunk now insults your cooking and your trailer. Temptations never attack the faith; defending it is not a sin.",
		],
	},
	{
		"version": "0.5.0", "date": "10 Nov 2026", "title": "St. Brigid's",
		"changes": [
			"Walk to St. Brigid's from the sign at the end of the church street. It is open from morning to the end of the evening shift.",
			"Confession with Father Columba, every evening and on Saturday afternoon. A full confession restores the state of grace and gives a penance. Holding a grave sin back makes it a bad confession.",
			"Hear Mass from the pews, then choose to receive Communion or stay in the pew. Receiving in mortal sin is a sacrilege.",
			"Pray before the Blessed Sacrament, light a candle to Our Lady, bless yourself with holy water, and talk to the priest.",
			"Temptations: greed, gluttony, sloth, anger, lust, envy and pride now tempt you during the day. Giving in helps you and eases stress, but stains your soul. Resisting costs stress, more for the sins you struggle with, less after Communion or confession.",
			"The more stressed you are, the more often you are tempted.",
			"Sins are remembered until you confess them. Missing Sunday Mass is one of them.",
			"Faithfulness draws the state: a watcher at the back of the church, and fines on the way home.",
			"The mirror and the cameras now show your arm reaching, holding and eating, and the food in your hand.",
			"The game version is shown on the main menu. Press it to read these notes.",
		],
	},
	{
		"version": "0.4.0", "date": "10 Nov 2026", "title": "Shower and hands",
		"changes": [
			"The bathroom is wider and has a shower. Showering eases stress and tiredness.",
			"You see your own hand in first person. It reaches for what you use, holds food on the palm and lifts it to your mouth when you eat.",
		],
	},
	{
		"version": "0.3.1", "date": "10 Nov 2026", "title": "Two thumbs",
		"changes": [
			"Phones: you can walk with the left stick and look around with another finger at the same time.",
		],
	},
	{
		"version": "0.3.0", "date": "10 Nov 2026", "title": "The soundtrack",
		"changes": [
			"Six original pieces: the menu theme, Night Shift, Overcast, Something Outside, Sunday and a Requiem for when you die.",
			"Music follows the hour, Sunday and the state of your soul, with silence between pieces.",
		],
	},
	{
		"version": "0.2.0", "date": "10 Nov 2026", "title": "Open the hatch",
		"changes": [
			"Customers come to the hatch with an order and a timer. They leave when it runs out, and tip more the sooner they are served.",
			"Hands-on cooking in free first person: take sausages, patties and rolls, cook them on the grill, add ketchup and mustard, and hand them over.",
			"Burgers join the hot dogs.",
		],
	},
	{
		"version": "0.1.0", "date": "9 Nov 2026", "title": "First steps",
		"changes": [
			"Main menu with New game, Continue, Load game, Settings and Quit, and ten save slots. Dead is dead.",
			"Character creation with the four temperaments, the capital sins and their virtues, and randomize for everything.",
			"The trailer: kitchen, storage, home and bathroom, all walkable. A mirror shows you yourself.",
			"The computer: security cameras, a shop with drone deliveries, and the news.",
			"Survival: money, hunger, thirst, tiredness, stress and health.",
			"The calendar starts on 15 January 2050, with six shifts a day and Sunday Mass.",
			"Play in the browser.",
		],
	},
]


static func version() -> String:
	return PATCHES[0]["version"]


## The notes as plain text, for the patch notes screen.
static func text() -> String:
	var parts: PackedStringArray = []
	for patch: Dictionary in PATCHES:
		var lines: PackedStringArray = ["Version %s, %s: %s" % [patch["version"], patch["title"], patch["date"]]]
		for change: String in patch["changes"]:
			lines.append("  •  " + change)
		parts.append("\n".join(lines))
	return "\n\n".join(parts)
