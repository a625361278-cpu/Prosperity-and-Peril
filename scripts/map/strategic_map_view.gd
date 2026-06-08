@tool
extends Node3D

const CoreDataLoader = preload("res://scripts/data/core_data_loader.gd")
const CoreStateFactory = preload("res://scripts/simulation/core_state_factory.gd")

const CITY_POSITIONS := {
	"CITY_TEST_A": Vector3(-3.0, 0.2, 0.0),
	"CITY_TEST_B": Vector3(3.0, 0.2, 0.0),
}
const FORCE_COLORS := {
	"FORCE_PLAYER": Color(0.16, 0.42, 0.95, 1.0),
	"FORCE_ENEMY": Color(0.86, 0.18, 0.14, 1.0),
}

@export var editor_preview_enabled := true:
	set(value):
		editor_preview_enabled = value
		if Engine.is_editor_hint() and is_inside_tree():
			call_deferred("_rebuild_editor_preview")

var _generated_root: Node3D


func _ready() -> void:
	if Engine.is_editor_hint() and editor_preview_enabled:
		call_deferred("_rebuild_editor_preview")


func render_state(state: Dictionary) -> Dictionary:
	var errors := _validate_state(state)
	if not errors.is_empty():
		return {"ok": false, "errors": errors}

	_clear_generated()
	_generated_root = Node3D.new()
	_generated_root.name = "GeneratedStrategicMap"
	add_child(_generated_root)

	_add_ground()
	for route_id in _sorted_keys(state.routes):
		_add_route(state.routes[route_id])
	for city_id in _sorted_keys(state.cities):
		_add_city(state.cities[city_id])
	for army_id in _sorted_keys(state.armies):
		_add_army(state, state.armies[army_id])
	return {"ok": true, "errors": []}


func _rebuild_editor_preview() -> void:
	if not Engine.is_editor_hint() or not editor_preview_enabled:
		return
	var loaded: Dictionary = CoreDataLoader.load_and_validate("res://data/prototype_v0_1/core_test_data.json")
	if not loaded.ok:
		push_error("editor map preview data load failed: %s" % [loaded.errors])
		return
	var state_result: Dictionary = CoreStateFactory.build_from_dataset(loaded.dataset)
	if not state_result.ok:
		push_error("editor map preview state build failed: %s" % [state_result.errors])
		return
	var render_result := render_state(state_result.state)
	if not render_result.ok:
		push_error("editor map preview render failed: %s" % [render_result.errors])


func _validate_state(state: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key in ["cities", "routes", "armies"]:
		if not state.has(key):
			errors.append("strategic map state missing %s" % key)
	if not errors.is_empty():
		return errors

	for city_id in state.cities.keys():
		var city: Dictionary = state.cities[city_id]
		if not CITY_POSITIONS.has(city_id):
			errors.append("strategic map missing city position %s" % city_id)
		for field in ["id", "name", "force_id"]:
			if not city.has(field):
				errors.append("strategic map city missing %s %s" % [field, city_id])
	for route_id in state.routes.keys():
		var route: Dictionary = state.routes[route_id]
		for field in ["id", "from_city_id", "to_city_id"]:
			if not route.has(field):
				errors.append("strategic map route missing %s %s" % [field, route_id])
		if route.has("from_city_id") and not CITY_POSITIONS.has(str(route.from_city_id)):
			errors.append("strategic map route origin position missing %s" % str(route.from_city_id))
		if route.has("to_city_id") and not CITY_POSITIONS.has(str(route.to_city_id)):
			errors.append("strategic map route target position missing %s" % str(route.to_city_id))
	for army_id in state.armies.keys():
		var army: Dictionary = state.armies[army_id]
		for field in ["id", "origin_city_id", "route_id", "route_progress_days"]:
			if not army.has(field):
				errors.append("strategic map army missing %s %s" % [field, army_id])
		if army.has("route_id") and not state.routes.has(str(army.route_id)):
			errors.append("strategic map army route missing %s" % str(army.route_id))
	return errors


func _clear_generated() -> void:
	for child in get_children():
		if child.name == "GeneratedStrategicMap":
			remove_child(child)
			child.free()
	if _generated_root != null and is_instance_valid(_generated_root):
		if _generated_root.get_parent() == self:
			remove_child(_generated_root)
		_generated_root.free()
	_generated_root = null


func _add_ground() -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(8.0, 4.5)
	var node := MeshInstance3D.new()
	node.name = "Ground"
	node.mesh = mesh
	node.material_override = _material(Color(0.18, 0.27, 0.18, 1.0))
	_generated_root.add_child(node)


func _add_city(city: Dictionary) -> void:
	var city_node := Node3D.new()
	city_node.name = "City_%s" % str(city.id)
	city_node.position = CITY_POSITIONS[str(city.id)]
	_generated_root.add_child(city_node)

	var mesh := SphereMesh.new()
	mesh.radius = 0.22
	mesh.height = 0.44
	var marker := MeshInstance3D.new()
	marker.name = "Marker"
	marker.mesh = mesh
	marker.material_override = _material(_force_color(str(city.force_id)))
	city_node.add_child(marker)

	var label := Label3D.new()
	label.name = "Label"
	label.text = "%s\n%s" % [str(city.name), str(city.force_id)]
	label.position = Vector3(0.0, 0.45, 0.0)
	label.font_size = 28
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	city_node.add_child(label)


func _add_route(route: Dictionary) -> void:
	var from_pos: Vector3 = CITY_POSITIONS[str(route.from_city_id)]
	var to_pos: Vector3 = CITY_POSITIONS[str(route.to_city_id)]
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	mesh.surface_add_vertex(from_pos + Vector3(0.0, 0.04, 0.0))
	mesh.surface_add_vertex(to_pos + Vector3(0.0, 0.04, 0.0))
	mesh.surface_end()

	var node := MeshInstance3D.new()
	node.name = "Route_%s" % str(route.id)
	node.mesh = mesh
	node.material_override = _material(Color(0.82, 0.74, 0.52, 1.0))
	_generated_root.add_child(node)


func _add_army(state: Dictionary, army: Dictionary) -> void:
	var route: Dictionary = state.routes[army.route_id]
	var from_pos: Vector3 = CITY_POSITIONS[str(route.from_city_id)]
	var to_pos: Vector3 = CITY_POSITIONS[str(route.to_city_id)]
	var progress := 0.0
	if army.has("days_required") and int(army.days_required) > 0:
		progress = clamp(float(army.route_progress_days) / float(army.days_required), 0.0, 1.0)
	var position := from_pos.lerp(to_pos, progress) + Vector3(0.0, 0.45, 0.0)

	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.32, 0.32, 0.32)
	var node := MeshInstance3D.new()
	node.name = "Army_%s" % str(army.id)
	node.position = position
	node.mesh = mesh
	node.material_override = _material(Color(1.0, 0.86, 0.22, 1.0))
	_generated_root.add_child(node)


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	return material


func _force_color(force_id: String) -> Color:
	if not FORCE_COLORS.has(force_id):
		return Color(0.55, 0.55, 0.55, 1.0)
	return FORCE_COLORS[force_id]


func _sorted_keys(values: Dictionary) -> Array:
	var keys := values.keys()
	keys.sort()
	return keys
