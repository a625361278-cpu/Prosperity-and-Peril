extends RefCounted

const REQUIRED_STATE_KEYS := ["cities", "forces", "officers"]


static func build_detail(state: Dictionary, city_id: String) -> Dictionary:
	var errors := _validate_state(state)
	if city_id.is_empty():
		errors.append("city detail requires city_id")
	if not errors.is_empty():
		return _failure(errors)
	if not state.cities.has(city_id):
		return _failure(["city detail missing city %s" % city_id])
	var city: Dictionary = state.cities[city_id]
	var force_id := str(city.force_id)
	if not state.forces.has(force_id):
		return _failure(["city detail missing force %s for city %s" % [force_id, city_id]])
	var force: Dictionary = state.forces[force_id]
	var governor := _governor_summary(state, city)
	if not governor.ok:
		return _failure(governor.errors)

	return {
		"ok": true,
		"errors": [],
		"detail": {
			"city_id": city_id,
			"title": "%s / %s" % [str(city.name), str(force.name)],
			"resource_rows": [
				_stat("兵力", city, "troops"),
				_stat("粮草", city, "food"),
				_stat("民心", city, "morale_public"),
				_stat("治安", city, "public_order"),
			],
			"governance_rows": [
				_stat("士族", city, "gentry_support"),
				{"label": "状态", "value": str(city.recovery_state)},
				{"label": "整合", "value": str(city.get("integration_progress", -1))},
			],
			"governor_text": governor.text,
			"officer_rows": _same_force_officers(state.officers, force_id),
			"actions": [
				{"id": "appointment", "label": "任命", "enabled": true, "blocked_reason": "打开正式任命与出阵面板"},
				{"id": "sortie", "label": "出阵", "enabled": true, "blocked_reason": "打开正式任命与出阵面板"},
			],
		},
	}


static func _validate_state(state: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key in REQUIRED_STATE_KEYS:
		if not state.has(key):
			errors.append("city detail missing state key %s" % key)
	return errors


static func _stat(label: String, values: Dictionary, key: String) -> Dictionary:
	if not values.has(key):
		return {"label": label, "value": "缺字段:%s" % key}
	return {"label": label, "value": str(values[key])}


static func _governor_summary(state: Dictionary, city: Dictionary) -> Dictionary:
	if not city.has("governor_officer_id") or str(city.governor_officer_id).is_empty():
		return {"ok": true, "errors": [], "text": "太守: 未任命"}
	var officer_id := str(city.governor_officer_id)
	if not state.officers.has(officer_id):
		return {"ok": false, "errors": ["city detail governor officer missing %s" % officer_id], "text": ""}
	var officer: Dictionary = state.officers[officer_id]
	return {"ok": true, "errors": [], "text": "太守: %s 忠诚=%s" % [str(officer.name), str(officer.loyalty)]}


static func _same_force_officers(officers: Dictionary, force_id: String) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for officer_id in _sorted_keys(officers):
		var officer: Dictionary = officers[officer_id]
		if str(officer.force_id) != force_id:
			continue
		rows.append({
			"id": str(officer_id),
			"name": str(officer.name),
			"loyalty": str(officer.loyalty),
			"assignment": str(officer.get("assignment_type", "未任命")),
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
		"detail": {},
	}
