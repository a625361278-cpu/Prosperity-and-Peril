@tool
extends Node3D

signal map_entity_selected(selection: Dictionary)

const CoreDataLoader = preload("res://scripts/data/core_data_loader.gd")
const CoreStateFactory = preload("res://scripts/simulation/core_state_factory.gd")

const CITY_POSITIONS := {
	"CITY_TEST_A": Vector3(-3.6, 0.2, 0.0),
	"CITY_TEST_B": Vector3(3.6, 0.2, 0.0),
}
const FORCE_COLORS := {
	"FORCE_PLAYER": Color(0.16, 0.42, 0.95, 1.0),
	"FORCE_ENEMY": Color(0.86, 0.18, 0.14, 1.0),
}
const ROUTE_COLORS := {
	"road": Color(0.82, 0.74, 0.52, 1.0),
	"pass": Color(0.86, 0.55, 0.22, 1.0),
	"water": Color(0.23, 0.55, 0.82, 1.0),
}
const ROUTE_OFFSETS := {
	"road": Vector3(0.0, 0.05, -0.12),
	"pass": Vector3(0.0, 0.08, 0.12),
	"water": Vector3(0.0, 0.04, 0.0),
}

@export var editor_preview_enabled := true:
	set(value):
		editor_preview_enabled = value
		if Engine.is_editor_hint() and is_inside_tree():
			call_deferred("_rebuild_editor_preview")

var _generated_root: Node3D
var _rendered_state: Dictionary = {}
var _current_selection: Dictionary = {}


func _ready() -> void:
	if Engine.is_editor_hint() and editor_preview_enabled:
		call_deferred("_rebuild_editor_preview")


func render_state(state: Dictionary) -> Dictionary:
	var errors := _validate_state(state)
	if not errors.is_empty():
		return {"ok": false, "errors": errors}

	_clear_generated()
	_rendered_state = state
	_current_selection = {}
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


func select_entity(entity_type: String, entity_id: String) -> Dictionary:
	var errors := _validate_selection(entity_type, entity_id)
	if not errors.is_empty():
		return {"ok": false, "errors": errors, "selection": {}}

	_current_selection = {
		"type": entity_type,
		"id": entity_id,
	}
	_update_selection_marker()
	map_entity_selected.emit(_current_selection.duplicate(true))
	return {
		"ok": true,
		"errors": [],
		"selection": _current_selection.duplicate(true),
	}


func get_current_selection() -> Dictionary:
	return _current_selection.duplicate(true)


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	var hit := _pick_map_entity(mouse_event.position)
	if hit.is_empty():
		return
	var result := select_entity(str(hit.type), str(hit.id))
	if not result.ok:
		push_error("strategic map selection failed: %s" % [result.errors])


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
		for field in ["id", "from_city_id", "to_city_id", "route_type"]:
			if not route.has(field):
				errors.append("strategic map route missing %s %s" % [field, route_id])
		if route.has("route_type") and not ROUTE_COLORS.has(str(route.route_type)):
			errors.append("strategic map route type unsupported %s %s" % [str(route.route_type), route_id])
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
	_rendered_state = {}
	_current_selection = {}


func _add_ground() -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(11.0, 6.2)
	var node := MeshInstance3D.new()
	node.name = "Ground"
	node.mesh = mesh
	node.material_override = _material(Color(0.22, 0.27, 0.20, 1.0))
	_generated_root.add_child(node)


func _add_city(city: Dictionary) -> void:
	var city_node := Node3D.new()
	city_node.name = "City_%s" % str(city.id)
	city_node.position = CITY_POSITIONS[str(city.id)]
	_set_entity_metadata(city_node, "city", str(city.id))
	_generated_root.add_child(city_node)

	var mesh := SphereMesh.new()
	mesh.radius = 0.32
	mesh.height = 0.64
	var marker := MeshInstance3D.new()
	marker.name = "Marker"
	marker.mesh = mesh
	marker.material_override = _material(_force_color(str(city.force_id)))
	city_node.add_child(marker)

	var label := Label3D.new()
	label.name = "Label"
	label.text = "%s\n%s" % [str(city.name), _force_short_name(str(city.force_id))]
	label.position = Vector3(0.0, 0.62, 0.0)
	label.font_size = 34
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	city_node.add_child(label)

	_add_hit_area(city_node, "city", str(city.id), 0.48)


func _add_route(route: Dictionary) -> void:
	var from_pos: Vector3 = CITY_POSITIONS[str(route.from_city_id)]
	var to_pos: Vector3 = CITY_POSITIONS[str(route.to_city_id)]
	var route_type := str(route.route_type)
	var offset := _route_visual_offset(route_type)
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	mesh.surface_add_vertex(from_pos + offset)
	mesh.surface_add_vertex(to_pos + offset)
	mesh.surface_end()

	var node := MeshInstance3D.new()
	node.name = "Route_%s" % str(route.id)
	node.mesh = mesh
	node.material_override = _material(_route_color(route_type))
	node.set_meta("route_type", route_type)
	node.set_meta("route_visual_offset", offset)
	node.set_meta("blocks_enemy_passage", bool(route.get("blocks_enemy_passage", false)))
	_generated_root.add_child(node)

	if bool(route.get("blocks_enemy_passage", false)):
		_add_block_marker(node, from_pos.lerp(to_pos, 0.5) + offset)


func _add_army(state: Dictionary, army: Dictionary) -> void:
	var route: Dictionary = state.routes[army.route_id]
	var from_pos: Vector3 = CITY_POSITIONS[str(route.from_city_id)]
	var to_pos: Vector3 = CITY_POSITIONS[str(route.to_city_id)]
	var progress := 0.0
	if army.has("days_required") and int(army.days_required) > 0:
		progress = clamp(float(army.route_progress_days) / float(army.days_required), 0.0, 1.0)
	var army_position := from_pos.lerp(to_pos, progress) + Vector3(0.0, 0.45, 0.0)

	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.42, 0.42, 0.42)
	var node := MeshInstance3D.new()
	node.name = "Army_%s" % str(army.id)
	node.position = army_position
	node.mesh = mesh
	node.material_override = _material(Color(1.0, 0.86, 0.22, 1.0))
	_set_entity_metadata(node, "army", str(army.id))
	_generated_root.add_child(node)
	_add_hit_area(node, "army", str(army.id), 0.42)
	var label := Label3D.new()
	label.name = "Label"
	label.text = "%s\n兵 %s" % [str(army.id), str(army.troop_count)]
	label.position = Vector3(0.0, 0.46, 0.0)
	label.font_size = 24
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	node.add_child(label)


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	return material


func _force_color(force_id: String) -> Color:
	if not FORCE_COLORS.has(force_id):
		return Color(0.55, 0.55, 0.55, 1.0)
	return FORCE_COLORS[force_id]


func _force_short_name(force_id: String) -> String:
	if force_id == "FORCE_PLAYER":
		return "刘"
	if force_id == "FORCE_ENEMY":
		return "曹"
	return force_id


func _route_color(route_type: String) -> Color:
	if not ROUTE_COLORS.has(route_type):
		return Color(0.68, 0.68, 0.68, 1.0)
	return ROUTE_COLORS[route_type]


func _route_visual_offset(route_type: String) -> Vector3:
	if not ROUTE_OFFSETS.has(route_type):
		return Vector3(0.0, 0.05, 0.0)
	return ROUTE_OFFSETS[route_type]


func _add_block_marker(parent: Node3D, marker_position: Vector3) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.38, 0.38, 0.12)
	var marker := MeshInstance3D.new()
	marker.name = "BlockMarker"
	marker.position = marker_position + Vector3(0.0, 0.18, 0.0)
	marker.mesh = mesh
	marker.material_override = _material(Color(0.95, 0.18, 0.12, 1.0))
	parent.add_child(marker)


func _add_hit_area(parent: Node3D, entity_type: String, entity_id: String, radius: float) -> void:
	var area := Area3D.new()
	area.name = "HitArea"
	_set_entity_metadata(area, entity_type, entity_id)
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	shape.shape = sphere
	area.add_child(shape)
	parent.add_child(area)


func _set_entity_metadata(node: Node, entity_type: String, entity_id: String) -> void:
	node.set_meta("map_entity_type", entity_type)
	node.set_meta("map_entity_id", entity_id)


func _validate_selection(entity_type: String, entity_id: String) -> Array[String]:
	var errors: Array[String] = []
	if _rendered_state.is_empty():
		errors.append("strategic map selection requires rendered state")
		return errors
	if entity_type == "city":
		if not _rendered_state.cities.has(entity_id):
			errors.append("strategic map selection city missing %s" % entity_id)
		return errors
	if entity_type == "army":
		if not _rendered_state.armies.has(entity_id):
			errors.append("strategic map selection army missing %s" % entity_id)
		return errors
	errors.append("strategic map selection type unsupported %s" % entity_type)
	return errors


func _pick_map_entity(screen_position: Vector2) -> Dictionary:
	var camera := get_viewport().get_camera_3d()
	if camera == null or get_world_3d() == null:
		return {}
	var ray_origin := camera.project_ray_origin(screen_position)
	var ray_end := ray_origin + camera.project_ray_normal(screen_position) * 1000.0
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if not result.has("collider"):
		return {}
	var collider := result.collider as Node
	if collider == null:
		return {}
	return _selection_from_node(collider)


func _selection_from_node(node: Node) -> Dictionary:
	var current := node
	while current != null:
		if current.has_meta("map_entity_type") and current.has_meta("map_entity_id"):
			return {
				"type": str(current.get_meta("map_entity_type")),
				"id": str(current.get_meta("map_entity_id")),
			}
		current = current.get_parent()
	return {}


func _update_selection_marker() -> void:
	_clear_selection_markers()
	if _current_selection.is_empty() or _generated_root == null:
		return
	var target := _entity_node(str(_current_selection.type), str(_current_selection.id))
	if target == null:
		return
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.42
	mesh.bottom_radius = 0.42
	mesh.height = 0.04
	var marker := MeshInstance3D.new()
	marker.name = "SelectionMarker"
	marker.position = Vector3(0.0, 0.03, 0.0)
	marker.mesh = mesh
	marker.material_override = _material(Color(1.0, 0.95, 0.35, 0.85))
	target.add_child(marker)


func _clear_selection_markers() -> void:
	if _generated_root == null:
		return
	for child in _generated_root.find_children("SelectionMarker", "", true, false):
		var parent := child.get_parent()
		if parent != null:
			parent.remove_child(child)
		child.free()


func _entity_node(entity_type: String, entity_id: String) -> Node3D:
	if _generated_root == null:
		return null
	if entity_type == "city":
		return _generated_root.get_node_or_null("City_%s" % entity_id) as Node3D
	if entity_type == "army":
		return _generated_root.get_node_or_null("Army_%s" % entity_id) as Node3D
	return null


func _sorted_keys(values: Dictionary) -> Array:
	var keys := values.keys()
	keys.sort()
	return keys
