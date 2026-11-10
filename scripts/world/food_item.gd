class_name FoodItem
extends Node3D
## Something you can hold, put down and cook: meat, rolls, finished food,
## cans and sauce bottles. Drawn from simple shapes that sit on their origin.

var data: Dictionary
## Render layer of its shapes: the world when it sits somewhere, your own view in your hand.
var layer := 1
## What you look at to pick it up. Off while it is in your hand.
var pick: Interactable
var _shown := ""
var _shapes: Node3D


static func create(kind: String) -> FoodItem:
	var item := FoodItem.new()
	item.add_to_group("food")
	item.data = StandRules.new_item(kind)
	if StandRules.is_sauce(item.data):
		item.data["left"] = StandRules.BOTTLE_SIZE
	item._shapes = Node3D.new()
	item.add_child(item._shapes)
	item.pick = Interactable.new()
	item.pick.id = "item"
	item.pick.set_meta("item", item)
	item.pick.collision_layer = Surface.PICK_LAYER
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	var tall := StandRules.is_sauce(item.data) or kind == "can"
	box.size = Vector3(0.16, 0.26, 0.14) if tall else Vector3(0.22, 0.1, 0.14)
	shape.shape = box
	shape.position.y = box.size.y / 2.0
	item.pick.add_child(shape)
	item.add_child(item.pick)
	item.refresh(0)
	return item


func set_layer(value: int) -> void:
	layer = value
	for child in _shapes.get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).layers = value


## In your hand it cannot be looked at; set down, it can.
func set_held(held: bool) -> void:
	set_layer(TrailerWorld.LAYER_VIEWMODEL if held else TrailerWorld.LAYER_WORLD)
	pick.collision_layer = 0 if held else Surface.PICK_LAYER


func describe(cooking: int) -> String:
	return StandRules.describe(data, cooking)


## Rebuilds the shapes when the look has changed: cooking, sauces, assembly.
func refresh(cooking: int, pro := false) -> void:
	var state := StandRules.cook_state(data, cooking, pro)
	var key := "%s|%s|%s|%s|%s|%s|%s|%s" % [data["kind"], state, data["ketchup"], data["mustard"], data["mayo"], data["burnt"], data["dirty"], data.get("left", 0) > 0]
	if key == _shown:
		return
	_shown = key
	for child in _shapes.get_children():
		child.queue_free()
	var meat := _meat_colour(data["kind"], "burnt" if data["burnt"] else (state if not state.is_empty() else "cooked"))
	match data["kind"]:
		"sausage":
			_box(Vector3(0.15, 0.035, 0.035), Vector3(0, 0.018, 0), meat)
		"patty":
			_cyl(0.055, 0.022, Vector3(0, 0.011, 0), meat)
		"bun":
			_box(Vector3(0.17, 0.05, 0.07), Vector3(0, 0.025, 0), Color("#c48c4c"))
		"hot_dog":
			_box(Vector3(0.17, 0.05, 0.07), Vector3(0, 0.025, 0), Color("#c48c4c"))
			_box(Vector3(0.19, 0.035, 0.035), Vector3(0, 0.06, 0), meat)
			if data["ketchup"]:
				_box(Vector3(0.13, 0.008, 0.012), Vector3(0, 0.081, -0.008), Color("#b3262c"))
			if data["mustard"]:
				_box(Vector3(0.13, 0.008, 0.012), Vector3(0, 0.082, 0.008), Color("#d1a22a"))
			if data["mayo"]:
				_box(Vector3(0.11, 0.008, 0.01), Vector3(0, 0.083, 0.0), Color("#efe8d0"))
		"burger":
			_cyl(0.06, 0.025, Vector3(0, 0.0125, 0), Color("#c48c4c"))
			_cyl(0.058, 0.022, Vector3(0, 0.036, 0), meat)
			var top := 0.047
			if data["ketchup"]:
				_cyl(0.056, 0.005, Vector3(0, top + 0.0025, 0), Color("#b3262c"))
				top += 0.005
			if data["mustard"]:
				_cyl(0.056, 0.005, Vector3(0, top + 0.0025, 0), Color("#d1a22a"))
				top += 0.005
			if data["mayo"]:
				_cyl(0.056, 0.005, Vector3(0, top + 0.0025, 0), Color("#efe8d0"))
				top += 0.005
			_cyl(0.06, 0.035, Vector3(0, top + 0.0175, 0), Color("#cf9852"), 0.045)
		"can":
			_cyl(0.03, 0.11, Vector3(0, 0.055, 0), Color("#b3262c"))
			_cyl(0.028, 0.006, Vector3(0, 0.113, 0), Color("#b9bdc0"))
		"ketchup", "mustard", "mayo":
			var colours := {"ketchup": "#b3262c", "mustard": "#d1a22a", "mayo": "#efe8d0"}
			var colour := Color(colours[data["kind"]])
			if int(data.get("left", 0)) <= 0:
				colour = colour.lerp(Color("#9aa0a4"), 0.7)
			_cyl(0.035, 0.18, Vector3(0, 0.09, 0), colour)
			_cyl(0.012, 0.04, Vector3(0, 0.2, 0), Color("#e8e2d4"), 0.004)
	if data["dirty"]:
		for i in 3:
			_box(Vector3(0.02, 0.012, 0.02), Vector3(-0.05 + i * 0.05, 0.05, 0.03 - i * 0.025), Color("#2a2418"))


func _meat_colour(kind: String, state: String) -> Color:
	var colours := {
		"raw": "#c97a74" if kind != "patty" else "#b5655c",
		"cooked": "#8a4a24" if kind != "patty" else "#5a3418",
		"burnt": "#241612",
	}
	return Color(colours.get(state, "#8a4a24"))


func _box(size: Vector3, at: Vector3, colour: Color) -> void:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.position = at
	mesh.material_override = TextureFactory.plain(colour, 0.7)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.layers = layer
	_shapes.add_child(mesh)


func _cyl(radius: float, height: float, at: Vector3, colour: Color, top_radius := -1.0) -> void:
	var mesh := MeshInstance3D.new()
	var shape := CylinderMesh.new()
	shape.bottom_radius = radius
	shape.top_radius = radius if top_radius < 0.0 else top_radius
	shape.height = height
	shape.radial_segments = 10
	shape.rings = 1
	mesh.mesh = shape
	mesh.position = at
	mesh.material_override = TextureFactory.plain(colour, 0.7)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.layers = layer
	_shapes.add_child(mesh)
