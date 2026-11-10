class_name FoodItem
extends Node3D
## Something you can hold, put down and cook: meat, rolls, finished food,
## cans and sauce bottles. Drawn from simple shapes that sit on their origin.

var data: Dictionary
## Render layer of its shapes: the world when it sits somewhere, your own view in your hand.
var layer := 1
var _shown := ""


static func create(kind: String) -> FoodItem:
	var item := FoodItem.new()
	item.data = StandRules.new_item(kind)
	item.refresh(0)
	return item


func set_layer(value: int) -> void:
	layer = value
	for child in get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).layers = value


func describe(cooking: int) -> String:
	return StandRules.describe(data, cooking)


## Rebuilds the shapes when the look has changed: cooking, sauces, assembly.
func refresh(cooking: int) -> void:
	var state := StandRules.cook_state(data, cooking)
	var key := "%s|%s|%s|%s|%s" % [data["kind"], state, data["ketchup"], data["mustard"], data["burnt"]]
	if key == _shown:
		return
	_shown = key
	for child in get_children():
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
			_cyl(0.06, 0.035, Vector3(0, top + 0.0175, 0), Color("#cf9852"), 0.045)
		"can":
			_cyl(0.03, 0.11, Vector3(0, 0.055, 0), Color("#b3262c"))
			_cyl(0.028, 0.006, Vector3(0, 0.113, 0), Color("#b9bdc0"))
		"ketchup", "mustard":
			var colour := Color("#b3262c") if data["kind"] == "ketchup" else Color("#d1a22a")
			_cyl(0.035, 0.18, Vector3(0, 0.09, 0), colour)
			_cyl(0.012, 0.04, Vector3(0, 0.2, 0), Color("#e8e2d4"), 0.004)


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
	add_child(mesh)


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
	add_child(mesh)
