extends RefCounted

const REQUIRED_LOYALTY_FIELDS := ["id", "officer_id", "loyalty_delta", "reason", "source_type"]
const REQUIRED_DEFECTOR_FIELDS := ["id", "officer_id", "old_force_id", "new_force_id", "trust_initial", "loyalty_delta", "reason"]


static func apply_loyalty_change(state: Dictionary, change: Dictionary) -> Dictionary:
	var errors := _validate_loyalty_change(state, change)
	if not errors.is_empty():
		return {"ok": false, "errors": errors}

	var officer: Dictionary = state.officers[str(change.officer_id)]
	var before := int(officer.loyalty)
	var after := clampi(before + int(change.loyalty_delta), 0, 100)
	officer.loyalty = after
	var log_id := _write_loyalty_log(state, {
		"change_id": str(change.id),
		"officer_id": str(change.officer_id),
		"loyalty_delta": int(change.loyalty_delta),
		"loyalty_before": before,
		"loyalty_after": after,
		"reason": str(change.reason),
		"source_type": str(change.source_type),
	})
	return {"ok": true, "errors": [], "log_id": log_id}


static func create_defector_state(state: Dictionary, action: Dictionary) -> Dictionary:
	var errors := _validate_defector_action(state, action)
	if not errors.is_empty():
		return {"ok": false, "errors": errors}

	var officer: Dictionary = state.officers[str(action.officer_id)]
	var before := int(officer.loyalty)
	officer.force_id = str(action.new_force_id)
	officer.loyalty = clampi(before + int(action.loyalty_delta), 0, 100)
	state.defector_states[str(action.officer_id)] = {
		"officer_id": str(action.officer_id),
		"old_force_id": str(action.old_force_id),
		"new_force_id": str(action.new_force_id),
		"state": "new_surrender",
		"trust": int(action.trust_initial),
		"reason": str(action.reason),
		"created_day": int(state.current_day),
	}
	var log_id := _write_loyalty_log(state, {
		"change_id": str(action.id),
		"officer_id": str(action.officer_id),
		"loyalty_delta": int(action.loyalty_delta),
		"loyalty_before": before,
		"loyalty_after": int(officer.loyalty),
		"reason": str(action.reason),
		"source_type": "defector",
	})
	return {"ok": true, "errors": [], "log_id": log_id}


static func loyalty_risk_for_officer(state: Dictionary, officer_id: String) -> Dictionary:
	var errors := _validate_runtime_state(state)
	if not errors.is_empty():
		return {"ok": false, "errors": errors}
	if not state.officers.has(officer_id):
		return {"ok": false, "errors": ["loyalty officer not found %s" % officer_id]}
	var officer: Dictionary = state.officers[officer_id]
	if not officer.has("loyalty") or not _is_integer_number(officer.loyalty):
		return {"ok": false, "errors": ["officer.loyalty must be an integer %s" % officer_id]}

	var reasons: Array[String] = []
	var risk_level := "stable"
	if int(officer.loyalty) < 50:
		risk_level = "high"
		reasons.append("low_loyalty")
	if state.defector_states.has(officer_id):
		var defector: Dictionary = state.defector_states[officer_id]
		reasons.append("defector_%s" % str(defector.state))
		if risk_level != "high":
			risk_level = "watch"
	return {"ok": true, "errors": [], "risk_level": risk_level, "reasons": reasons}


static func _validate_loyalty_change(state: Dictionary, change: Dictionary) -> Array[String]:
	var errors := _validate_runtime_state(state)
	for field in REQUIRED_LOYALTY_FIELDS:
		if not change.has(field):
			errors.append("loyalty_change.%s missing required field" % field)
	if not errors.is_empty():
		return errors
	_validate_officer_for_loyalty(state, str(change.officer_id), errors)
	_validate_int_field(change, "loyalty_delta", "loyalty_change", errors)
	if str(change.reason).is_empty():
		errors.append("loyalty_change.reason must not be empty")
	if str(change.source_type).is_empty():
		errors.append("loyalty_change.source_type must not be empty")
	return errors


static func _validate_defector_action(state: Dictionary, action: Dictionary) -> Array[String]:
	var errors := _validate_runtime_state(state)
	for field in REQUIRED_DEFECTOR_FIELDS:
		if not action.has(field):
			errors.append("defector_action.%s missing required field" % field)
	if not errors.is_empty():
		return errors
	_validate_officer_for_loyalty(state, str(action.officer_id), errors)
	if not state.forces.has(str(action.old_force_id)):
		errors.append("old force not found %s" % str(action.old_force_id))
	if not state.forces.has(str(action.new_force_id)):
		errors.append("new force not found %s" % str(action.new_force_id))
	if str(action.old_force_id) == str(action.new_force_id):
		errors.append("old and new force must differ")
	for field in ["trust_initial", "loyalty_delta"]:
		_validate_int_field(action, field, "defector_action", errors)
	if action.has("trust_initial") and _is_integer_number(action.trust_initial):
		if int(action.trust_initial) < 0 or int(action.trust_initial) > 100:
			errors.append("defector_action.trust_initial must be between 0 and 100")
	if str(action.reason).is_empty():
		errors.append("defector_action.reason must not be empty")
	return errors


static func _validate_runtime_state(state: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key in ["current_day", "forces", "officers", "loyalty_logs", "defector_states", "next_loyalty_log_seq"]:
		if not state.has(key):
			errors.append("runtime state missing %s" % key)
	return errors


static func _validate_officer_for_loyalty(state: Dictionary, officer_id: String, errors: Array[String]) -> void:
	if not state.officers.has(officer_id):
		errors.append("loyalty officer not found %s" % officer_id)
		return
	var officer: Dictionary = state.officers[officer_id]
	if not officer.has("loyalty"):
		errors.append("officer missing loyalty %s" % officer_id)
	elif not _is_integer_number(officer.loyalty):
		errors.append("officer.loyalty must be an integer %s" % officer_id)


static func _write_loyalty_log(state: Dictionary, log_data: Dictionary) -> String:
	var log_id := "LOYLOG_%d" % int(state.next_loyalty_log_seq)
	state.next_loyalty_log_seq += 1
	log_data.id = log_id
	log_data.day = int(state.current_day)
	state.loyalty_logs[log_id] = log_data
	return log_id


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
