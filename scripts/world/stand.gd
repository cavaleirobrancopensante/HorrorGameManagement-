class_name Stand
extends Node
## The food stand, run with your own hands: take rolls, meat and cans, cook
## on the grill, put food together on the counter, add sauce with the bottles,
## and hand it to customers through the hatch.

signal message(text: String)

## Where customers stand outside the hatch.
const SPOTS := [Vector3(2.55, 0.0, 3.95), Vector3(1.75, 0.0, 3.95), Vector3(0.95, 0.0, 3.95)]
const SOURCES := {"take_sausage": ["sausage", "sausages"], "take_patty": ["patty", "patties"], "take_bun": ["bun", "buns"], "cooler": ["can", "soda"]}

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
	# The sauce bottles start on the counter.
	for pair: Array in [["ketchup", game.world.ketchup_spot], ["mustard", game.world.mustard_spot]]:
		var bottle := FoodItem.create(pair[0])
		game.world.add_child(bottle)
		(pair[1] as FoodSpot).place(bottle)


func _cooking() -> int:
	return game.character.stat_value("cooking")


func _charm() -> int:
	return game.character.stat_value("charm")


func _hatch_open() -> bool:
	return bool(game.save["world"]["hatch_open"])


func _street_point() -> Vector3:
	return Vector3(_rng.randf_range(-4.0, 12.0), TrailerWorld.GROUND, 13.0)


func _name(item: FoodItem) -> String:
	return item.describe(_cooking())


# Every frame ------------------------------------------------------------------

func tick(delta: float) -> void:
	var sizzling := false
	for spot: FoodSpot in game.world.grill_spots:
		if spot.item != null:
			spot.item.data["cook"] = float(spot.item.data["cook"]) + delta
			spot.item.refresh(_cooking())
			sizzling = true
	if held != null:
		held.refresh(_cooking())
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
			customer.patience -= delta
			if customer.patience <= 0.0:
				_send_away(i)
				Survival.change_need(game.save, "stress", 3.0)
				message.emit("A customer gave up waiting and left.")
				continue

	if not _hatch_open() or spots.find(null) == -1:
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
	_spawn_wait = StandRules.spawn_interval(shift, _skill()) * _rng.randf_range(0.7, 1.3)
	var free := spots.find(null)
	if free == -1:
		return
	var customer := Customer.create(_rng, StandRules.random_order(_rng), StandRules.patience(_charm()))
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


## When hours pass at once: customers go, and anything left on the grill burns.
func clear() -> void:
	for i in spots.size():
		var customer: Customer = spots[i]
		spots[i] = null
		if customer != null and is_instance_valid(customer):
			customer.queue_free()
	for spot: FoodSpot in game.world.grill_spots:
		if spot.item != null:
			spot.item.data["cook"] = 999.0
			spot.item.refresh(_cooking())
	_sizzle.stop()


# Holding ----------------------------------------------------------------------

func _hold(item: FoodItem) -> void:
	held = item
	if item.get_parent() == null:
		game.player.hand.add_child(item)
	else:
		item.reparent(game.player.hand, false)
	item.transform = Transform3D.IDENTITY
	item.set_layer(TrailerWorld.LAYER_VIEWMODEL)


func _drop_into(spot: FoodSpot) -> void:
	var item := held
	held = null
	item.reparent(game.world, false)
	item.set_layer(TrailerWorld.LAYER_WORLD)
	spot.place(item)


func _consume_held() -> void:
	held.queue_free()
	held = null


## Order bubbles for customers the camera can see: [screen point, text, colour].
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
		var hit := space.intersect_ray(query)
		var collider: Object = hit.get("collider")
		if collider != null and not (collider is Interactable and (collider as Interactable).id == "customer"):
			continue
		result.append([camera.unproject_position(point) * pixel_scale, customer.bubble_text(_charm()), customer.bubble_colour()])
	return result


## The line at the bottom of the screen about what is in your hands.
func held_text() -> String:
	return "" if held == null else "Holding: %s" % _name(held)


func can_eat_held() -> bool:
	return held != null and not StandRules.eat_effect(held.data, _cooking()).is_empty() and StandRules.eat_effect(held.data, _cooking()).size() > 1


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


# Looking and using ------------------------------------------------------------

## The prompt for things the stand handles, or "" for anything else.
func prompt_for(target: Interactable) -> String:
	if target is FoodSpot:
		return _spot_prompt(target as FoodSpot)
	if SOURCES.has(target.id):
		var source: Array = SOURCES[target.id]
		var count := Survival.stock(game.save, source[1])
		if held == null:
			return "Take a %s (%d left)" % [StandRules.NAMES[source[0]], count]
		if held.data["kind"] == source[0] and (source[0] != "sausage" and source[0] != "patty" or StandRules.cook_state(held.data, _cooking()) == "raw"):
			return "Put the %s back" % StandRules.NAMES[source[0]]
		return "Your hands are full"
	match target.id:
		"bin":
			return "Bin" if held == null else "Throw away the %s" % _name(held)
		"customer":
			var customer: Customer = target.get_meta("customer")
			if not customer.at_hatch:
				return ""
			return "Give the %s" % _name(held) if held != null else "Waiting for: %s" % StandRules.order_text(customer.order).replace("\n", " ")
	return ""


## Uses something the stand handles. Returns false if it is not the stand's.
func use(target: Interactable) -> bool:
	if target is FoodSpot:
		_use_spot(target as FoodSpot)
		return true
	if SOURCES.has(target.id):
		_use_source(SOURCES[target.id])
		return true
	match target.id:
		"bin":
			if held != null:
				message.emit("You throw away the %s." % _name(held))
				_consume_held()
			return true
		"customer":
			_give(target.get_meta("customer"))
			return true
	return false


func _use_source(source: Array) -> void:
	var kind: String = source[0]
	var stock_id: String = source[1]
	if held == null:
		if Survival.take_stock(game.save, stock_id):
			_hold(FoodItem.create(kind))
		else:
			message.emit("None left. Order more on the computer.")
	elif held.data["kind"] == kind and (not kind in StandRules.MEATS or StandRules.cook_state(held.data, _cooking()) == "raw"):
		Survival.add_stock(game.save, stock_id, 1)
		_consume_held()


func _spot_prompt(spot: FoodSpot) -> String:
	var place := "grill" if spot.grill else "counter"
	if held == null:
		return "Pick up the %s" % _name(spot.item) if spot.item != null else place.capitalize()
	if spot.item == null:
		if not spot.accepts(held.data["kind"]):
			return "Only meat goes on the grill"
		return "Put the %s on the grill" % _name(held) if spot.grill else "Put the %s down" % _name(held)
	var result: Variant = StandRules.combine(spot.item.data, held.data, _cooking())
	if result is Dictionary:
		if held.data["kind"] in StandRules.SAUCES:
			return "Add %s" % held.data["kind"]
		return "Put the %s in the roll" % _name(held)
	var reason := str(result)
	return reason if not reason.is_empty() else "There is already a %s here" % _name(spot.item)


func _use_spot(spot: FoodSpot) -> void:
	if held == null:
		if spot.item != null:
			_hold(spot.take())
		return
	if spot.item == null:
		if spot.accepts(held.data["kind"]):
			_drop_into(spot)
		return
	var result: Variant = StandRules.combine(spot.item.data, held.data, _cooking())
	if not (result is Dictionary):
		if not str(result).is_empty():
			message.emit(str(result))
		return
	spot.item.data = result
	spot.item.refresh(_cooking())
	if not held.data["kind"] in StandRules.SAUCES:
		_consume_held()


func _give(customer: Customer) -> void:
	if held == null or not customer.at_hatch:
		return
	var problem := StandRules.give_problem(customer.order, held.data, customer.has_food, customer.has_can)
	if not problem.is_empty():
		Survival.change_need(game.save, "stress", 1.5)
		message.emit("\"%s\"" % problem)
		return
	if held.data["kind"] == "can":
		customer.has_can = true
	else:
		customer.has_food = true
	_consume_held()
	if not customer.is_complete():
		return
	var paid := StandRules.price(customer.order)
	var tip := StandRules.tip(customer.patience_left(), _charm())
	game.save["survival"]["money"] = Survival.money(game.save) + paid + tip
	Sound.play("till")
	message.emit("+%d credits%s" % [paid + tip, " (tip %d)" % tip if tip > 0 else ""])
	_send_away(spots.find(customer))
