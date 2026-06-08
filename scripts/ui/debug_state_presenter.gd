extends RefCounted

const REQUIRED_STATE_KEYS := [
	"current_day",
	"current_month",
	"forces",
	"cities",
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
			"armies": _army_rows(state.armies),
			"routes": _route_rows(state.routes),
			"battle_logs": _battle_log_rows(state.battle_logs),
		},
	}


static func _validate_state(state: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key in REQUIRED_STATE_KEYS:
		if not state.has(key):
			errors.append("debug snapshot missing state key %s" % key)
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


static func _sorted_keys(values: Dictionary) -> Array:
	var keys := values.keys()
	keys.sort()
	return keys
