class_name FoodSpot
extends Interactable
## A place on a counter or the grill where one item can sit.

## Only meat can go on the grill, and meat there cooks.
var grill := false
var item: FoodItem = null
## Where items sit, on the surface.
var anchor := Vector3.ZERO


static func create(surface_point: Vector3, width: float, depth: float, on_grill: bool) -> FoodSpot:
	var spot := FoodSpot.new()
	spot.id = "spot"
	spot.grill = on_grill
	spot.anchor = surface_point
	spot.position = surface_point + Vector3(0.0, 0.05, 0.0)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, 0.1, depth)
	shape.shape = box
	spot.add_child(shape)
	return spot


func accepts(kind: String) -> bool:
	return not grill or kind in StandRules.MEATS


## Sets an item down here. The item must already be in the world.
func place(new_item: FoodItem) -> void:
	item = new_item
	item.global_transform = Transform3D(Basis.IDENTITY, anchor)


func take() -> FoodItem:
	var taken := item
	item = null
	return taken
