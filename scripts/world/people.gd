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
			_apron(rig, recipe)
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


# Aprons -----------------------------------------------------------------------

## Where a bone sits in the rig's frame (metres, forward -Z).
static func _bone_point(rig: PersonRig, bone: String) -> Vector3:
	var skeleton := rig.skeleton
	skeleton.force_update_all_bone_transforms()
	var world := skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(bone))
	return rig.global_transform.affine_inverse() * world.origin


## A flat strap from a to b (rig frame), relative to origin.
static func _strap(a: Vector3, b: Vector3, width: float, origin: Vector3, colour: Color) -> MeshInstance3D:
	var length := a.distance_to(b)
	var node := _box(Vector3(width, 0.006, length), (a + b) * 0.5 - origin, colour)
	var direction := (b - a).normalized()
	# The flat side faces out: forward on straps that run up and down, up on
	# straps that lie over the shoulders.
	var up := Vector3.FORWARD if absf(direction.y) > 0.7 else Vector3.UP
	node.basis = Basis.looking_at(direction, up)
	return node


## The arms hang this far out (degrees) on anyone wearing an apron: men,
## women (narrower shoulders, so a little more).
const APRON_ARM_OUT := {"man": 9.0, "woman": 13.5}
## The thickness of each arm part, for keeping the apron clear of it.
const ARM_RADIUS := {"UpperArm": 0.05, "LowerArm": 0.042, "Hand": 0.038}
const NOT_TORSO := ["Shoulder", "Arm", "Hand", "Index", "Middle", "Ring", "Pinky", "Thumb", "Head", "Neck"]


## The body's surface without arms or head, posed as the rig stands now, in the
## rig's frame. Skinned here on the CPU so it works without a renderer.
static func _torso_points(rig: PersonRig) -> PackedVector3Array:
	var skeleton := rig.skeleton
	skeleton.force_update_all_bone_transforms()
	var to_rig := rig.global_transform.affine_inverse() * skeleton.global_transform
	var points := PackedVector3Array()
	for mesh_instance: MeshInstance3D in skeleton.find_children("*", "MeshInstance3D", true, false):
		if mesh_instance.name.ends_with("_Head") or mesh_instance.name.ends_with("_Feet") or mesh_instance.skin == null or not mesh_instance.visible:
			continue
		var skin := mesh_instance.skin
		var poses: Array[Transform3D] = []
		var names: Array[String] = []
		for i in skin.get_bind_count():
			var bone := skin.get_bind_bone(i)
			if bone < 0:
				bone = skeleton.find_bone(skin.get_bind_name(i))
			poses.append(skeleton.get_bone_global_pose(bone) * skin.get_bind_pose(i))
			names.append(skeleton.get_bone_name(bone))
		var mesh: Mesh = mesh_instance.mesh
		for surface in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var per := bones.size() / maxi(vertices.size(), 1)
			var posed_all := PackedVector3Array()
			var keep := PackedByteArray()
			posed_all.resize(vertices.size())
			keep.resize(vertices.size())
			for v in vertices.size():
				var heaviest := 0
				for k in per:
					if weights[v * per + k] > weights[v * per + heaviest]:
						heaviest = k
				var dominant: String = names[bones[v * per + heaviest]]
				keep[v] = 0 if NOT_TORSO.any(func(word: String) -> bool: return dominant.contains(word)) else 1
				var posed := Vector3.ZERO
				for k in per:
					var weight := weights[v * per + k]
					if weight > 0.0:
						posed += (poses[bones[v * per + k]] * vertices[v]) * weight
				posed_all[v] = to_rig * posed
			# Sample across each face too: low-poly faces are long, and the
			# corners alone leave gaps a hand's width high.
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if indices.is_empty():
				for v in vertices.size():
					indices.append(v)
			for t in range(0, indices.size() - 2, 3):
				var a := indices[t]
				var b := indices[t + 1]
				var c := indices[t + 2]
				if keep[a] == 0 or keep[b] == 0 or keep[c] == 0:
					continue
				var pa := posed_all[a]
				var pb := posed_all[b]
				var pc := posed_all[c]
				var n := clampi(ceili(maxf(pa.distance_to(pb), maxf(pb.distance_to(pc), pc.distance_to(pa))) / 0.025), 1, 10)
				for i in n + 1:
					for j in n + 1 - i:
						var u := float(i) / n
						var w := float(j) / n
						points.append(pa * (1.0 - u - w) + pb * u + pc * w)
	return points


## Points along both arms as they hang now, each with its thickness.
static func _arm_points(rig: PersonRig) -> Array:
	var out := []
	for side in ["L", "R"]:
		var upper := _bone_point(rig, "UpperArm." + side)
		var lower := _bone_point(rig, "LowerArm." + side)
		var hand := _bone_point(rig, "Hand." + side)
		var tip := hand + (hand - lower).normalized() * 0.1
		for part: Array in [[upper, lower, "UpperArm"], [lower, hand, "LowerArm"], [hand, tip, "Hand"]]:
			for i in 7:
				out.append([(part[0] as Vector3).lerp(part[1], i / 6.0), ARM_RADIUS[part[2]]])
	return out


## The front of the body at (x, y): the most forward point within reach, so
## the cloth bridges hollows and the gap between the legs as cloth would.
## points may be a PackedVector3Array or a _binned grid of them.
static func _front_at(points, x: float, y: float, reach_x: float, reach_y: float) -> float:
	var front := INF
	if points is Dictionary:
		for bx in range(floori((x - reach_x) / BIN), floori((x + reach_x) / BIN) + 1):
			for by in range(floori((y - reach_y) / BIN), floori((y + reach_y) / BIN) + 1):
				for p: Vector3 in points.get(Vector2i(bx, by), []):
					if absf(p.x - x) <= reach_x and absf(p.y - y) <= reach_y:
						front = minf(front, p.z)
		return front
	for p: Vector3 in points:
		if absf(p.x - x) <= reach_x and absf(p.y - y) <= reach_y:
			front = minf(front, p.z)
	return front


const BIN := 0.04


static func _binned(points: PackedVector3Array) -> Dictionary:
	var bins := {}
	for p in points:
		var key := Vector2i(floori(p.x / BIN), floori(p.y / BIN))
		if not bins.has(key):
			bins[key] = []
		bins[key].append(p)
	return bins


## How wide the cloth may be at height y: inside the body's sides and clear
## of every arm hanging beside it.
static func _width_at(points: PackedVector3Array, arms: Array, y: float, wanted: float) -> float:
	var body := 0.0
	for p in points:
		if absf(p.y - y) <= 0.03:
			body = maxf(body, absf(p.x))
	var width := minf(wanted, body * 0.86)
	for arm: Array in arms:
		var p: Vector3 = arm[0]
		if absf(p.y - y) <= arm[1] + 0.03:
			width = minf(width, absf(p.x) - arm[1] - 0.022)
	return maxf(width, 0.06)


## A sheet of cloth laid over the front of the body. rows is [[height,
## half width]]; the cloth stands gap in front of the body and is smoothed so
## it hangs rather than clings. Built relative to origin; coloured per row.
static func _draped(points, rows: Array, columns: int, gap: float, extra_at: Callable, origin: Vector3, colour_at: Callable) -> MeshInstance3D:
	var grid := []
	for r in rows.size():
		var y: float = rows[r][0]
		var half: float = rows[r][1]
		var line := []
		for c in columns + 1:
			var x := lerpf(-half, half, float(c) / columns)
			line.append(Vector3(x, y, _front_at(points, x, y, 0.06, 0.035)))
		# Smooth across, never moving the cloth behind the body.
		var smooth := []
		for c in line.size():
			var a: Vector3 = line[maxi(c - 1, 0)]
			var b: Vector3 = line[c]
			var d: Vector3 = line[mini(c + 1, line.size() - 1)]
			smooth.append(minf(b.z, (a.z + b.z * 2.0 + d.z) / 4.0))
		for c in line.size():
			var v: Vector3 = line[c]
			v.z = smooth[c] - gap - float(extra_at.call(r))
			line[c] = v - origin
		grid.append(line)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in grid.size() - 1:
		var colour: Color = colour_at.call(r)
		for c in columns:
			for corner in [grid[r][c], grid[r + 1][c], grid[r][c + 1], grid[r][c + 1], grid[r + 1][c], grid[r + 1][c + 1]]:
				st.set_color(colour)
				st.add_vertex(corner)
	st.generate_normals()
	var node := MeshInstance3D.new()
	node.mesh = st.commit()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.85
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	node.material_override = material
	return node


## A band hugging the body all the way round at height y.
static func _band(points: PackedVector3Array, y: float, height: float, centre: Vector3, origin: Vector3, colour: Color) -> MeshInstance3D:
	var segments := 28
	var radius := []
	for j in segments:
		radius.append(0.0)
	for p in points:
		if absf(p.y - y) <= height:
			var flat := Vector2(p.x - centre.x, p.z - centre.z)
			var j := int(posmod(flat.angle(), TAU) / TAU * segments) % segments
			radius[j] = maxf(radius[j], flat.length())
	for j in segments:
		if radius[j] == 0.0:
			radius[j] = maxf(radius[(j + segments - 1) % segments], radius[(j + 1) % segments])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in segments:
		var corners := []
		for k in [j, (j + 1) % segments]:
			var angle := (float(k) + 0.5) * TAU / segments
			var r: float = radius[k] + 0.007
			var at := Vector3(centre.x + cos(angle) * r - origin.x, 0.0, centre.z + sin(angle) * r - origin.z)
			corners.append(at + Vector3(0.0, y + height * 0.5 - origin.y, 0.0))
			corners.append(at + Vector3(0.0, y - height * 0.5 - origin.y, 0.0))
		for corner in [corners[0], corners[1], corners[2], corners[2], corners[1], corners[3]]:
			st.set_color(colour)
			st.add_vertex(corner)
	st.generate_normals()
	var node := MeshInstance3D.new()
	node.mesh = st.commit()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.85
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	node.material_override = material
	return node


## A butcher's bib apron: a bib from the chest, a skirt to the knee with a
## darker hem, a neck strap, and a waistband tied at the back. It is laid over
## the body's own shape, kept inside the line of the arms, and the arms hang a
## little wider, so no arm passes through it in any pose. The skirt hangs from
## the hips and the bib from the torso, so both move with the body.
static func _apron(rig: PersonRig, recipe: Dictionary) -> void:
	var cloth := Color(recipe.get("apron_colour", "#d8d0bc"))
	var hem_colour := cloth.darkened(0.12)
	var band_colour := cloth.darkened(0.08)
	rig.arm_out = APRON_ARM_OUT.get(recipe.get("sex", "man"), 9.0)
	rig._apply(0.0)
	var points := _torso_points(rig)
	var grid := _binned(points)
	var arms := _arm_points(rig)
	var hips := _bone_point(rig, "Hips")
	var torso := _bone_point(rig, "Torso")
	var chest := _bone_point(rig, "Chest")
	var neck := _bone_point(rig, "Neck")
	var knee := _bone_point(rig, "LowerLeg.L")
	var waist := _bone_point(rig, "Abdomen").y + 0.04

	# The skirt, from the waist to just above the knee, standing a little
	# further off the body as it falls, so the legs can move behind it.
	var skirt := Node3D.new()
	skirt.name = "Apron"
	var rows := []
	var steps := 8
	for k in steps + 1:
		var y := lerpf(waist, knee.y + 0.03, float(k) / steps)
		rows.append([y, _width_at(points, arms, y, 0.2)])
	var flare := func(r: int) -> float: return 0.035 * float(r) / steps
	var sheet := _draped(grid, rows, 14, 0.012, flare, hips, func(r: int) -> Color: return hem_colour if r == steps - 1 else cloth)
	# Hung from a hinge at the front of the waist, so it can swing forward
	# with the leading thigh as they walk.
	var hinge := Node3D.new()
	hinge.position = Vector3(0.0, waist, _front_at(grid, 0.0, waist, 0.06, 0.035)) - hips
	sheet.position = -hinge.position
	hinge.add_child(sheet)
	skirt.add_child(hinge)
	rig.apron_swing = hinge
	# The waistband round the body, and its ties hanging at the back.
	skirt.add_child(_band(points, waist, 0.04, hips, hips, band_colour))
	var back := -INF
	for p in points:
		if absf(p.y - waist) < 0.03 and absf(p.x) < 0.05:
			back = maxf(back, p.z)
	for side in [-1.0, 1.0]:
		var tail := _box(Vector3(0.035, 0.24, 0.006), Vector3(side * 0.035, waist - 0.13, back + 0.014) - hips, band_colour)
		tail.rotation.z = side * 0.18
		skirt.add_child(tail)
	rig.attach("Hips", skirt)

	# The bib, from the waist up over the chest, narrowing.
	var bib := Node3D.new()
	bib.name = "ApronBib"
	var bib_top := chest.y + 0.04
	var bib_rows := []
	for k in 7:
		var t := float(k) / 6
		var y := lerpf(waist + 0.01, bib_top, t)
		bib_rows.append([y, _width_at(points, arms, y, lerpf(0.15, 0.1, t))])
	var bib_sheet := _draped(grid, bib_rows, 12, 0.01, func(_r: int) -> float: return 0.0, torso, func(_r: int) -> Color: return cloth)
	bib.add_child(bib_sheet)
	# The strap round the neck, from the bib's top corners.
	var top: Array = bib_rows[6]
	for side in [-1.0, 1.0]:
		var x: float = side * top[1]
		var corner := Vector3(x, bib_top, _front_at(grid, x, bib_top, 0.06, 0.035) - 0.01)
		var collar := Vector3(side * 0.065, neck.y + 0.01, neck.z - 0.02)
		var nape := Vector3(0.0, neck.y + 0.02, neck.z + 0.06)
		bib.add_child(_strap(corner, collar, 0.022, torso, band_colour))
		bib.add_child(_strap(collar, nape, 0.022, torso, band_colour))
	rig.attach("Torso", bib)


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
