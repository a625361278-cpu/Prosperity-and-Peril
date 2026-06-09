extends RefCounted

const REQUIRED_STATE_KEYS := [
	"current_day",
	"current_month",
	"forces",
	"cities",
	"officers",
	"armies",
	"routes",
	"battle_logs",
]


static func build_snapshot(state: Dictionary) -> Dictionary:
	var errors := _validate_state(state)
	if not errors.is_empty():
		return {
			"ok": false,
			"errors": errors,
			"snapshot": {},
		}

	return {
		"ok": true,
		"errors": [],
		"snapshot": {
			"current_day": state.current_day,
			"current_month": state.current_month,
			"forces": _force_rows(state.forces),
			"cities": _city_rows(state.cities),
			"officers": _officer_rows(state.officers),
			"armies": _army_rows(state.armies),
			"routes": _route_rows(state.routes),
			"battle_logs": _battle_log_rows(state.battle_logs),
		},
	}


static func build_selection_detail(state: Dictionary, selection: Dictionary) -> Dictionary:
	var errors := _validate_state(state)
	errors.append_array(_validate_selection_payload(selection))
	if not errors.is_empty():
		return {
			"ok": false,
			"errors": errors,
			"detail": {},
		}

	var selection_type := str(selection.type)
	var selection_id := str(selection.id)
	if selection_type == "city":
		return _city_selection_detail(state, selection_id)
	if selection_type == "army":
		return _army_selection_detail(state, selection_id)

	return {
		"ok": false,
		"errors": ["selection type unsupported %s" % selection_type],
		"detail": {},
	}


static func _validate_state(state: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key in REQUIRED_STATE_KEYS:
		if not state.has(key):
			errors.append("debug snapshot missing state key %s" % key)
	return errors


static func _validate_selection_payload(selection: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key in ["type", "id"]:
		if not selection.has(key):
			errors.append("selection payload missing %s" % key)
	return errors


static func _force_rows(forces: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for force_id in _sorted_keys(forces):
		var force: Dictionary = forces[force_id]
		rows.append({
			"id": force_id,
			"name": force.name,
			"legitimacy": force.legitimacy,
			"prestige": force.prestige,
		})
	return rows


static func _city_rows(cities: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for city_id in _sorted_keys(cities):
		var city: Dictionary = cities[city_id]
		rows.append({
			"id": city_id,
			"name": city.name,
			"force_id": city.force_id,
			"troops": city.troops,
			"food": city.food,
			"public_order": city.public_order,
			"morale_public": city.morale_public,
			"gentry_support": city.gentry_support,
			"recovery_state": city.recovery_state,
			"integration_progress": city.get("integration_progress", -1),
		})
	return rows


static func _army_rows(armies: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for army_id in _sorted_keys(armies):
		var army: Dictionary = armies[army_id]
		rows.append({
			"id": army_id,
			"origin_city_id": army.origin_city_id,
			"commander_officer_id": army.commander_officer_id,
			"route_id": army.route_id,
			"troop_count": army.troop_count,
			"food_current": army.food_current,
			"route_progress_days": army.route_progress_days,
			"state": army.state,
			"last_battle_result": army.get("last_battle_result", ""),
		})
	return rows


static func _officer_rows(officers: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for officer_id in _sorted_keys(officers):
		var officer: Dictionary = officers[officer_id]
		rows.append({
			"id": officer_id,
			"name": officer.name,
			"force_id": officer.force_id,
			"loyalty": officer.loyalty,
		})
	return rows


static func _route_rows(routes: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for route_id in _sorted_keys(routes):
		var route: Dictionary = routes[route_id]
		rows.append({
			"id": route_id,
			"from_city_id": route.from_city_id,
			"to_city_id": route.to_city_id,
			"route_type": route.route_type,
			"distance": route.distance,
			"battle_trigger": route.battle_trigger,
		})
	return rows


static func _battle_log_rows(battle_logs: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for battle_id in _sorted_keys(battle_logs):
		rows.append(battle_logs[battle_id].duplicate(true))
	return rows


static func _city_selection_detail(state: Dictionary, city_id: String) -> Dictionary:
	if not state.cities.has(city_id):
		return {
			"ok": false,
			"errors": ["selection city missing %s" % city_id],
			"detail": {},
		}
	var city: Dictionary = state.cities[city_id]
	return {
		"ok": true,
		"errors": [],
		"detail": {
			"title": "城市: %s" % str(city.name),
			"body": "ID=%s\n势力=%s\n兵=%s 粮=%s\n民心=%s 治安=%s 士族=%s\n状态=%s 整合=%s" % [
				city_id,
				str(city.force_id),
				city.troops,
				city.food,
				city.morale_public,
				city.public_order,
				city.gentry_support,
				city.recovery_state,
				city.get("integration_progress", -1),
			],
		},
	}


static func _army_selection_detail(state: Dictionary, army_id: String) -> Dictionary:
	if not state.armies.has(army_id):
		return {
			"ok": false,
			"errors": ["selection army missing %s" % army_id],
			"detail": {},
		}
	var army: Dictionary = state.armies[army_id]
	return {
		"ok": true,
		"errors": [],
		"detail": {
			"title": "部队: %s" % army_id,
			"body": "状态=%s\n出阵=%s 路线=%s\n主将=%s\n兵=%s 粮=%s\n进度=%s 战果=%s" % [
				army.state,
				army.origin_city_id,
				army.route_id,
				army.commander_officer_id,
				army.troop_count,
				army.food_current,
				army.route_progress_days,
				army.get("last_battle_result", ""),
			],
		},
	}


static func _sorted_keys(values: Dictionary) -> Array:
	var keys := values.keys()
	keys.sort()
	return keys
