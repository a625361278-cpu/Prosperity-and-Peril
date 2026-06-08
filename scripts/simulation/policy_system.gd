extends RefCounted

const EffectSystem = preload("res://scripts/simulation/effect_system.gd")


static func activate_policy(state: Dictionary, policy: Dictionary) -> Dictionary:
	var errors := _validate_policy_for_activation(state, policy)
	if not errors.is_empty():
		return {"ok": false, "errors": errors}

	var effect_result: Dictionary = EffectSystem.apply_effect_group(state, policy.effects)
	if not effect_result.ok:
		return {"ok": false, "errors": effect_result.errors}

	var force: Dictionary = state.forces[policy.owner_force_id]
	force.gold -= int(policy.monthly_cost_gold)
	state.active_policies[policy.id] = {
		"id": policy.id,
		"name": policy.name,
		"owner_force_id": policy.owner_force_id,
		"monthly_cost_gold": int(policy.monthly_cost_gold),
		"effects": policy.effects.duplicate(true),
		"status": "active",
	}
	return {"ok": true, "errors": []}


static func apply_monthly_maintenance(state: Dictionary) -> Dictionary:
	if not state.has("active_policies"):
		return {"ok": false, "errors": ["runtime state missing active_policies"], "events": []}
	var events: Array[Dictionary] = []
	for policy_id in state.active_policies.keys():
		var policy: Dictionary = state.active_policies[policy_id]
		if policy.status != "active":
			continue
		if not state.forces.has(policy.owner_force_id):
			return {"ok": false, "errors": ["active policy owner force missing %s" % policy.owner_force_id], "events": events}
		var force: Dictionary = state.forces[policy.owner_force_id]
		var cost := int(policy.monthly_cost_gold)
		if not force.has("gold"):
			return {"ok": false, "errors": ["force missing gold for policy maintenance %s" % policy.owner_force_id], "events": events}
		if int(force.gold) < cost:
			policy.status = "paused"
			events.append({"type": "policy_paused", "policy_id": policy_id, "owner_force_id": policy.owner_force_id})
			continue
		force.gold -= cost
	return {"ok": true, "errors": [], "events": events}


static func _validate_policy_for_activation(state: Dictionary, policy: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for field in ["id", "name", "owner_force_id", "monthly_cost_gold", "effects"]:
		if not policy.has(field):
			errors.append("policy.%s missing required field" % field)
	if not state.has("active_policies"):
		errors.append("runtime state missing active_policies")
	if not errors.is_empty():
		return errors
	if state.active_policies.has(policy.id):
		errors.append("policy already active %s" % policy.id)
	if not state.has("forces") or not state.forces.has(policy.owner_force_id):
		errors.append("policy owner force not found %s" % policy.owner_force_id)
		return errors
	var force: Dictionary = state.forces[policy.owner_force_id]
	if not force.has("gold"):
		errors.append("force missing gold for policy activation %s" % policy.owner_force_id)
	elif int(force.gold) < int(policy.monthly_cost_gold):
		errors.append("force gold is insufficient for policy activation")
	if not policy.effects is Array:
		errors.append("policy.effects must be an array")
	return errors

