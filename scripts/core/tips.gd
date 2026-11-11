class_name Tips
extends RefCounted
## What things are and what they are for, shown when you hold the crosshair on
## something for a moment, and on the menus when you point at a control.

## Things in the world, by their id: [title, what it does].
const WORLD := {
	"take_sausage": ["Sausage drawer", "Raw sausages. Take one, cook it on the grill, then put it in a bread roll for a hot dog."],
	"take_patty": ["Patty drawer", "Raw burger patties. Cook them on the grill until done, but take them off before they burn."],
	"take_bun": ["Bread bin", "Bread rolls for hot dogs and burgers. Put one down, then add cooked meat."],
	"cooler": ["Drinks cooler", "Cans of soda. Some customers want one with their food. You can drink one yourself."],
	"bin": ["Bin", "Throw away anything burnt, dirty or unwanted."],
	"hatch": ["Hatch lever", "Opens and shuts the serving hatch. Customers only come while it is open. Shut, nobody outside can see or shoot in."],
	"computer": ["Computer", "Civic Link: your security cameras, the shop for stock and upgrades, the news, and your standing with the state."],
	"bed": ["Bed", "Sleep through the night to shake off tiredness. Close the window shutter first."],
	"altar": ["Home altar", "Pray: eases stress and turns your soul toward the faith. Also where you say a penance."],
	"calendar": ["Calendar", "Plan the day: spend a whole shift working, resting, sleeping, praying or at Mass."],
	"coffee": ["Kettle", "A coffee keeps tiredness off for a while."],
	"sink": ["Sink", "Drink tap water when you are thirsty."],
	"wardrobe": ["Wardrobe", "Change your top, trousers, shoes and apron. What you wear shows in the mirror and on the cameras."],
	"shower": ["Shower", "Wash. Eases stress and tiredness, and takes a quarter of an hour."],
	"fridge": ["Fridge", "Ready meals, for when you are hungry and the grill is not worth it."],
	"shelves": ["Stock shelves", "Look here to count what you have left."],
	"delivery": ["Delivery crates", "What the drone dropped off. Carry it in to add it to your stock."],
	"shutters": ["Window shutter", "Closed, nothing can watch you or shoot in, and most burglars give up. You cannot see or shoot out either."],
	"barricade": ["Planks", "Nail them across the closed front door. It then takes three times the bashing to break in."],
	"first_aid": ["First aid box", "Bandages heal your wounds. Buy more on the computer."],
	"church_street": ["Sign to St. Brigid's", "Walk to the church. Open from morning to the end of the evening shift."],
	"church_exit": ["Church door", "Walk home. Twenty minutes."],
	"pew": ["Pews", "Hear Mass when it is on: Sunday morning, noon and evening, and Saturday evening. Otherwise, kneel and pray."],
	"confession": ["Confessional", "Confess to Father Columba in the evening, or on Saturday afternoon. A full confession restores the state of grace."],
	"priest": ["Father Columba", "The parish priest. He hears confessions, and knows more than he says."],
	"tabernacle": ["Tabernacle", "The Blessed Sacrament. Prayer here eases stress more than anywhere."],
	"font": ["Holy water", "Bless yourself on the way in."],
	"votive": ["Candles to Our Lady", "Light one for a credit: eases stress and turns your soul toward the faith."],
}

const ENEMIES := {
	"thug": ["Thug", "Comes to break your door down and fight you up close. Hit him with the bat, or keep the door barricaded."],
	"shooter": ["Shooter", "Shoots you through any open window, hatch or door. Close the shutters and the hatch to force him to come in."],
	"burglar": ["Burglar", "Came in through the window for your cash. Fight him off with the bat."],
	"drone": ["Civic enforcement drone", "Zaps you through any opening, and rams the shutter or door when everything is shut. Two good slingshot hits bring it down."],
}

const MENU := {
	"continue": "Pick up your most recent game where you left it.",
	"new": "Make a character and begin on Saturday 15 January 2050, in your trailer.",
	"load": "Choose one of your ten saved games.",
	"settings": "Volume and picture.",
	"quit": "Close the game. Your game is saved as you play.",
	"version": "Every change in every version of the game.",
}

const CREATION := {
	"name": "Your character's name. Type one, or press Random name.",
	"random_name": "Pick a name that fits your character.",
	"randomize_step": "Fill in this step at random. You can still change anything afterwards.",
	"randomize_all": "A whole random character: looks, temperament, conscience and abilities.",
	"back": "The previous step.",
	"next": "The next step.",
	"begin": "Start the game with this character.",
	"menu": "Back to the main menu. This character will be lost.",
	"preview": "Your character as they will look in the mirror. Drag to turn them around.",
	"sex": "Man or woman. Changes the body, faces and clothes you can choose.",
	"head": "Face and hair. Each one is a different person.",
	"top": "What you wear on top. Your apron goes over it.",
	"legs": "Trousers, jeans or a skirt.",
	"feet": "Shoes and boots.",
	"skin": "Skin tone.",
	"hair_colour": "Hair colour. Also colours eyebrows and moustaches.",
	"top_colour": "The colour of your top.",
	"apron": "The colour of your apron.",
}


static func world(id: String) -> Array:
	return WORLD.get(id, [])
