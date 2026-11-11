class_name People
extends RefCounted
## Builds people from the CC0 modular men and women. Every outfit has four
## parts on one skeleton (Head, Body with the arms, Legs, Feet), so any part
## goes with any other of the same sex: a recipe names the outfit each part
## comes from, recolours skin, hair and clothes, and adds extras made in code
## in the same flat-coloured, low-poly finish (a cassock skirt, a headscarf, a
## hood, a cloth over the face, an apron, hats, and things to hold).
##
## Recipe keys: sex ("man" or "woman"), head, body, legs, feet (outfit names),
## skin, hair, top, top2, legs_colour, feet_colour (colours), mask (the head's
## skin goes dark: a balaclava), extras (list), hold (rest, bag, pipe, pistol).

const MEN := ["Adventurer", "Casual", "Casual2", "Farmer", "Punk", "Suit", "Swat", "Worker"]
const WOMEN := ["Adventurer", "Casual", "Formal", "Medieval", "Punk", "SciFi", "Soldier", "Suit", "Witch", "Worker"]
## Outfits ordinary people on the street wear.
const STREET_MEN := ["Adventurer", "Casual", "Casual2", "Farmer", "Punk", "Suit", "Worker"]
const STREET_WOMEN := ["Adventurer", "Casual", "Formal", "Punk", "SciFi", "Suit", "Worker"]
const HEIGHT := 1.75

const CLOTHES := ["#3b3f4a", "#4a3b32", "#2f4a3a", "#5a2f2f", "#6b6b70", "#2a2d36", "#7a6a4a", "#33475e", "#5e4a5e", "#8a8478", "#2b2b2e", "#6e3b2a"]

static var _scenes := {}
static var _scale := {}


static func _scene(sex: String, outfit: String) -> PackedScene:
	var path := "res://assets/people/%s/%s.glb" % ["men" if sex == "man" else "women", outfit]
	if not _scenes.has(path):
		_scenes[path] = load(path)
	return _scenes[path]


## Which part a mesh is: names end in _Head, _Body, _Legs (or _Pants), _Feet.
static func _part(mesh_name: String) -> String:
	for part in ["Head", "Body", "Legs", "Feet"]:
		if mesh_name.ends_with("_" + part):
			return part
	if mesh_name.ends_with("_Pants"):
		return "Legs"
	return ""


static func build(recipe: Dictionary) -> PersonRig:
	var sex: String = recipe.get("sex", "man")
	var rig := PersonRig.new()
	var base: Node3D = _scene(sex, recipe.get("body", "Casual")).instantiate()
	rig.add_child(base)
	var skeleton: Skeleton3D = base.find_children("*", "Skeleton3D", true, false)[0]
	# Keep the base's body; take every other part from its own outfit.
	for node in skeleton.get_children():
		if node is MeshInstance3D:
			var part := _part(node.name)
			if part == "" or part != "Body":
				node.free()
	for part in ["Head", "Legs", "Feet"]:
		var outfit: String = recipe.get(part.to_lower(), recipe.get("body", "Casual"))
		var donor: Node3D = _scene(sex, outfit).instantiate()
		for node in donor.find_children("*", "MeshInstance3D", true, false):
			if _part(node.name) == part:
				var mesh := node as MeshInstance3D
				var skin := mesh.skin
				mesh.owner = null
				mesh.get_parent().remove_child(mesh)
				skeleton.add_child(mesh)
				mesh.skin = skin
				mesh.skeleton = NodePath("..")
				break
		donor.free()
	_recolour(skeleton, recipe)
	# Facing -Z like everything else.
	base.rotation.y = PI
	base.name = "Model"
	return rig


## Call once the rig is in the scene tree: sets up the skeleton and the extras.
static func finish(rig: PersonRig, recipe: Dictionary) -> void:
	var sex: String = recipe.get("sex", "man")
	var base: Node3D = rig.get_node("Model")
	if not _scale.has(sex):
		_scale[sex] = HEIGHT / _rest_height(base)
	base.scale = Vector3.ONE * float(_scale[sex]) * float(recipe.get("height", 1.0))
	var skeleton: Skeleton3D = rig.find_children("*", "Skeleton3D", true, false)[0]
	rig.setup(skeleton, recipe.get("sex", "man"))
	rig.hold_pose = recipe.get("hold", "rest")
	for extra: String in recipe.get("extras", []):
		_extra(rig, extra, recipe)
	match recipe.get("hold", "rest"):
		"bag":
			rig.attach("Hand.R", _box(Vector3(0.2, 0.22, 0.09), Vector3(0.0, -0.14, 0.0), Color("#8a7a5a")))
		"pipe":
			rig.attach("Hand.R", _rod(0.02, 0.62, Vector3(0.0, -0.02, -0.26), Vector3(-75.0, 0.0, 0.0), Color("#6e4a34")))
		"pistol":
			var gun := Node3D.new()
			gun.add_child(_box(Vector3(0.035, 0.05, 0.16), Vector3(0.0, 0.0, -0.08), Color("#1c1c20")))
			gun.add_child(_box(Vector3(0.03, 0.09, 0.04), Vector3(0.0, -0.05, -0.01), Color("#2a2420")))
			rig.attach("Hand.R", gun)


## Height of the model as it stands, measured in the world (it must be in the tree).
static func _rest_height(base: Node3D) -> float:
	var low := INF
	var high := -INF
	for node in base.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var box: AABB = mesh.global_transform * mesh.get_aabb()
		low = minf(low, box.position.y)
		high = maxf(high, box.end.y)
	return maxf(high - low, 0.0001) / base.global_basis.get_scale().y


static func _recolour(skeleton: Skeleton3D, recipe: Dictionary) -> void:
	for node in skeleton.get_children():
		if not node is MeshInstance3D:
			continue
		var mesh := node as MeshInstance3D
		var part := _part(mesh.name)
		var clothing := 0
		for surface in mesh.mesh.get_surface_count():
			var material := mesh.mesh.surface_get_material(surface)
			if not material is BaseMaterial3D:
				continue
			var name: String = material.resource_name
			var colour: Variant = null
			if name.begins_with("Skin"):
				colour = recipe.get("skin", null)
				if part == "Head" and recipe.get("mask", false):
					colour = recipe.get("mask_colour", "#151417")
				if colour != null and name == "Skin_Darker":
					colour = Color(colour).darkened(0.15)
			elif name.begins_with("Hair") or name in ["Eyebrows", "Moustache"]:
				colour = recipe.get("hair", null)
				if part == "Head" and recipe.get("mask", false) and name.begins_with("Hair"):
					colour = recipe.get("mask_colour", "#151417")
			elif name in ["Eye", "Visor", "Earrings", "Gold", "Metal", "Metal_Dark"]:
				pass
			else:
				var key := ""
				match part:
					"Body":
						key = "top" if clothing == 0 else "top2"
					"Legs":
						key = "legs_colour"
					"Feet":
						key = "feet_colour"
					"Head":
						key = "hat_colour"
				clothing += 1
				colour = recipe.get(key, null)
			if colour != null:
				var copy: BaseMaterial3D = material.duplicate()
				copy.albedo_color = Color(colour)
				mesh.set_surface_override_material(surface, copy)


# Extras made in code ----------------------------------------------------------

static func _material(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.8
	return material


static func _box(size: Vector3, at: Vector3, colour: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	node.mesh = box
	node.position = at
	node.material_override = _material(colour)
	return node


static func _rod(radius: float, length: float, at: Vector3, turn: Vector3, colour: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var rod := CylinderMesh.new()
	rod.top_radius = radius
	rod.bottom_radius = radius
	rod.height = length
	rod.radial_segments = 8
	node.mesh = rod
	node.position = at
	node.rotation_degrees = turn
	node.material_override = _material(colour)
	return node


## A cone or shell spun around Y, in the low-poly finish of the models.
static func _shell(rings: Array, segments: int, colour: Color, arc := TAU, arc_start := 0.0) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points := []
	for ring: Vector2 in rings:
		var row := []
		for j in segments + 1:
			var angle := arc_start + arc * float(j) / segments
			row.append(Vector3(sin(angle) * ring.y, ring.x, -cos(angle) * ring.y))
		points.append(row)
	for i in points.size() - 1:
		for j in segments:
			for corner in [points[i][j], points[i + 1][j], points[i][j + 1], points[i][j + 1], points[i + 1][j], points[i + 1][j + 1]]:
				st.add_vertex(corner)
	st.generate_normals()
	var node := MeshInstance3D.new()
	node.mesh = st.commit()
	var material := _material(colour)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	node.material_override = material
	return node


static func _extra(rig: PersonRig, extra: String, recipe: Dictionary) -> void:
	var colour := Color(recipe.get("extra_colour", "#18161c"))
	match extra:
		"cassock":
			# The long skirt of the cassock, from the waist to the ankles.
			var skirt := _shell([Vector2(0.06, 0.17), Vector2(-0.3, 0.2), Vector2(-0.6, 0.23), Vector2(-0.86, 0.26)], 12, colour)
			rig.attach("Hips", skirt)
		"collar":
			rig.attach("Neck", _box(Vector3(0.05, 0.035, 0.02), Vector3(0.0, -0.02, -0.07), Color("#f1ece2")))
		"rosary":
			var beads := Node3D.new()
			for i in 10:
				beads.add_child(_box(Vector3(0.02, 0.02, 0.02), Vector3(0.13, -0.05 - i * 0.045, -0.13), Color("#2a1e16")))
			beads.add_child(_box(Vector3(0.025, 0.06, 0.012), Vector3(0.13, -0.52, -0.13), Color("#2a1e16")))
			rig.attach("Hips", beads)
		"headscarf":
			var scarf := _shell([Vector2(-0.1, 0.0), Vector2(-0.1, 0.1), Vector2(0.02, 0.118), Vector2(0.12, 0.12), Vector2(0.2, 0.1), Vector2(0.25, 0.05), Vector2(0.26, 0.0)], 12, colour, PI * 1.45, PI * 0.28)
			rig.attach("Head", scarf)
		"hood":
			var hood := _shell([Vector2(-0.14, 0.0), Vector2(-0.12, 0.16), Vector2(0.0, 0.135), Vector2(0.12, 0.135), Vector2(0.22, 0.11), Vector2(0.28, 0.06), Vector2(0.29, 0.0)], 12, colour, PI * 1.4, PI * 0.3)
			rig.attach("Head", hood)
		"face_cloth":
			rig.attach("Head", _box(Vector3(0.17, 0.09, 0.04), Vector3(0.0, 0.02, -0.1), Color(recipe.get("cloth_colour", "#1e1d22"))))
		"apron":
			var apron := Node3D.new()
			apron.add_child(_box(Vector3(0.34, 0.62, 0.015), Vector3(0.0, -0.18, -0.13), Color(recipe.get("apron_colour", "#d8d0bc"))))
			rig.attach("Hips", apron)
		"brim_hat":
			var hat := Node3D.new()
			hat.add_child(_rod(0.17, 0.015, Vector3(0.0, 0.2, 0.0), Vector3.ZERO, colour))
			hat.add_child(_rod(0.1, 0.1, Vector3(0.0, 0.25, 0.0), Vector3.ZERO, colour))
			rig.attach("Head", hat)
		"peaked_cap":
			var cap := Node3D.new()
			cap.add_child(_rod(0.11, 0.07, Vector3(0.0, 0.22, 0.0), Vector3.ZERO, colour))
			cap.add_child(_box(Vector3(0.16, 0.012, 0.08), Vector3(0.0, 0.19, -0.11), colour.darkened(0.3)))
			cap.add_child(_box(Vector3(0.04, 0.04, 0.01), Vector3(0.0, 0.23, -0.112), Color("#c9c4b8")))
			rig.attach("Head", cap)
		"beanie":
			rig.attach("Head", _shell([Vector2(0.12, 0.0), Vector2(0.12, 0.112), Vector2(0.2, 0.105), Vector2(0.26, 0.06), Vector2(0.27, 0.0)], 12, colour))


## Builds a person, puts them in parent at a point facing yaw, and finishes them.
static func place(parent: Node, recipe: Dictionary, at: Vector3, yaw := 0.0) -> PersonRig:
	var rig := build(recipe)
	parent.add_child(rig)
	rig.global_position = at
	rig.rotation.y = yaw
	finish(rig, recipe)
	return rig


# Recipes ----------------------------------------------------------------------

## A random member of the public: any head, top, legs and shoes of one sex.
static func stranger(rng: RandomNumberGenerator) -> Dictionary:
	var woman := rng.randf() < 0.45
	var outfits: Array = STREET_WOMEN if woman else STREET_MEN
	var skins: Array = GameData.SKIN_TONES.values()
	var hairs: Array = GameData.HAIR_COLOURS.values()
	var recipe := {
		"sex": "woman" if woman else "man",
		"head": outfits[rng.randi() % outfits.size()],
		"body": outfits[rng.randi() % outfits.size()],
		"legs": outfits[rng.randi() % outfits.size()],
		"feet": outfits[rng.randi() % outfits.size()],
		"skin": skins[rng.randi() % skins.size()],
		"hair": hairs[rng.randi() % hairs.size()],
		"height": rng.randf_range(0.94, 1.05),
	}
	if rng.randf() < 0.75:
		recipe["top"] = CLOTHES[rng.randi() % CLOTHES.size()]
	if rng.randf() < 0.6:
		recipe["legs_colour"] = CLOTHES[rng.randi() % CLOTHES.size()]
	if rng.randf() < 0.2:
		recipe["hold"] = "bag"
	return recipe


## The people with parts to play.
static func role(name: String, rng: RandomNumberGenerator) -> Dictionary:
	var skins: Array = GameData.SKIN_TONES.values()
	match name:
		"priest":
			return {"sex": "man", "head": "Suit", "body": "Suit", "legs": "Suit", "feet": "Suit", "skin": "#e2b796", "hair": "#85808a", "top": "#18161c", "top2": "#18161c", "legs_colour": "#18161c", "extras": ["cassock", "collar", "rosary"], "extra_colour": "#18161c", "height": 0.97}
		"informant":
			return {"sex": "man", "head": "Suit", "body": "Suit", "legs": "Suit", "feet": "Suit", "skin": "#efd9c8", "hair": "#46301f", "top": "#5a5c60", "top2": "#d8d4cc", "legs_colour": "#55575c", "extras": ["brim_hat"], "extra_colour": "#4a4c50"}
		"inspector":
			return {"sex": "man", "head": "Casual", "body": "Suit", "legs": "Suit", "feet": "Swat", "skin": skins[rng.randi() % skins.size()], "hair": "#1c1719", "top": "#4a5058", "top2": "#4a5058", "legs_colour": "#4a5058", "extras": ["peaked_cap"], "extra_colour": "#3e434a"}
		"old_woman":
			return {"sex": "woman", "head": "Casual", "body": "Medieval", "legs": "Medieval", "feet": "Suit", "skin": "#f0d2bb", "hair": "#d6d1d3", "top": "#2f4a3a", "legs_colour": "#2f4a3a", "extras": ["headscarf"], "extra_colour": "#7a3b4a", "hold": "bag", "height": 0.92}
		"thug":
			var woman := rng.randf() < 0.2
			var outfits: Array = ["Punk", "Casual", "Casual2", "Adventurer"] if not woman else ["Punk", "Casual", "Adventurer"]
			return {"sex": "woman" if woman else "man", "head": "Casual", "body": outfits[rng.randi() % outfits.size()], "legs": "Casual", "feet": "Punk", "skin": skins[rng.randi() % skins.size()], "hair": "#1c1719", "top": ["#55575c", "#3b3f4a", "#26332b", "#3b2a26"][rng.randi() % 4], "legs_colour": "#2d2f33", "extras": ["hood", "face_cloth"], "extra_colour": "#4a4c52", "hold": "pipe"}
		"shooter":
			return {"sex": "man", "head": "Casual", "body": "Punk", "legs": "Swat", "feet": "Swat", "skin": skins[rng.randi() % skins.size()], "mask": true, "top": "#1a1a1e", "top2": "#2a2a2e", "legs_colour": "#26282c", "hold": "pistol"}
		"burglar":
			return {"sex": "man", "head": "Casual", "body": "Casual", "legs": "Suit", "feet": "Swat", "skin": "#c79a6e", "mask": true, "top": "#141416", "legs_colour": "#18181b", "extras": ["beanie"], "extra_colour": "#121214"}
	return stranger(rng)


## You, from your character: the face, clothes and colours you chose, and
## an apron over them.
static func player(character: PlayerCharacter) -> Dictionary:
	var look: Dictionary = character.appearance
	var sex: String = look.get("sex", "man")
	var recipe := {
		"sex": sex,
		"head": look.get("head", "Casual"),
		"body": look.get("top", "Casual"),
		"legs": look.get("legs", "Casual"),
		"feet": look.get("feet", "Casual"),
		"skin": GameData.SKIN_TONES.get(look.get("skin", "fair"), "#e2b796"),
		"hair": GameData.HAIR_COLOURS.get(look.get("hair_colour", "brown"), "#46301f"),
		"extras": ["apron"],
		"apron_colour": GameData.APRON_COLOURS.get(look.get("apron", "white"), "#d8d0bc"),
	}
	var colour: String = look.get("top_colour", "as_made")
	if GameData.TOP_COLOURS.has(colour):
		recipe["top"] = GameData.TOP_COLOURS[colour]
	return recipe
