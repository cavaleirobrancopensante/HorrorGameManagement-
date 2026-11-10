class_name Stand
extends Node
## The food stand while it is open: customers arriving at the hatch, the grill,
## and the tray you build each order on.

signal message(text: String)

## Where customers stand outside the hatch, left to right as seen from inside.
const SPOTS := [Vector3(2.55, 0.0, 3.95), Vector3(1.75, 0.0, 3.95), Vector3(0.95, 0.0, 3.95)]
const EMPTY := -1.0

var game: TrailerGame
var spots: Array = [null, null, null]
## Seconds each grill slot has been cooking, or EMPTY.
var grill: Array[float] = []
var tray := StandRules.empty_tray()
var _spawn_wait := 6.0
var _rng := RandomNumberGenerator.new()
var _sizzle: AudioStreamPlayer


func setup(owner_game: TrailerGame) -> void:
	game = owner_game
	_rng.randomize()
	for i in StandRules.GRILL_SLOTS:
		grill.append(EMPTY)
	_sizzle = AudioStreamPlayer.new()
	var stream: AudioStreamOggVorbis = load("res://assets/audio/sizzle.ogg")
	stream.loop = true
	_sizzle.stream = stream
	_sizzle.bus = "SFX"
	_sizzle.volume_db = -10.0
	add_child(_sizzle)


func _character() -> PlayerCharacter:
	return game.character


func _hatch_open() -> bool:
	return bool(game.save["world"]["hatch_open"])


func _ground(spot: Vector3) -> Vector3:
	return Vector3(spot.x, TrailerWorld.GROUND, spot.z)


func _street_point() -> Vector3:
	return Vector3(_rng.randf_range(-4.0, 12.0), TrailerWorld.GROUND, 13.0)


## Called every frame while the clock runs.
func tick(delta: float) -> void:
	var cooking := false
	for i in grill.size():
		if grill[i] != EMPTY:
			grill[i] += delta
			cooking = true
	if cooking and not _sizzle.playing:
		_sizzle.play()
	elif not cooking and _sizzle.playing:
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

	if not _hatch_open() or spots.find(null) == -1:
		return
	_spawn_wait -= delta
	if _spawn_wait <= 0.0:
		spawn()


func _skill() -> float:
	var who := _character()
	return (who.stat_value("cooking") + who.stat_value("charm") + who.stat_value("business")) / 30.0


## Brings a new customer to a free spot. instant skips the walk, for tests.
func spawn(instant := false) -> void:
	var shift := Survival.shift_index(Survival.now(game.save))
	_spawn_wait = StandRules.spawn_interval(shift, _skill()) * _rng.randf_range(0.7, 1.3)
	var free := spots.find(null)
	if free == -1:
		return
	var customer := Customer.create(_rng, StandRules.random_order(_rng), StandRules.patience(_character().stat_value("charm")))
	game.world.add_child(customer)
	spots[free] = customer
	var target := _ground(SPOTS[free])
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


## Everyone leaves at once, for when time jumps.
func clear() -> void:
	for i in spots.size():
		_send_away(i)
		var customer: Customer = spots[i]
		if customer != null and is_instance_valid(customer):
			customer.queue_free()
	for i in grill.size():
		grill[i] = EMPTY
	tray = StandRules.empty_tray()
	_sizzle.stop()


# Grill ------------------------------------------------------------------------

func slot_state(index: int) -> String:
	var seconds := grill[index]
	if seconds == EMPTY:
		return "empty"
	if seconds < StandRules.COOK_SECONDS:
		return "raw"
	if seconds < StandRules.COOK_SECONDS + StandRules.burn_window(_character().stat_value("cooking")):
		return "ready"
	return "burnt"


func cook_progress(index: int) -> float:
	return clampf(grill[index] / StandRules.COOK_SECONDS, 0.0, 1.0) if grill[index] != EMPTY else 0.0


func add_sausage() -> void:
	var free := grill.find(EMPTY)
	if free == -1:
		message.emit("The grill is full.")
	elif Survival.take_stock(game.save, "sausages"):
		grill[free] = 0.0
	else:
		message.emit("No sausages left.")


func use_slot(index: int) -> void:
	match slot_state(index):
		"raw":
			message.emit("Not cooked yet.")
		"burnt":
			grill[index] = EMPTY
			Survival.change_need(game.save, "stress", 1.0)
			message.emit("You bin the burnt sausage.")
		"ready":
			if not tray["bun"]:
				message.emit("Put a bun on the tray first.")
			elif tray["sausage"]:
				message.emit("This hot dog already has a sausage.")
			else:
				grill[index] = EMPTY
				tray["sausage"] = true


# Tray -------------------------------------------------------------------------

func add_bun() -> void:
	if tray["bun"]:
		message.emit("There is already a bun on the tray.")
	elif Survival.take_stock(game.save, "buns"):
		tray["bun"] = true
	else:
		message.emit("No bread rolls left.")


func add_sauce(sauce: String) -> void:
	if not tray["bun"]:
		message.emit("Put a bun on the tray first.")
	else:
		tray[sauce] = true


func add_can() -> void:
	if tray["can"]:
		message.emit("There is already a can on the tray.")
	elif Survival.take_stock(game.save, "soda"):
		tray["can"] = true
	else:
		message.emit("No cans left.")


func bin_tray() -> void:
	tray = StandRules.empty_tray()


func serve(index: int) -> void:
	var customer: Customer = spots[index]
	if customer == null or not is_instance_valid(customer) or not customer.at_hatch:
		return
	var wrong := StandRules.problem(customer.order, tray)
	if not wrong.is_empty():
		Survival.change_need(game.save, "stress", 1.5)
		message.emit("\"%s\"" % wrong)
		return
	var paid := StandRules.price(customer.order)
	var tip := StandRules.tip(customer.patience_left(), _character().stat_value("charm"))
	game.save["survival"]["money"] = Survival.money(game.save) + paid + tip
	tray = StandRules.empty_tray()
	Sound.play("till")
	message.emit("+%d credits%s" % [paid + tip, " (tip %d)" % tip if tip > 0 else ""])
	_send_away(index)
