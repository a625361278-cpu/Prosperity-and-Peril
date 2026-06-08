extends RefCounted

const DiplomacySchemeSystem = preload("res://scripts/simulation/diplomacy_scheme_system.gd")
const RouteAccessSystem = preload("res://scripts/simulation/route_access_system.gd")

const REQUIRED_OPTION_FIELDS := ["troop_count", "speed_base", "food_cost_per_day"]
const BLOCKING_DIPLOMACY_STATES := ["truce", "alliance", "vassal"]


static func select_attack_target(state: Dictionary, force_id: String, options: Dictionary) -> Dictionary:
	var errors := _validate_request(state, force_id, options)
	if not errors.is_empty():
		return {"ok": false, "errors": errors}

	var candidate_result := _collect_candidates(state, force_id, options)
	if not candidate_result.ok:
		return {"ok": false, "errors": candidate_result.errors, "candidates": []}
	var candidates: Array[Dictionary] = candidate_result.candidates
	if candidates.is_empty():
		return {"ok": false, "errors": ["no valid attack target"], "candidates": []}

	candidates.sort_custom(_sort_candidate)
	var selected: Dictionary = candidates[0]
	return {
		"ok": true,
		"errors": [],
		"origin_city_id": selected.origin_city_id,
		"target_city_id": selected.target_city_id,
		"target_force_id": selected.target_force_id,
		"route_id": selected.route_id,
		"days_required": selected.days_required,
		"required_food": selected.required_food,
		"candidates": candidates,
	}


static func _validate_request(state: Dictionary, force_id: String, options: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key in ["forces", "cities", "routes", "diplomacy_states"]:
		if not state.has(key):
			errors.append("runtime state missing %s" % key)
	for field in REQUIRED_OPTION_FIELDS:
		if not options.has(field):
			errors.append("ai_target_options.%s missing required field" % field)
	if not errors.is_empty():
		return errors

	if not state.forces.has(force_id):
		errors.append("ai force not found %s" % force_id)
	_validate_positive_int_field(options, "troop_count", "ai_target_options", errors)
	_validate_positive_number_field(options, "speed_base", "ai_target_options", errors)
	_validate_positive_int_field(options, "food_cost_per_day", "ai_target_options", errors)
	if options.has("origin_city_id") and not state.cities.has(str(options.origin_city_id)):
		errors.append("origin city not found %s" % str(options.origin_city_id))
	return errors


static func _collect_candidates(state: Dictionary, force_id: String, options: Dictionary) -> Dictionary:
	var candidates: Array[Dictionary] = []
	var errors: Array[String] = []
	var troop_count := int(options.troop_count)
	var speed_base := float(options.speed_base)
	var food_cost_per_day := int(options.food_cost_per_day)
	for route_id in state.routes.keys():
		var route: Dictionary = state.routes[route_id]
		var candidate := _candidate_from_route(state, force_id, options, route, troop_count, speed_base, food_cost_per_day)
		if candidate.has("errors"):
			errors.append_array(candidate.errors)
		if candidate.ok:
			candidates.append(candidate.candidate)
	if not errors.is_empty():
		return {"ok": false, "errors": errors, "candidates": []}
	return {"ok": true, "errors": [], "candidates": candidates}


static func _candidate_from_route(
	state: Dictionary,
	force_id: String,
	options: Dictionary,
	route: Dictionary,
	troop_count: int,
	speed_base: float,
	food_cost_per_day: int
) -> Dictionary:
	var errors := _validate_route_shape(state, route)
	if not errors.is_empty():
		return {"ok": false, "errors": errors}
	if options.has("origin_city_id") and str(route.from_city_id) != str(options.origin_city_id):
		return {"ok": false}

	var origin_city: Dictionary = state.cities[route.from_city_id]
	var target_city: Dictionary = state.cities[route.to_city_id]
	if str(origin_city.force_id) != force_id:
		return {"ok": false}
	if str(target_city.force_id) == force_id:
		return {"ok": false}
	if int(origin_city.troops) < troop_count:
		return {"ok": false}
	if _is_diplomacy_blocked(state, force_id, str(target_city.force_id)):
		return {"ok": false}
	var route_access: Dictionary = RouteAccessSystem.evaluate_route_access(state, force_id, str(route.id))
	if not route_access.ok:
		return {"ok": false, "errors": route_access.errors}
	if not route_access.can_pass:
		return {"ok": false}

	var days_required := _days_required(route, speed_base)
	var required_food := _required_food(route, days_required, food_cost_per_day)
	if int(origin_city.food) < required_food:
		return {"ok": false}

	return {
		"ok": true,
		"candidate": {
			"origin_city_id": str(route.from_city_id),
			"target_city_id": str(route.to_city_id),
			"target_force_id": str(target_city.force_id),
			"route_id": str(route.id),
			"distance": float(route.distance),
			"days_required": days_required,
			"required_food": required_food,
			"origin_troops": int(origin_city.troops),
			"target_troops": int(target_city.troops),
		},
	}


static func _validate_route_shape(state: Dictionary, route: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for field in ["id", "from_city_id", "to_city_id", "distance", "terrain_modifier", "supply_modifier"]:
		if not route.has(field):
			errors.append("route missing required field %s" % field)
	if not errors.is_empty():
		return errors
	if not [TYPE_INT, TYPE_FLOAT].has(typeof(route.distance)):
		errors.append("route.distance must be a number %s" % str(route.id))
	if not [TYPE_INT, TYPE_FLOAT].has(typeof(route.terrain_modifier)):
		errors.append("route.terrain_modifier must be a number %s" % str(route.id))
	elif float(route.terrain_modifier) <= 0.0:
		errors.append("route.terrain_modifier must be positive %s" % str(route.id))
	if not [TYPE_INT, TYPE_FLOAT].has(typeof(route.supply_modifier)):
		errors.append("route.supply_modifier must be a number %s" % str(route.id))
	elif float(route.supply_modifier) <= 0.0:
		errors.append("route.supply_modifier must be positive %s" % str(route.id))
	if not state.cities.has(route.from_city_id):
		errors.append("route origin city not found %s" % str(route.from_city_id))
	if not state.cities.has(route.to_city_id):
		errors.append("route target city not found %s" % str(route.to_city_id))
	if not errors.is_empty():
		return errors

	var origin_city: Dictionary = state.cities[route.from_city_id]
	var target_city: Dictionary = state.cities[route.to_city_id]
	for field in ["force_id", "troops", "food"]:
		if not origin_city.has(field):
			errors.append("origin city missing %s %s" % [field, str(route.from_city_id)])
	if not target_city.has("force_id"):
		errors.append("target city missing force_id %s" % str(route.to_city_id))
	if not target_city.has("troops"):
		errors.append("target city missing troops %s" % str(route.to_city_id))
	if target_city.has("force_id") and not state.forces.has(str(target_city.force_id)):
		errors.append("target force not found %s" % str(target_city.force_id))
	return errors


static func _days_required(route: Dictionary, speed_base: float) -> int:
	return int(ceil(float(route.distance) / (speed_base * float(route.terrain_modifier))))


static func _required_food(route: Dictionary, days_required: int, food_cost_per_day: int) -> int:
	return int(ceil(float(days_required * food_cost_per_day) * float(route.supply_modifier)))


static func _is_diplomacy_blocked(state: Dictionary, force_id: String, target_force_id: String) -> bool:
	var key := DiplomacySchemeSystem.relation_key(force_id, target_force_id)
	if not state.diplomacy_states.has(key):
		return false
	var relation: Dictionary = state.diplomacy_states[key]
	return BLOCKING_DIPLOMACY_STATES.has(str(relation.state))


static func _sort_candidate(left: Dictionary, right: Dictionary) -> bool:
	if int(left.days_required) != int(right.days_required):
		return int(left.days_required) < int(right.days_required)
	if int(left.required_food) != int(right.required_food):
		return int(left.required_food) < int(right.required_food)
	return str(left.route_id) < str(right.route_id)


static func _validate_positive_int_field(data: Dictionary, field: String, label: String, errors: Array[String]) -> void:
	if typeof(data[field]) != TYPE_INT:
		errors.append("%s.%s must be an integer" % [label, field])
		return
	if int(data[field]) <= 0:
		errors.append("%s.%s must be positive" % [label, field])


static func _validate_positive_number_field(data: Dictionary, field: String, label: String, errors: Array[String]) -> void:
	if not [TYPE_INT, TYPE_FLOAT].has(typeof(data[field])):
		errors.append("%s.%s must be a number" % [label, field])
		return
	if float(data[field]) <= 0.0:
		errors.append("%s.%s must be positive" % [label, field])
