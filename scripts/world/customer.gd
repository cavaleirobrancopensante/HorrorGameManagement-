class_name Customer
extends Node3D
## Someone who walks up to the hatch, waits with an order, then walks off.
## Drawn with the same pixel figures as the player, in their own clothes.

signal arrived

const WALK_SPEED := 1.3
const SHIRTS := ["#4a5a6e", "#6e3b33", "#3f5a43", "#5c5048", "#2f2f38", "#7a6a3a", "#4e3a5c"]

var order := {}
var patience := 0.0
var max_patience := 1.0
var at_hatch := false
var leaving := false
var _tween: Tween


static func create(look_rng: RandomNumberGenerator, wanted: Dictionary, wait_seconds: float) -> Customer:
	var customer := Customer.new()
	customer.order = wanted
	customer.patience = wait_seconds
	customer.max_patience = wait_seconds

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


func patience_left() -> float:
	return patience / max_patience
