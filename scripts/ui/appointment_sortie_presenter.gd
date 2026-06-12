extends RefCounted

const AppointmentSystem = preload("res://scripts/simulation/appointment_system.gd")
const SortieSystem = preload("res://scripts/simulation/sortie_system.gd")
const MarchSystem = preload("res://scripts/simulation/march_system.gd")

const REQUIRED_STATE_KEYS := ["cities", "forces", "officers", "routes", "armies", "next_army_seq"]


static func build_form(state: Dictionary, city_id: String) -> Dictionary:
	var errors := _validate_state(state)
	if city_id.is_empty():
		errors.append("appointment sortie requires city_id")
	if not errors.is_empty():
		return _failure(errors)
	if not state.cities.has(city_id):
		return _failure(["appointment sortie city not found %s" % city_id])
	var city: Dictionary = state.cities[city_id]
	var force_id := str(city.force_id)
	if not state.forces.has(force_id):
		return _failure(["appointment sortie force not found %s" % force_id])
	var officer_rows := _same_force_officers(state.officers, force_id)
	if officer_rows.is_empty():
		return _failure(["appointment sortie no eligible officer for force %s" % force_id])
	var route_rows := _origin_routes(state.routes, city_id)
	if route_rows.is_empty():
		return _failure(["appointment sortie no route starts from city %s" % city_id])
	return {
		"ok": true,
		"errors": [],
		"form": {
			"city_id": city_id,
			"city_summary": "%s  势力=%s  兵=%s  粮=%s" % [
				str(city.name),
				force_id,
				str(city.troops),
				str(city.food),
			],
			"officers": officer_rows,
			"routes": route_rows,
			"max_troops": int(city.troops),
			"max_food": int(city.food),
			"default_troops": mini(1000, int(city.troops)),
			"default_food": mini(1000, int(city.food)),
		},
	}


static func appoint_governor(state: Dictionary, city_id: String, officer_id: String) -> Dictionary:
	var result: Dictionary = AppointmentSystem.appoint_governor(state, city_id, officer_id)
	if not result.ok:
		return _failure(result.errors)
	return {
		"ok": true,
		"errors": [],
		"message": "任命完成: %s -> %s" % [city_id, officer_id],
	}


static func create_sortie(state: Dictionary, city_id: String, officer_id: String, route_id: String, troops: int, food: int) -> Dictionary:
	var result: Dictionary = SortieSystem.create_sortie(state, city_id, officer_id, route_id, troops, food)
	if not result.ok:
		return _failure(result.errors)
	var march_result: Dictionary = MarchSystem.start_march(state, str(result.army_id), 12.0, 1000)
	if not march_result.ok:
		return _failure(march_result.errors)
	return {
		"ok": true,
		"errors": [],
		"message": "出阵完成并开始行军: %s" % str(result.army_id),
		"army_id": str(result.army_id),
	}


static func _validate_state(state: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key in REQUIRED_STATE_KEYS:
		if not state.has(key):
			errors.append("appointment sortie missing state key %s" % key)
	return errors


static func _same_force_officers(officers: Dictionary, force_id: String) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for officer_id in _sorted_keys(officers):
		var officer: Dictionary = officers[officer_id]
		if str(officer.force_id) != force_id:
			continue
		rows.append({
			"id": str(officer_id),
			"label": "%s %s 忠诚=%s" % [str(officer_id), str(officer.name), str(officer.loyalty)],
		})
	return rows


static func _origin_routes(routes: Dictionary, city_id: String) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for route_id in _sorted_keys(routes):
		var route: Dictionary = routes[route_id]
		if str(route.from_city_id) != city_id:
			continue
		rows.append({
			"id": str(route_id),
			"label": "%s -> %s 距离=%s 类型=%s" % [
				str(route_id),
				str(route.to_city_id),
				str(route.distance),
				str(route.route_type),
			],
		})
	return rows


static func _sorted_keys(values: Dictionary) -> Array:
	var keys := values.keys()
	keys.sort()
	return keys


static func _failure(errors: Array) -> Dictionary:
	return {
		"ok": false,
		"errors": errors,
		"form": {},
		"message": "",
		"army_id": "",
	}
