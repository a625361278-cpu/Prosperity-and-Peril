extends RefCounted

const REQUIRED_STATE_KEYS := ["cities", "forces", "officers"]
const REQUIRED_CITY_KEYS := ["name", "force_id", "troops", "food", "public_order", "morale_public", "gentry_support", "recovery_state"]
const REQUIRED_FORCE_KEYS := ["name", "legitimacy", "prestige"]


static func build_detail(state: Dictionary, city_id: String) -> Dictionary:
	var errors := _validate_state(state)
	if city_id.is_empty():
		errors.append("city detail requires city_id")
	if not errors.is_empty():
		return _failure(errors)
	if not state.cities.has(city_id):
		return _failure(["city detail missing city %s" % city_id])
	var city: Dictionary = state.cities[city_id]
	errors.append_array(_require_fields(city, "city %s" % city_id, REQUIRED_CITY_KEYS))
	if not errors.is_empty():
		return _failure(errors)
	var force_id := str(city.force_id)
	if not state.forces.has(force_id):
		return _failure(["city detail missing force %s for city %s" % [force_id, city_id]])
	var force: Dictionary = state.forces[force_id]
	errors.append_array(_require_fields(force, "force %s" % force_id, REQUIRED_FORCE_KEYS))
	if not errors.is_empty():
		return _failure(errors)
	var governor := _governor_summary(state, city)
	if not governor.ok:
		return _failure(governor.errors)

	return {
		"ok": true,
		"errors": [],
		"detail": {
			"city_id": city_id,
			"title": "%s / %s" % [str(city.name), str(force.name)],
			"force_summary_text": "势力 %s  正统 %s  名望 %s" % [
				str(force.name),
				str(force.legitimacy),
				str(force.prestige),
			],
			"section_order": ["resource", "governance", "officer", "actions", "data_gaps"],
			"resource_section_title": "兵粮与民生",
			"governance_section_title": "治理状态",
			"officer_section_title": "太守与属官",
			"action_section_title": "城市动作",
			"resource_rows": [
				{"label": "兵力", "value": "%s" % str(city.troops)},
				{"label": "粮草", "value": "%s" % str(city.food)},
				{"label": "民心", "value": "%s / 100" % str(city.morale_public)},
				{"label": "治安", "value": "%s / 100" % str(city.public_order)},
			],
			"governance_rows": [
				{"label": "士族", "value": "%s / 100" % str(city.gentry_support)},
				{"label": "状态", "value": str(city.recovery_state)},
				{"label": "整合", "value": _integration_value(city)},
			],
			"governor_text": governor.text,
			"officer_rows": _same_force_officers(state.officers, force_id),
			"data_gap_rows": _data_gap_rows(city),
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


static func _require_fields(values: Dictionary, context: String, fields: Array) -> Array[String]:
	var errors: Array[String] = []
	for field in fields:
		if not values.has(field):
			errors.append("city detail %s missing %s" % [context, str(field)])
	return errors


static func _integration_value(city: Dictionary) -> String:
	if not city.has("integration_progress"):
		return "未进入战后整合"
	return "%s / 100" % str(city.integration_progress)


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


static func _data_gap_rows(city: Dictionary) -> Array[Dictionary]:
	var gaps: Array[Dictionary] = []
	_append_gap_if_missing(gaps, city, "troop_capacity", "兵力上限", "正式城市军事容量字段尚未进入运行时状态")
	_append_gap_if_missing(gaps, city, "food_capacity", "粮草上限", "正式城市仓储容量字段尚未进入运行时状态")
	_append_gap_if_missing(gaps, city, "resource_yield", "资源产量", "正式城市资源产量字段尚未进入运行时状态")
	_append_gap_if_missing(gaps, city, "buildings", "建筑列表", "正式城市建筑列表尚未进入运行时状态")
	return gaps


static func _append_gap_if_missing(gaps: Array[Dictionary], values: Dictionary, field: String, label: String, reason: String) -> void:
	if values.has(field):
		return
	gaps.append({
		"field": field,
		"label": label,
		"reason": reason,
	})


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
