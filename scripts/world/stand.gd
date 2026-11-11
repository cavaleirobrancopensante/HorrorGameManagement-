class_name Stand
extends Node
## The food stand, run with your own hands. Take rolls, meat and cans; put
## anything down anywhere; meat cooks wherever it sits on the grill; put food
## together wherever it lies; add sauce from the bottles; hand it through the
## hatch. Food belongs on the grill, the serving counter and the prep board:
## set down elsewhere, customers mind; on the floor or a filthy counter, they
## refuse it. Everything runs out and has to be bought again.

signal message(text: String)

## Where customers stand outside the hatch.
const SPOTS := [Vector3(2.55, 0.0, 3.95), Vector3(1.75, 0.0, 3.95), Vector3(0.95, 0.0, 3.95)]
const SOURCES := {"take_sausage": ["sausage", "sausages"], "take_patty": ["patty", "patties"], "take_bun": ["bun", "buns"], "cooler": ["can", "soda"]}
## Below this height a point is the floor (the trailer's, or the street).
const FLOOR_HEIGHT := 0.12
## Dirt left on a food surface.
const DIRT_PLACE := 0.02
const DIRT_RAW := 0.08
const DIRT_COOKED := 0.03
const DIRT_BURNT := 0.12

var game: TrailerGame
var spots: Array = [null, null, null]
## What you are holding, or null.
var held: FoodItem = null
var _spawn_wait := 6.0
var _rng := RandomNumberGenerator.new()
var _sizzle: AudioStreamPlayer


func setup(owner_game: TrailerGame) -> void:
	game = owner_game
	_rng.randomize()
	_sizzle = AudioStreamPlayer.new()
	var stream: AudioStreamOggVorbis = load("res://assets/audio/sizzle.ogg")
	stream.loop = true
	_sizzle.stream = stream
	_sizzle.bus = "SFX"
	_sizzle.volume_db = -10.0
	add_child(_sizzle)
	for surface in game.world.surfaces:
		surface.show_dirt(_dirt(surface.key))
	# The sauce bottles start on the serving counter, as full as you left them.
	for kind: String in TrailerWorld.BOTTLE_HOMES:
		var bottle := FoodItem.create(kind)
		bottle.data["left"] = int(_save_world()["bottles"].get(kind, _bottle_size()))
		bottle.refresh(0)
		game.world.add_child(bottle)
		bottle.global_position = TrailerWorld.BOTTLE_HOMES[kind]
		bottle.data["on"] = "prep"


func _save_world() -> Dictionary:
	return game.save["world"]


func _cooking() -> int:
	return game.character.stat_value("cooking")


func _charm() -> int:
	return game.character.stat_value("charm")


func _pro() -> bool:
	return Survival.has_upgrade(game.save, "grill")


func _bottle_size() -> int:
	return StandRules.bottle_size(Survival.has_upgrade(game.save, "bottles"))


## The sign in the window says OPEN: new customers come.
func is_open() -> bool:
	return bool(_save_world().get("sign_open", true))


func _hatch_open() -> bool:
	return bool(_save_world()["hatch_open"])


func _street_point() -> Vector3:
	return Vector3(_rng.randf_range(-4.0, 12.0), TrailerWorld.GROUND, 13.0)


func _name(item: FoodItem) -> String:
	return item.describe(_cooking())


func items() -> Array:
	return get_tree().get_nodes_in_group("food").filter(func(n: Node) -> bool: return n != held and is_instance_valid(n) and not n.is_queued_for_deletion())


# Dirt -------------------------------------------------------------------------

func _dirt(key: String) -> float:
	return float(_save_world()["dirt"].get(key, 0.0))


func _add_dirt(key: String, amount: float) -> void:
	var dirt := clampf(_dirt(key) + amount, 0.0, 1.0)
	_save_world()["dirt"][key] = dirt
	for surface in game.world.surfaces:
		if surface.key == key:
			surface.show_dirt(dirt)


func _learn(step: String) -> void:
	_save_world()["learned"][step] = true


func _learned(step: String) -> bool:
	return bool(_save_world()["learned"].get(step, false))


# Every frame ------------------------------------------------------------------

func tick(delta: float) -> void:
	var sizzling := false
	var pro := _pro()
	var speed := StandRules.PRO_GRILL_SPEED if pro else 1.0
	var grill_dirty := _dirt("grill") >= Surface.DIRTY
	for item: FoodItem in items():
		if item.data.get("on", "") != "grill" or not item.data["kind"] in StandRules.MEATS:
			continue
		var before := StandRules.cook_state(item.data, _cooking(), pro)
		item.data["cook"] = float(item.data["cook"]) + delta * speed
		var after := StandRules.cook_state(item.data, _cooking(), pro)
		if after != before:
			_add_dirt("grill", DIRT_BURNT if after == "burnt" else DIRT_COOKED)
		if grill_dirty:
			item.data["dirty"] = true
		item.refresh(_cooking(), pro)
		sizzling = true
	if held != null:
		held.refresh(_cooking(), pro)
	if sizzling and not _sizzle.playing:
		_sizzle.play()
	elif not sizzling and _sizzle.playing:
		_sizzle.stop()

	for i in spots.size():
		var customer: Customer = spots[i]
		if customer == null or not is_instance_valid(customer):
			spots[i] = null
			continue
		if not _hatch_open():
			_send_away(i)
			continue
		if customer.at_hatch:
			customer.mood -= customer.decay * delta
			if customer.mood <= 0.0:
				_send_away(i)
				Survival.change_need(game.save, "stress", Virtue.insult_stress(game.save, 3.0))
				GameLog.bad("A customer gave up waiting and left angry.")
				Life.change_trust(game.save, -1.0)
				message.emit("A customer gave up waiting and left angry.")
				continue

	if not _hatch_open() or not is_open() or spots.find(null) == -1:
		return
	_spawn_wait -= delta
	if _spawn_wait <= 0.0:
		spawn()


func _skill() -> float:
	var who := game.character
	return (who.stat_value("cooking") + who.stat_value("charm") + who.stat_value("business")) / 30.0


## Brings a new customer to a free spot. instant skips the walk, for tests.
func spawn(instant := false) -> void:
	var shift := Survival.shift_index(Survival.now(game.save))
	# The more the street trusts you, the more people come.
	var trusted := 1.15 - 0.3 * Life.trust(game.save) / 100.0
	_spawn_wait = StandRules.spawn_interval(shift, _skill(), Survival.has_upgrade(game.save, "neon")) * trusted * _rng.randf_range(0.7, 1.3)
	var free := spots.find(null)
	if free == -1:
		return
	var tv := Survival.has_upgrade(game.save, "tv")
	GameLog.mark("a customer arrives")
	var customer := Customer.create(_rng, StandRules.random_order(_rng), StandRules.start_mood(_charm()), StandRules.mood_decay(_charm(), tv))
	game.world.add_child(customer)
	spots[free] = customer
	var target := Vector3(SPOTS[free].x, TrailerWorld.GROUND, SPOTS[free].z)
	if instant:
		customer.position = target
		customer.at_hatch = true
	else:
		customer.position = _street_point()
		customer.walk_to(target, func() -> void: customer.at_hatch = true)


func _send_away(index: int) -> void:
	var customer: Customer = spots[index]
	spots[index] = null
	if customer != null and is_instance_valid(customer):
		customer.leave(_street_point())


func waiting_orders() -> Array:
	var orders := []
	for customer: Customer in spots:
		if customer != null and is_instance_valid(customer) and customer.at_hatch and not customer.has_food:
			orders.append(customer.order)
	return orders


## When hours pass at once: customers go, and anything left on the grill burns.
func clear() -> void:
	for i in spots.size():
		var customer: Customer = spots[i]
		spots[i] = null
		if customer != null and is_instance_valid(customer):
			customer.queue_free()
	for item: FoodItem in items():
		if item.data.get("on", "") == "grill" and item.data["kind"] in StandRules.MEATS:
			if StandRules.cook_state(item.data, _cooking(), _pro()) != "burnt":
				_add_dirt("grill", DIRT_BURNT)
			item.data["cook"] = 999.0
			item.refresh(_cooking(), _pro())
	_sizzle.stop()


# Holding ----------------------------------------------------------------------

func _hold(item: FoodItem) -> void:
	held = item
	item.data["on"] = ""
	if item.get_parent() == null:
		game.player.hand.add_child(item)
	else:
		item.reparent(game.player.hand, false)
	item.transform = Transform3D.IDENTITY
	item.set_held(true)


func _consume_held() -> void:
	held.remove_from_group("food")
	held.queue_free()
	held = null


## Puts what you hold down at a point. surface is the food surface there, or null.
func _put_down(point: Vector3, surface: Surface) -> void:
	var item := held
	held = null
	item.reparent(game.world, false)
	item.set_held(false)
	item.rotation = Vector3(0.0, game.player.rotation.y, 0.0)
	var raw: bool = item.data["kind"] in StandRules.MEATS and StandRules.cook_state(item.data, _cooking(), _pro()) == "raw"
	if surface != null:
		item.global_position = surface.landing(point)
		item.data["on"] = surface.kind
		if _dirt(surface.key) >= Surface.DIRTY and not StandRules.is_sauce(item.data):
			item.data["dirty"] = true
			message.emit("The %s is filthy. Wipe it before you put food on it." % surface.label)
		_add_dirt(surface.key, DIRT_RAW if raw else DIRT_PLACE)
		if surface.kind == "grill" and raw:
			_learn("grill")
	else:
		item.global_position = point
		var on_floor := point.y < FLOOR_HEIGHT
		item.data["on"] = "floor" if on_floor else "other"
		if StandRules.is_sauce(item.data) or item.data["kind"] == "can":
			pass
		elif on_floor:
			item.data["dirty"] = true
			GameLog.bad("Dropped food on the floor.")
			message.emit("On the floor. Nobody will eat that now.")
		else:
			item.data["odd"] = true
	if item.data["kind"] in StandRules.FOODS or item.data["kind"] in StandRules.MEATS:
		_learn("spare")
	item.refresh(_cooking(), _pro())
	Sound.play("step", 0.1, -12.0)


## Order bubbles for customers the camera can see: [screen point, text, colour, mood].
func bubbles(camera: Camera3D, pixel_scale: float) -> Array:
	var result := []
	var space := camera.get_world_3d().direct_space_state
	for customer: Customer in spots:
		if customer == null or not is_instance_valid(customer) or not customer.at_hatch:
			continue
		var point := customer.bubble_point()
		if camera.is_position_behind(point) or camera.global_position.distance_to(point) > 14.0:
			continue
		# Hidden when a wall is between you and them.
		var query := PhysicsRayQueryParameters3D.create(camera.global_position, customer.global_position + Vector3(0.0, 1.45, 0.0))
		query.exclude = [game.player.get_rid()]
		query.collision_mask = 1
		var hit := space.intersect_ray(query)
		var collider: Object = hit.get("collider")
		if collider != null and not (collider is Interactable and (collider as Interactable).id == "customer"):
			continue
		result.append([camera.unproject_position(point) * pixel_scale, customer.bubble_text(_charm()), customer.bubble_colour(), customer.mood])
	return result


## The line at the bottom of the screen about what is in your hands.
func held_text() -> String:
	if held == null:
		return ""
	var text := "Holding: %s" % _name(held)
	if StandRules.is_sauce(held.data):
		text += " (%d left)" % int(held.data["left"])
	return text


## A first-time hint about the next step, or "".
func hint() -> String:
	if held == null:
		if not _learned("take") and _hatch_open() and not waiting_orders().is_empty():
			return "Take meat from the drawers under the grill and rolls from the bread bin."
		return ""
	var next := StandRules.hint(held.data, waiting_orders(), _cooking(), _pro())
	if next.is_empty() or _learned(next["id"]):
		return ""
	return next["text"]


func can_eat_held() -> bool:
	return held != null and StandRules.eat_effect(held.data, _cooking()).size() > 1


## Eat or drink what you are holding.
func use_held() -> void:
	if held == null:
		return
	var effect := StandRules.eat_effect(held.data, _cooking())
	if effect.is_empty():
		message.emit("You can't eat that.")
		return
	for need: String in ["hunger", "thirst", "stress"]:
		if effect.has(need):
			Survival.change_need(game.save, need, effect[need])
	message.emit(effect["text"])
	if effect.size() > 1:
		Sound.play("can" if held.data["kind"] == "can" else "step", 0.1)
		_consume_held()


# What is available ------------------------------------------------------------

func _loose(kind: String, usable := true) -> bool:
	for item: FoodItem in items() + ([held] if held != null else []):
		if item.data["kind"] != kind:
			continue
		if usable and (item.data["dirty"] or item.data["burnt"] or StandRules.cook_state(item.data, _cooking(), _pro()) == "burnt"):
			continue
		return true
	return false


func _bottle(kind: String) -> FoodItem:
	for item: FoodItem in items() + ([held] if held != null else []):
		if item.data["kind"] == kind:
			return item
	return null


## What could be served right now, counting stock and food already made.
func availability() -> Dictionary:
	var available := {}
	var buns := Survival.stock(game.save, "buns") > 0 or _loose("bun")
	available["hot_dog"] = _loose("hot_dog") or (buns and (Survival.stock(game.save, "sausages") > 0 or _loose("sausage")))
	available["burger"] = _loose("burger") or (buns and (Survival.stock(game.save, "patties") > 0 or _loose("patty")))
	for sauce: String in StandRules.SAUCES:
		var bottle := _bottle(sauce)
		available[sauce] = (bottle != null and int(bottle.data["left"]) > 0) or Survival.stock(game.save, sauce) > 0
	available["can"] = Survival.stock(game.save, "soda") > 0 or _loose("can")
	return available


# Looking and using ------------------------------------------------------------

## The prompt for things the stand handles, or "" for anything else.
## target may be null: then it is about putting down what you hold.
func prompt_for(target: Interactable) -> String:
	if target == null:
		return _aim_prompt()
	if target.id == "item":
		return _item_prompt(target.get_meta("item"))
	if target.id == "surface":
		return _surface_prompt(target as Surface)
	if SOURCES.has(target.id):
		var source: Array = SOURCES[target.id]
		var count := Survival.stock(game.save, source[1])
		if held == null:
			return "Take a %s (%d left)" % [StandRules.NAMES[source[0]], count] if count > 0 else "No %s left. Order more on the computer." % source[1]
		if _can_put_back(source):
			return "Put the %s back" % StandRules.NAMES[source[0]]
		return "Hands full. Put it down first"
	match target.id:
		"bin":
			return "Bin" if held == null else "Throw away the %s" % _name(held)
		"customer":
			var customer: Customer = target.get_meta("customer")
			if not customer.at_hatch:
				return ""
			if held != null:
				return "Give the %s" % _name(held)
			var gone := StandRules.missing(customer.order, availability())
			if not gone.is_empty():
				return "Tell them: no %s today" % ", ".join(gone)
			return "Waiting for: %s" % StandRules.order_text(customer.order).replace("\n", " ")
	return ""


## Uses something the stand handles. Returns false if it is not the stand's.
func use(target: Interactable) -> bool:
	if target == null:
		return _aim_use()
	if target.id == "item":
		_use_item(target.get_meta("item"))
		return true
	if target.id == "surface":
		_use_surface(target as Surface)
		return true
	if SOURCES.has(target.id):
		_use_source(SOURCES[target.id])
		return true
	match target.id:
		"bin":
			if held != null:
				message.emit("You throw away the %s." % _name(held))
				_consume_held()
				_learn("bin")
			return true
		"customer":
			var customer: Customer = target.get_meta("customer")
			if held != null:
				_give(customer)
			elif not StandRules.missing(customer.order, availability()).is_empty():
				_tell_out_of(customer)
			return true
	return false


func _can_put_back(source: Array) -> bool:
	var kind: String = source[0]
	return held.data["kind"] == kind and not held.data["dirty"] and (not kind in StandRules.MEATS or float(held.data["cook"]) <= 0.0)


func _use_source(source: Array) -> void:
	var kind: String = source[0]
	var stock_id: String = source[1]
	if held == null:
		if Survival.take_stock(game.save, stock_id):
			_hold(FoodItem.create(kind))
			_learn("take")
		else:
			message.emit("None left. Order more on the computer.")
	elif _can_put_back(source):
		Survival.add_stock(game.save, stock_id, 1)
		_consume_held()


# Putting down anywhere --------------------------------------------------------

func _aim_point() -> Dictionary:
	var aim: Dictionary = game.player.aim
	if aim.is_empty():
		return {}
	var normal: Vector3 = aim["normal"]
	if normal.y < 0.7:
		return {}
	return aim


func _aim_prompt() -> String:
	if held == null:
		return ""
	var aim := _aim_point()
	if aim.is_empty():
		return ""
	var point: Vector3 = aim["position"]
	var surface := game.world.surface_at(point)
	if surface != null:
		return _put_text(surface)
	if point.y < FLOOR_HEIGHT:
		return "Put the %s on the floor" % _name(held)
	return "Put the %s down here" % _name(held)


func _aim_use() -> bool:
	if held == null:
		return false
	var aim := _aim_point()
	if aim.is_empty():
		return false
	var point: Vector3 = aim["position"]
	_put_down(point, game.world.surface_at(point))
	return true


func _put_text(surface: Surface) -> String:
	if surface.kind == "grill":
		return "Put the %s on the grill" % _name(held)
	return "Put the %s on the %s" % [_name(held), surface.label]


func _surface_prompt(surface: Surface) -> String:
	if held != null:
		return _put_text(surface)
	var dirt := _dirt(surface.key)
	if dirt < 0.08:
		return ""
	var state := "filthy" if dirt >= Surface.DIRTY else "greasy"
	var spray := Survival.stock(game.save, "cleaner")
	if spray <= 0:
		return "The %s is %s. Order cleaning spray." % [surface.label, state]
	return "Wipe the %s (spray for %d wipes)" % [surface.label, spray]


func _use_surface(surface: Surface) -> void:
	if held != null:
		var point: Vector3 = game.player.aim.get("position", surface.global_position)
		_put_down(point, surface)
		return
	if _dirt(surface.key) < 0.08:
		return
	if not Survival.take_stock(game.save, "cleaner"):
		message.emit("No cleaning spray left. Order some on the computer.")
		return
	_save_world()["dirt"][surface.key] = 0.0
	for each in game.world.surfaces:
		if each.key == surface.key:
			each.show_dirt(0.0)
	Sound.play("water", 0.2, -10.0)
	message.emit("You spray and wipe the %s clean." % surface.label)


# Items ------------------------------------------------------------------------

func _item_prompt(item: FoodItem) -> String:
	var sauce := StandRules.is_sauce(item.data)
	if held == null:
		if sauce and int(item.data["left"]) <= 0:
			var refills := Survival.stock(game.save, item.data["kind"])
			if refills > 0:
				return "Refill the %s (%d refills)" % [StandRules.NAMES[item.data["kind"]], refills]
			return "The %s is empty. Order a refill." % StandRules.NAMES[item.data["kind"]]
		return "Pick up the %s" % _name(item)
	# A bottle in front of you and food in your hand: sauce it where you stand.
	if sauce and held.data["kind"] in StandRules.FOODS:
		return _sauce_text(held.data, item)
	if StandRules.is_sauce(held.data) and item.data["kind"] in StandRules.FOODS:
		return _sauce_text(item.data, held)
	var result: Variant = StandRules.combine(item.data, held.data, _cooking(), _pro())
	if result is Dictionary:
		return "Put the %s in the roll" % _name(held) if held.data["kind"] != "bun" else "Put the %s in the roll" % _name(item)
	var reason := str(result)
	if not reason.is_empty():
		return reason
	return "Put the %s down here" % _name(held)


func _sauce_text(food: Dictionary, bottle: FoodItem) -> String:
	var kind: String = bottle.data["kind"]
	var sauce: String = StandRules.SAUCE_NAMES[kind]
	if int(bottle.data["left"]) <= 0:
		return "The %s bottle is empty" % sauce
	if food[kind]:
		return "It already has %s" % sauce
	return "Add %s (%d left)" % [sauce, int(bottle.data["left"])]


func _use_item(item: FoodItem) -> void:
	var sauce := StandRules.is_sauce(item.data)
	if held == null:
		if sauce and int(item.data["left"]) <= 0:
			if Survival.take_stock(game.save, item.data["kind"]):
				item.data["left"] = _bottle_size()
				_save_bottle(item)
				item.refresh(_cooking())
				message.emit("You refill the %s." % StandRules.NAMES[item.data["kind"]])
			return
		_hold(item)
		return
	if sauce and held.data["kind"] in StandRules.FOODS:
		_add_sauce(held, item)
		return
	if StandRules.is_sauce(held.data) and item.data["kind"] in StandRules.FOODS:
		_add_sauce(item, held)
		return
	var result: Variant = StandRules.combine(item.data, held.data, _cooking(), _pro())
	if result is Dictionary:
		var made: Dictionary = result
		made["on"] = item.data.get("on", "")
		item.data = made
		item.refresh(_cooking(), _pro())
		_consume_held()
		_learn("assemble")
		Sound.play("step", 0.1, -10.0)
		return
	if not str(result).is_empty():
		message.emit(str(result))
		return
	# Nothing to combine: set it down beside the other one.
	var point := item.global_position + game.player.global_basis.x * 0.2
	_put_down(point, game.world.surface_at(point))


func _add_sauce(food: FoodItem, bottle: FoodItem) -> void:
	var kind: String = bottle.data["kind"]
	if int(bottle.data["left"]) <= 0:
		message.emit("The bottle is empty. Refill it from stock, or order more.")
		return
	var result: Variant = StandRules.combine(food.data, bottle.data, _cooking(), _pro())
	if not (result is Dictionary):
		message.emit(str(result))
		return
	var on: Variant = food.data.get("on", "")
	food.data = result
	food.data["on"] = on
	bottle.data["left"] = int(bottle.data["left"]) - 1
	_save_bottle(bottle)
	food.refresh(_cooking(), _pro())
	bottle.refresh(_cooking())
	_learn("sauce")
	if int(bottle.data["left"]) == 0:
		message.emit("That was the last of the %s." % StandRules.SAUCE_NAMES[kind])


func _save_bottle(bottle: FoodItem) -> void:
	_save_world()["bottles"][bottle.data["kind"]] = int(bottle.data["left"])


# Customers --------------------------------------------------------------------

func _tell_out_of(customer: Customer) -> void:
	var changed := StandRules.substitute(customer.order, availability())
	if changed.is_empty():
		GameLog.bad("A customer left: nothing they wanted was in stock.")
		message.emit("\"Nothing I want? Unbelievable.\" They walk off.")
		Survival.change_need(game.save, "stress", 2.0)
		_send_away(spots.find(customer))
		return
	customer.order = changed
	customer.upset(StandRules.MOOD_SUBSTITUTE)
	message.emit("\"Fine. %s, then.\"" % StandRules.order_text(changed).replace("\n", " "))


func _give(customer: Customer) -> void:
	if held == null or not customer.at_hatch:
		return
	var problem := StandRules.give_problem(customer.order, held.data, customer.has_food, customer.has_can)
	if not problem.is_empty():
		customer.upset(StandRules.MOOD_REFUSED if held.data["dirty"] else StandRules.MOOD_WRONG)
		Survival.change_need(game.save, "stress", 1.5)
		GameLog.bad("Order refused: %s" % problem)
		message.emit("\"%s\"" % problem)
		return
	if held.data["odd"]:
		customer.upset(StandRules.MOOD_ODD_PLACE)
		GameLog.bad("Order refused: the food was put on a dirty or odd spot.")
		message.emit("\"Where has this been sitting?\"")
	if held.data["kind"] == "can":
		customer.has_can = true
	else:
		customer.has_food = true
	_consume_held()
	_learn("serve")
	if not customer.is_complete():
		return
	customer.pay()
	var paid := StandRules.price(customer.order)
	# Trust: regulars who know you tip a little more.
	var tip := roundi(StandRules.tip(customer.mood, _charm()) * (0.8 + 0.4 * Life.trust(game.save) / 100.0))
	game.save["survival"]["money"] = Survival.money(game.save) + paid + tip
	Life.count(game.save, "served")
	Life.change_trust(game.save, 0.4 if customer.mood >= StandRules.MOOD_ANGRY else -0.5)
	Sound.play("till")
	var face := StandRules.face(customer.mood)
	var mood_text: String = {"happy": "They look pleased.", "neutral": "They take it without a word.", "angry": "They snatch it and go."}[face]
	GameLog.good("Served a customer: +%d credits%s. %s" % [paid + tip, " (tip %d)" % tip if tip > 0 else "", mood_text])
	message.emit("+%d credits%s. %s" % [paid + tip, " (tip %d)" % tip if tip > 0 else "", mood_text])
	_send_away(spots.find(customer))
