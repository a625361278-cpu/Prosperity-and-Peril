extends RefCounted

const REQUIRED_CHANGE_FIELDS := [
	"id",
	"force_id",
	"legitimacy_delta",
	"prestige_delta",
	"reason",
	"source_type",
]


static func apply_force_reputation_change(state: Dictionary, change: Dictionary) -> Dictionary:
	var errors := _validate_change(state, change)
	if not errors.is_empty():
		return {"ok": false, "errors": errors}

	var force: Dictionary = state.forces[change.force_id]
	var legitimacy_before := int(force.legitimacy)
	var prestige_before := int(force.prestige)
	var legitimacy_after := clampi(legitimacy_before + int(change.legitimacy_delta), 0, 100)
	var prestige_after := clampi(prestige_before + int(change.prestige_delta), 0, 100)

	force.legitimacy = legitimacy_after
	force.prestige = prestige_after

	var log_id := "LEGLOG_%d" % int(state.next_legitimacy_log_seq)
	state.next_legitimacy_log_seq += 1
	state.legitimacy_logs[log_id] = {
		"id": log_id,
		"change_id": str(change.id),
		"force_id": str(change.force_id),
		"legitimacy_delta": int(change.legitimacy_delta),
		"prestige_delta": int(change.prestige_delta),
		"legitimacy_before": legitimacy_before,
		"legitimacy_after": legitimacy_after,
		"prestige_before": prestige_before,
		"prestige_after": prestige_after,
		"reason": str(change.reason),
		"source_type": str(change.source_type),
		"day": int(state.current_day),
	}

	return {"ok": true, "errors": [], "log_id": log_id}


static func _validate_change(state: Dictionary, change: Dictionary) -> Array[String]:
	var errors := _validate_runtime_state(state)
	for field in REQUIRED_CHANGE_FIELDS:
		if not change.has(field):
			errors.append("legitimacy_change.%s missing required field" % field)
	if not errors.is_empty():
		return errors

	if not state.forces.has(str(change.force_id)):
		errors.append("legitimacy force not found %s" % str(change.force_id))
	else:
		var force: Dictionary = state.forces[str(change.force_id)]
		for field in ["legitimacy", "prestige"]:
			if not force.has(field):
				errors.append("force missing %s %s" % [field, str(change.force_id)])
			elif not _is_integer_number(force[field]):
				errors.append("force.%s must be an integer %s" % [field, str(change.force_id)])
	_validate_int_field(change, "legitimacy_delta", "legitimacy_change", errors)
	_validate_int_field(change, "prestige_delta", "legitimacy_change", errors)
	if str(change.reason).is_empty():
		errors.append("legitimacy_change.reason must not be empty")
	if str(change.source_type).is_empty():
		errors.append("legitimacy_change.source_type must not be empty")
	return errors


static func _validate_runtime_state(state: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key in ["current_day", "forces", "legitimacy_logs", "next_legitimacy_log_seq"]:
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
