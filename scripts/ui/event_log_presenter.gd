extends RefCounted

const REQUIRED_STATE_KEYS := [
	"battle_logs",
	"legitimacy_logs",
	"local_governance_logs",
	"loyalty_logs",
	"diplomacy_logs",
	"scheme_states",
]


static func build_event_index(state: Dictionary, category_filter := "all") -> Dictionary:
	var errors := _validate_state(state)
	if not errors.is_empty():
		return _failure(errors)
	var rows: Array[Dictionary] = []
	var collected := [
		_collect_battle_logs(state),
		_collect_legitimacy_logs(state),
		_collect_local_governance_logs(state),
		_collect_loyalty_logs(state),
		_collect_diplomacy_logs(state),
		_collect_scheme_states(state),
	]
	for result in collected:
		if not result.ok:
			return _failure(result.errors)
		for row in result.rows:
			if category_filter == "all" or str(row.category) == category_filter:
				rows.append(row)
	rows.sort_custom(_sort_rows)
	return {"ok": true, "errors": [], "events": rows}


static func _collect_battle_logs(state: Dictionary) -> Dictionary:
	var rows: Array[Dictionary] = []
	for log_id in _sorted_keys(state.battle_logs):
		var log: Dictionary = state.battle_logs[log_id]
		var errors := _require_fields(log, str(log_id), "battle", ["army_id", "target_city_id", "winner", "attacker_loss", "defender_loss"])
		if not errors.is_empty():
			return _failure(errors)
		rows.append(_row(
			str(log_id),
			"military",
			int(log.get("day", 0)),
			"战斗 %s %s" % [str(log.target_city_id), str(log.winner)],
			"部队=%s 目标=%s 进攻损失=%s 防守损失=%s" % [
				str(log.army_id),
				str(log.target_city_id),
				str(log.attacker_loss),
				str(log.defender_loss),
			]
		))
	return {"ok": true, "errors": [], "rows": rows}


static func _collect_legitimacy_logs(state: Dictionary) -> Dictionary:
	var rows: Array[Dictionary] = []
	for log_id in _sorted_keys(state.legitimacy_logs):
		var log: Dictionary = state.legitimacy_logs[log_id]
		var errors := _require_fields(log, str(log_id), "legitimacy", ["force_id", "legitimacy_delta", "prestige_delta", "reason", "day"])
		if not errors.is_empty():
			return _failure(errors)
		rows.append(_row(
			str(log_id),
			"domestic",
			int(log.day),
			"正统名望 %s" % str(log.force_id),
			"正统%s 名望%s 原因=%s" % [str(log.legitimacy_delta), str(log.prestige_delta), str(log.reason)]
		))
	return {"ok": true, "errors": [], "rows": rows}


static func _collect_local_governance_logs(state: Dictionary) -> Dictionary:
	var rows: Array[Dictionary] = []
	for log_id in _sorted_keys(state.local_governance_logs):
		var log: Dictionary = state.local_governance_logs[log_id]
		var errors := _require_fields(log, str(log_id), "local_governance", ["city_id", "public_order_before", "public_order_after", "morale_public_before", "morale_public_after", "reason", "day"])
		if not errors.is_empty():
			return _failure(errors)
		rows.append(_row(
			str(log_id),
			"domestic",
			int(log.day),
			"地方治理 %s" % str(log.city_id),
			"治安 %s->%s 民心 %s->%s 原因=%s" % [
				str(log.public_order_before),
				str(log.public_order_after),
				str(log.morale_public_before),
				str(log.morale_public_after),
				str(log.reason),
			]
		))
	return {"ok": true, "errors": [], "rows": rows}


static func _collect_loyalty_logs(state: Dictionary) -> Dictionary:
	var rows: Array[Dictionary] = []
	for log_id in _sorted_keys(state.loyalty_logs):
		var log: Dictionary = state.loyalty_logs[log_id]
		var errors := _require_fields(log, str(log_id), "loyalty", ["officer_id", "loyalty_before", "loyalty_after", "reason", "source_type", "day"])
		if not errors.is_empty():
			return _failure(errors)
		rows.append(_row(
			str(log_id),
			"officer",
			int(log.day),
			"忠诚变化 %s" % str(log.officer_id),
			"忠诚 %s->%s 来源=%s 原因=%s" % [
				str(log.loyalty_before),
				str(log.loyalty_after),
				str(log.source_type),
				str(log.reason),
			]
		))
	return {"ok": true, "errors": [], "rows": rows}


static func _collect_diplomacy_logs(state: Dictionary) -> Dictionary:
	var rows: Array[Dictionary] = []
	for log_id in _sorted_keys(state.diplomacy_logs):
		var log: Dictionary = state.diplomacy_logs[log_id]
		var errors := _require_fields(log, str(log_id), "diplomacy", ["source_force_id", "target_force_id", "new_state", "cost_gold", "day"])
		if not errors.is_empty():
			return _failure(errors)
		rows.append(_row(
			str(log_id),
			"diplomacy",
			int(log.day),
			"外交 %s -> %s" % [str(log.source_force_id), str(log.target_force_id)],
			"关系=%s 花费=%s" % [str(log.new_state), str(log.cost_gold)]
		))
	return {"ok": true, "errors": [], "rows": rows}


static func _collect_scheme_states(state: Dictionary) -> Dictionary:
	var rows: Array[Dictionary] = []
	for scheme_id in _sorted_keys(state.scheme_states):
		var scheme: Dictionary = state.scheme_states[scheme_id]
		var errors := _require_fields(scheme, str(scheme_id), "scheme", ["scheme_type", "source_force_id", "target_force_id", "target_scope", "target_id", "status", "day"])
		if not errors.is_empty():
			return _failure(errors)
		rows.append(_row(
			str(scheme_id),
			"diplomacy",
			int(scheme.day),
			"谋略 %s" % str(scheme.scheme_type),
			"%s -> %s 目标=%s:%s 状态=%s" % [
				str(scheme.source_force_id),
				str(scheme.target_force_id),
				str(scheme.target_scope),
				str(scheme.target_id),
				str(scheme.status),
			]
		))
	return {"ok": true, "errors": [], "rows": rows}


static func _row(id: String, category: String, day: int, title: String, detail: String) -> Dictionary:
	return {
		"id": id,
		"category": category,
		"day": day,
		"title": title,
		"detail": detail,
		"label": "第%s日 [%s] %s" % [str(day), category, title],
	}


static func _require_fields(log: Dictionary, id: String, label: String, fields: Array) -> Array[String]:
	var errors: Array[String] = []
	for field in fields:
		if not log.has(str(field)):
			errors.append("event log %s %s missing field %s" % [label, id, str(field)])
	return errors


static func _validate_state(state: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key in REQUIRED_STATE_KEYS:
		if not state.has(key):
			errors.append("event log missing state key %s" % key)
	return errors


static func _sort_rows(left: Dictionary, right: Dictionary) -> bool:
	var left_day := int(left.day)
	var right_day := int(right.day)
	if left_day == right_day:
		return str(left.id) < str(right.id)
	return left_day < right_day


static func _sorted_keys(values: Dictionary) -> Array:
	var keys := values.keys()
	keys.sort()
	return keys


static func _failure(errors: Array) -> Dictionary:
	return {"ok": false, "errors": errors, "events": [], "rows": []}
