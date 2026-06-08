extends RefCounted

const WATER_ROUTE_TYPES := ["river", "sea"]


static func evaluate_route_access(state: Dictionary, force_id: String, route_id: String) -> Dictionary:
	var errors := _validate_request(state, force_id, route_id)
	if not errors.is_empty():
		return {"ok": false, "errors": errors}

	var route: Dictionary = state.routes[route_id]
	var route_type := str(route.route_type)
	var node_type := str(route.get("strategic_node_type", "none"))
	var control_force_id := str(route.get("control_force_id", ""))
	var blocks_enemy := bool(route.get("blocks_enemy_passage", false))

	if route_type == "pass" and blocks_enemy and not control_force_id.is_empty() and control_force_id != force_id:
		return _access_result(false, "blocked_by_enemy_pass", "pass", route)
	if node_type == "port" and blocks_enemy and not control_force_id.is_empty() and control_force_id != force_id:
		return _access_result(false, "blocked_by_enemy_port", "port", route)
	if WATER_ROUTE_TYPES.has(route_type):
		var battle_type := "river"
		if str(route.battle_trigger) == "port":
			battle_type = "port"
		return _access_result(true, "water_route", battle_type, route)
	if route_type == "pass":
		return _access_result(true, "pass_route", "pass", route)
	return _access_result(true, "open", str(route.battle_trigger), route)


static func _access_result(can_pass: bool, access_state: String, required_battle_type: String, route: Dictionary) -> Dictionary:
	return {
		"ok": true,
		"errors": [],
		"can_pass": can_pass,
		"access_state": access_state,
		"required_battle_type": required_battle_type,
		"route_id": str(route.id),
	}


static func _validate_request(state: Dictionary, force_id: String, route_id: String) -> Array[String]:
	var errors: Array[String] = []
	for key in ["forces", "cities", "routes"]:
		if not state.has(key):
			errors.append("runtime state missing %s" % key)
	if not errors.is_empty():
		return errors
	if not state.forces.has(force_id):
		errors.append("route access force not found %s" % force_id)
	if not state.routes.has(route_id):
		errors.append("route access route not found %s" % route_id)
		return errors

	var route: Dictionary = state.routes[route_id]
	for field in ["id", "from_city_id", "to_city_id", "route_type", "battle_trigger"]:
		if not route.has(field):
			errors.append("route access route missing %s %s" % [field, route_id])
	if route.has("from_city_id") and not state.cities.has(str(route.from_city_id)):
		errors.append("route access origin city not found %s" % str(route.from_city_id))
	if route.has("to_city_id") and not state.cities.has(str(route.to_city_id)):
		errors.append("route access target city not found %s" % str(route.to_city_id))
	if route.has("control_force_id") and not state.forces.has(str(route.control_force_id)):
		errors.append("route access control force not found %s" % str(route.control_force_id))
	if route.has("blocks_enemy_passage") and typeof(route.blocks_enemy_passage) != TYPE_BOOL:
		errors.append("route access blocks_enemy_passage must be a bool %s" % route_id)
	return errors
