class_name Customer
extends Node3D
## Someone who walks up to the hatch, waits with an order over their head,
## and takes food handed through the hatch. Drawn with the same pixel figures
## as the player, in their own clothes.

const WALK_SPEED := 1.3
const SHIRTS := ["#4a5a6e", "#6e3b33", "#3f5a43", "#5c5048", "#2f2f38", "#7a6a3a", "#4e3a5c"]

var order := {}
## 0 to 100. Waiting wears it down; they leave at 0. Shown as a face.
var mood := 80.0
## Mood lost per second of waiting.
var decay := 1.0
var at_hatch := false
var leaving := false
var has_food := false
var has_can := false
var _tween: Tween


static func create(look_rng: RandomNumberGenerator, wanted: Dictionary, start_mood: float, mood_decay: float) -> Customer:
	var customer := Customer.new()
	customer.order = wanted
	customer.mood = start_mood
	customer.decay = mood_decay

	var person := PlayerCharacter.new()
	person.randomize_appearance(look_rng)
	var canvas := SubViewport.new()
	canvas.size = Vector2i(80, 320)
	canvas.transparent_bg = true
	canvas.disable_3d = true
	canvas.render_target_update_mode = SubViewport.UPDATE_ONCE
	var portrait := CharacterPortrait.new()
	portrait.full_body = true
	portrait.apron = false
	portrait.shirt_colour = Color(SHIRTS[look_rng.randi_range(0, SHIRTS.size() - 1)])
	portrait.size = Vector2(80, 320)
	portrait.character = person
	canvas.add_child(portrait)
	customer.add_child(canvas)

	var sprite := Sprite3D.new()
	sprite.texture = canvas.get_texture()
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.shaded = true
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.pixel_size = Player.BODY_PIXEL_SIZE
	sprite.position.y = 320.0 * Player.BODY_PIXEL_SIZE / 2.0
	customer.add_child(sprite)

	# What the player looks at to hand food over.
	var reach := Interactable.new()
	reach.id = "customer"
	reach.set_meta("customer", customer)
	reach.position.y = 1.35
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.5, 1.1, 0.3)
	shape.shape = box
	reach.add_child(shape)
	customer.add_child(reach)

	return customer


func walk_to(target: Vector3, then: Callable = Callable()) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	var seconds := position.distance_to(target) / WALK_SPEED
	_tween.tween_property(self, "position", target, seconds)
	if then.is_valid():
		_tween.tween_callback(then)


## Walks back out to the street and disappears.
func leave(street: Vector3) -> void:
	leaving = true
	at_hatch = false
	walk_to(street, queue_free)


func upset(amount: float) -> void:
	mood = maxf(mood - amount, 0.0)


func is_complete() -> bool:
	return has_food and (has_can or not order["can"])


## The point the order bubble hangs from, above the head.
func bubble_point() -> Vector3:
	return global_position + Vector3(0.0, 2.0, 0.0)


## The order, what has arrived and the tip on offer, for the bubble.
func bubble_text(charm: int) -> String:
	var lines := StandRules.order_text(order)
	if has_food:
		lines = lines.replace(lines.get_slice("\n", 0), "Food: done")
	if has_can:
		lines = lines.replace("+ a can", "Can: done")
	return "%s\nTip %d" % [lines, StandRules.tip(mood, charm)]


func bubble_colour() -> Color:
	match StandRules.face(mood):
		"happy":
			return UiKit.TALLOW
		"neutral":
			return UiKit.SODIUM
	return Color("#ff6a70")
