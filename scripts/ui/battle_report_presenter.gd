extends RefCounted

const REQUIRED_STATE_KEYS := ["battle_logs", "armies", "cities"]


static func build_report_index(state: Dictionary) -> Dictionary:
	var errors := _validate_state(state)
	if not errors.is_empty():
		return _failure(errors)
	var rows: Array[Dictionary] = []
	for battle_id in _sorted_keys(state.battle_logs):
		var report_result := build_report_detail(state, str(battle_id))
		if not report_result.ok:
			return _failure(report_result.errors)
		rows.append({
			"id": str(battle_id),
			"label": str(report_result.report.title),
		})
	return {
		"ok": true,
		"errors": [],
		"reports": rows,
	}


static func build_report_detail(state: Dictionary, battle_id: String) -> Dictionary:
	var errors := _validate_state(state)
	if battle_id.is_empty():
		errors.append("battle report requires battle_id")
	if not errors.is_empty():
		return _failure(errors)
	if not state.battle_logs.has(battle_id):
		return _failure(["battle report missing log %s" % battle_id])
	var log: Dictionary = state.battle_logs[battle_id]
	var reference_errors := _validate_log_references(state, battle_id, log)
	if not reference_errors.is_empty():
		return _failure(reference_errors)
	var army: Dictionary = state.armies[str(log.army_id)]
	var city: Dictionary = state.cities[str(log.target_city_id)]
	var winner_text := "进攻方胜利" if str(log.winner) == "attacker" else "防守方胜利"
	return {
		"ok": true,
		"errors": [],
		"report": {
			"id": battle_id,
			"title": "%s %s %s" % [battle_id, str(city.name), winner_text],
			"summary": "目标=%s  胜者=%s  城市归属=%s  部队状态=%s" % [
				str(city.name),
				winner_text,
				str(city.force_id),
				str(army.state),
			],
			"casualties": "进攻损失=%s  防守损失=%s  部队剩余=%s  城市守军=%s" % [
				str(log.attacker_loss),
				str(log.defender_loss),
				str(army.troop_count),
				str(city.troops),
			],
			"ownership": "目标城市=%s  当前势力=%s  前势力=%s  状态=%s  整合=%s" % [
				str(city.name),
				str(city.force_id),
				str(city.get("previous_force_id", "")),
				str(city.recovery_state),
				str(city.get("integration_progress", -1)),
			],
			"jump_city_id": str(log.target_city_id),
		},
	}


static func _validate_state(state: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key in REQUIRED_STATE_KEYS:
		if not state.has(key):
			errors.append("battle report missing state key %s" % key)
	return errors


static func _validate_log_references(state: Dictionary, battle_id: String, log: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key in ["army_id", "target_city_id", "winner", "attacker_loss", "defender_loss"]:
		if not log.has(key):
			errors.append("battle report log %s missing field %s" % [battle_id, key])
	if not errors.is_empty():
		return errors
	var army_id := str(log.army_id)
	var target_city_id := str(log.target_city_id)
	if not state.armies.has(army_id):
		errors.append("battle report army missing %s" % army_id)
	if not state.cities.has(target_city_id):
		errors.append("battle report target city missing %s" % target_city_id)
	if str(log.winner) != "attacker" and str(log.winner) != "defender":
		errors.append("battle report winner invalid %s" % str(log.winner))
	return errors


static func _sorted_keys(values: Dictionary) -> Array:
	var keys := values.keys()
	keys.sort()
	return keys


static func _failure(errors: Array) -> Dictionary:
	return {
		"ok": false,
		"errors": errors,
		"reports": [],
		"report": {},
	}
