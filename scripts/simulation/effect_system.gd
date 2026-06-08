extends RefCounted

const SUPPORTED_OPERATIONS := ["add_flat", "add_pct", "mul", "set"]


static func apply_effect_group(state: Dictionary, effects: Array) -> Dictionary:
	var resolved_effects: Array[Dictionary] = []
	var errors: Array[String] = []

	for index in effects.size():
		var resolved := _resolve_effect(state, effects[index], index)
		if not resolved.ok:
			errors.append_array(resolved.errors)
		else:
			resolved_effects.append(resolved)

	if not errors.is_empty():
		return {
			"ok": false,
			"errors": errors,
		}

	for resolved in resolved_effects:
		_apply_resolved_effect(resolved)

	return {
		"ok": true,
		"errors": [],
	}


static func _resolve_effect(state: Dictionary, effect, index: int) -> Dictionary:
	var errors: Array[String] = []
	if not effect is Dictionary:
		return {"ok": false, "errors": ["effects[%d] must be a dictionary" % index]}

	for field in ["target_scope", "target_id", "stat_key", "operation", "value"]:
		if not effect.has(field):
			errors.append("effects[%d].%s missing required field" % [index, field])
	if not errors.is_empty():
		return {"ok": false, "errors": errors}

	var operation := str(effect.operation)
	if not SUPPORTED_OPERATIONS.has(operation):
		errors.append("unknown effect operation %s" % operation)

	var target = _target_for_effect(state, str(effect.target_scope), str(effect.target_id), errors)
	if target != null:
		var stat_key := str(effect.stat_key)
		if not target.has(stat_key):
			errors.append("effect target missing stat %s" % stat_key)

	if not errors.is_empty():
		return {"ok": false, "errors": errors}

	return {
		"ok": true,
		"errors": [],
		"target": target,
		"stat_key": str(effect.stat_key),
		"operation": operation,
		"value": effect.value,
	}


static func _target_for_effect(state: Dictionary, target_scope: String, target_id: String, errors: Array[String]):
	match target_scope:
		"city":
			if not state.has("cities") or not state.cities.has(target_id):
				errors.append("effect target city not found %s" % target_id)
				return null
			return state.cities[target_id]
		"force":
			if not state.has("forces") or not state.forces.has(target_id):
				errors.append("effect target force not found %s" % target_id)
				return null
			return state.forces[target_id]
		"army":
			if not state.has("armies") or not state.armies.has(target_id):
				errors.append("effect target army not found %s" % target_id)
				return null
			return state.armies[target_id]
		"officer":
			if not state.has("officers") or not state.officers.has(target_id):
				errors.append("effect target officer not found %s" % target_id)
				return null
			return state.officers[target_id]
		_:
			errors.append("unknown effect target_scope %s" % target_scope)
			return null


static func _apply_resolved_effect(effect: Dictionary) -> void:
	var target: Dictionary = effect.target
	var stat_key: String = effect.stat_key
	var current_value = target[stat_key]
	match effect.operation:
		"add_flat":
			target[stat_key] = current_value + effect.value
		"add_pct":
			target[stat_key] = int(round(float(current_value) * (1.0 + float(effect.value))))
		"mul":
			target[stat_key] = int(round(float(current_value) * float(effect.value)))
		"set":
			target[stat_key] = effect.value
