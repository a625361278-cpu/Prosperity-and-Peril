extends RefCounted

const REQUIRED_RULE_FIELDS := [
	"id",
	"city_id",
	"gentry_support_below",
	"public_order_delta",
	"morale_public_delta",
	"integration_progress_delta",
	"reason",
]


static func apply_gentry_pressure_rule(state: Dictionary, rule: Dictionary) -> Dictionary:
	var errors := _validate_rule(state, rule)
	if not errors.is_empty():
		return {"ok": false, "errors": errors, "triggered": false}

	var city: Dictionary = state.cities[str(rule.city_id)]
	if int(city.gentry_support) >= int(rule.gentry_support_below):
		return {"ok": true, "errors": [], "triggered": false}

	var before := {
		"public_order": int(city.public_order),
		"morale_public": int(city.morale_public),
		"integration_progress": int(city.get("integration_progress", 0)),
	}
	city.public_order = clampi(before.public_order + int(rule.public_order_delta), 0, 100)
	city.morale_public = clampi(before.morale_public + int(rule.morale_public_delta), 0, 100)
	if city.has("integration_progress"):
		city.integration_progress = clampi(before.integration_progress + int(rule.integration_progress_delta), 0, 100)

	var log_id := "LGOVLOG_%d" % int(state.next_local_governance_log_seq)
	state.next_local_governance_log_seq += 1
	state.local_governance_logs[log_id] = {
		"id": log_id,
		"rule_id": str(rule.id),
		"city_id": str(rule.city_id),
		"gentry_support": int(city.gentry_support),
		"public_order_before": before.public_order,
		"public_order_after": int(city.public_order),
		"morale_public_before": before.morale_public,
		"morale_public_after": int(city.morale_public),
		"integration_progress_before": before.integration_progress,
		"integration_progress_after": int(city.get("integration_progress", before.integration_progress)),
		"reason": str(rule.reason),
		"day": int(state.current_day),
	}

	return {"ok": true, "errors": [], "triggered": true, "log_id": log_id}


static func _validate_rule(state: Dictionary, rule: Dictionary) -> Array[String]:
	var errors := _validate_runtime_state(state)
	for field in REQUIRED_RULE_FIELDS:
		if not rule.has(field):
			errors.append("gentry_pressure_rule.%s missing required field" % field)
	if not errors.is_empty():
		return errors

	if not state.cities.has(str(rule.city_id)):
		errors.append("gentry pressure city not found %s" % str(rule.city_id))
	else:
		var city: Dictionary = state.cities[str(rule.city_id)]
		for field in ["gentry_support", "public_order", "morale_public"]:
			if not city.has(field):
				errors.append("city missing %s %s" % [field, str(rule.city_id)])
			elif not _is_integer_number(city[field]):
				errors.append("city.%s must be an integer %s" % [field, str(rule.city_id)])
		if city.has("integration_progress") and not _is_integer_number(city.integration_progress):
			errors.append("city.integration_progress must be an integer %s" % str(rule.city_id))
	for field in ["gentry_support_below", "public_order_delta", "morale_public_delta", "integration_progress_delta"]:
		_validate_int_field(rule, field, "gentry_pressure_rule", errors)
	if rule.has("gentry_support_below"):
		if _is_integer_number(rule.gentry_support_below) and (int(rule.gentry_support_below) < 0 or int(rule.gentry_support_below) > 100):
			errors.append("gentry_pressure_rule.gentry_support_below must be between 0 and 100")
	if str(rule.reason).is_empty():
		errors.append("gentry_pressure_rule.reason must not be empty")
	return errors


static func _validate_runtime_state(state: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key in ["current_day", "cities", "local_governance_logs", "next_local_governance_log_seq"]:
		if not state.has(key):
			errors.append("runtime state missing %s" % key)
	return errors


static func _validate_int_field(data: Dictionary, field: String, label: String, errors: Array[String]) -> void:
	if not data.has(field):
		return
	if not _is_integer_number(data[field]):
		errors.append("%s.%s must be an integer" % [label, field])


static func _is_integer_number(value) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	if typeof(value) == TYPE_FLOAT:
		return is_equal_approx(float(value), float(int(value)))
	return false
