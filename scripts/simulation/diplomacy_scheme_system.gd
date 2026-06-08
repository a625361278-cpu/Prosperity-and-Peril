extends RefCounted

const EffectSystem = preload("res://scripts/simulation/effect_system.gd")

const DIPLOMACY_STATES := ["neutral", "hostile", "truce", "alliance", "vassal"]
const DIPLOMACY_REQUIRED_FIELDS := [
	"id",
	"action_type",
	"source_force_id",
	"target_force_id",
	"cost_gold",
	"new_state",
	"duration_days",
]
const SCHEME_REQUIRED_FIELDS := [
	"id",
	"scheme_type",
	"source_force_id",
	"target_force_id",
	"actor_officer_id",
	"target_scope",
	"target_id",
	"cost_gold",
	"effects",
]


static func relation_key(force_a_id: String, force_b_id: String) -> String:
	var ids := [force_a_id, force_b_id]
	ids.sort()
	return "%s|%s" % [ids[0], ids[1]]


static func execute_diplomacy_action(state: Dictionary, action: Dictionary) -> Dictionary:
	var errors := _validate_diplomacy_action(state, action)
	if not errors.is_empty():
		return {"ok": false, "errors": errors}

	var source_force: Dictionary = state.forces[action.source_force_id]
	var cost := int(action.cost_gold)
	source_force.gold -= cost

	var key := relation_key(str(action.source_force_id), str(action.target_force_id))
	state.diplomacy_states[key] = {
		"relation_key": key,
		"source_force_id": str(action.source_force_id),
		"target_force_id": str(action.target_force_id),
		"state": str(action.new_state),
		"action_type": str(action.action_type),
		"start_day": int(state.current_day),
		"end_day": _end_day_for_duration(state, int(action.duration_days)),
	}

	var log_id := "DIPLOG_%d" % int(state.next_diplomacy_log_seq)
	state.next_diplomacy_log_seq += 1
	state.diplomacy_logs[log_id] = {
		"id": log_id,
		"action_id": str(action.id),
		"relation_key": key,
		"source_force_id": str(action.source_force_id),
		"target_force_id": str(action.target_force_id),
		"new_state": str(action.new_state),
		"cost_gold": cost,
		"day": int(state.current_day),
	}

	return {"ok": true, "errors": [], "relation_key": key, "log_id": log_id}


static func execute_scheme_action(state: Dictionary, action: Dictionary) -> Dictionary:
	var errors := _validate_scheme_action(state, action)
	if not errors.is_empty():
		return {"ok": false, "errors": errors}

	var effect_result: Dictionary = EffectSystem.apply_effect_group(state, action.effects)
	if not effect_result.ok:
		return {"ok": false, "errors": effect_result.errors}

	var source_force: Dictionary = state.forces[action.source_force_id]
	var cost := int(action.cost_gold)
	source_force.gold -= cost

	var scheme_id := "SCHEME_%d" % int(state.next_scheme_seq)
	state.next_scheme_seq += 1
	state.scheme_states[scheme_id] = {
		"id": scheme_id,
		"action_id": str(action.id),
		"scheme_type": str(action.scheme_type),
		"source_force_id": str(action.source_force_id),
		"target_force_id": str(action.target_force_id),
		"actor_officer_id": str(action.actor_officer_id),
		"target_scope": str(action.target_scope),
		"target_id": str(action.target_id),
		"effects": action.effects.duplicate(true),
		"cost_gold": cost,
		"status": "resolved_success",
		"day": int(state.current_day),
	}

	return {"ok": true, "errors": [], "scheme_id": scheme_id}


static func _validate_diplomacy_action(state: Dictionary, action: Dictionary) -> Array[String]:
	var errors := _validate_runtime_keys(state, [
		"current_day",
		"forces",
		"diplomacy_states",
		"diplomacy_logs",
		"next_diplomacy_log_seq",
	])
	_validate_required_fields(action, DIPLOMACY_REQUIRED_FIELDS, "diplomacy_action", errors)
	if not errors.is_empty():
		return errors

	_validate_force_pair(state, str(action.source_force_id), str(action.target_force_id), errors)
	if not DIPLOMACY_STATES.has(str(action.new_state)):
		errors.append("unknown diplomacy state %s" % str(action.new_state))
	_validate_non_negative_int_field(action, "duration_days", "diplomacy_action", errors)
	_validate_non_negative_int_field(action, "cost_gold", "diplomacy_action", errors)
	if not errors.is_empty():
		return errors
	_validate_source_gold(state, str(action.source_force_id), int(action.cost_gold), errors)
	return errors


static func _validate_scheme_action(state: Dictionary, action: Dictionary) -> Array[String]:
	var errors := _validate_runtime_keys(state, [
		"current_day",
		"forces",
		"officers",
		"scheme_states",
		"next_scheme_seq",
	])
	_validate_required_fields(action, SCHEME_REQUIRED_FIELDS, "scheme_action", errors)
	if not errors.is_empty():
		return errors

	_validate_force_pair(state, str(action.source_force_id), str(action.target_force_id), errors)
	if state.has("officers") and state.officers.has(action.actor_officer_id):
		var actor: Dictionary = state.officers[action.actor_officer_id]
		if not actor.has("force_id"):
			errors.append("scheme actor missing force_id %s" % str(action.actor_officer_id))
		elif str(actor.force_id) != str(action.source_force_id):
			errors.append("scheme actor force does not match source force")
	else:
		errors.append("scheme actor officer not found %s" % str(action.actor_officer_id))
	if not action.effects is Array:
		errors.append("scheme_action.effects must be an array")
	_validate_non_negative_int_field(action, "cost_gold", "scheme_action", errors)
	if not errors.is_empty():
		return errors
	_validate_source_gold(state, str(action.source_force_id), int(action.cost_gold), errors)
	return errors


static func _validate_runtime_keys(state: Dictionary, keys: Array) -> Array[String]:
	var errors: Array[String] = []
	for key in keys:
		if not state.has(key):
			errors.append("runtime state missing %s" % str(key))
	return errors


static func _validate_required_fields(action: Dictionary, fields: Array, label: String, errors: Array[String]) -> void:
	for field in fields:
		if not action.has(field):
			errors.append("%s.%s missing required field" % [label, str(field)])


static func _validate_non_negative_int_field(action: Dictionary, field: String, label: String, errors: Array[String]) -> void:
	if not action.has(field):
		return
	if typeof(action[field]) != TYPE_INT:
		errors.append("%s.%s must be an integer" % [label, field])
		return
	if int(action[field]) < 0:
		errors.append("%s.%s must be >= 0" % [label, field])


static func _validate_force_pair(state: Dictionary, source_force_id: String, target_force_id: String, errors: Array[String]) -> void:
	if source_force_id == target_force_id:
		errors.append("source and target force must differ")
	if not state.has("forces"):
		return
	if not state.forces.has(source_force_id):
		errors.append("source force not found %s" % source_force_id)
	if not state.forces.has(target_force_id):
		errors.append("target force not found %s" % target_force_id)


static func _validate_source_gold(state: Dictionary, source_force_id: String, cost_gold: int, errors: Array[String]) -> void:
	if cost_gold < 0:
		errors.append("cost_gold must be >= 0")
		return
	if not state.has("forces") or not state.forces.has(source_force_id):
		return
	var force: Dictionary = state.forces[source_force_id]
	if not force.has("gold"):
		errors.append("source force missing gold %s" % source_force_id)
	elif int(force.gold) < cost_gold:
		errors.append("source force gold is insufficient")


static func _end_day_for_duration(state: Dictionary, duration_days: int) -> int:
	if duration_days == 0:
		return -1
	return int(state.current_day) + duration_days
