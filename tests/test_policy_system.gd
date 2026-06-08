extends SceneTree

const CoreDataLoader = preload("res://scripts/data/core_data_loader.gd")
const CoreStateFactory = preload("res://scripts/simulation/core_state_factory.gd")
const PolicySystem = preload("res://scripts/simulation/policy_system.gd")


var _failed := 0


func _initialize() -> void:
	_run("activating policy deducts cost records policy and applies effect", _test_activate_policy)
	_run("monthly maintenance deducts active policy cost", _test_monthly_maintenance)
	_run("insufficient gold pauses policy without applying effects", _test_insufficient_gold_pauses_policy)
	_run("invalid policy effect fails without deducting gold", _test_invalid_effect_fails_without_cost)
	quit(_failed)


func _run(test_name: String, test_func: Callable) -> void:
	var result: Dictionary = test_func.call()
	if result.get("ok", false):
		print("PASS: %s" % test_name)
	else:
		_failed += 1
		push_error("FAIL: %s -> %s" % [test_name, result.get("message", "no message")])


func _test_activate_policy() -> Dictionary:
	var state_result := _build_state()
	if not state_result.ok:
		return state_result
	var policy := _test_policy()
	var result: Dictionary = PolicySystem.activate_policy(state_result.state, policy)
	if not result.ok:
		return {"ok": false, "message": "expected policy success, got %s" % [result.errors]}
	if state_result.state.forces.FORCE_PLAYER.gold != 900:
		return {"ok": false, "message": "expected force gold 900"}
	if not state_result.state.active_policies.has("POLICY_TEST_ORDER"):
		return {"ok": false, "message": "expected active policy record"}
	if state_result.state.cities.CITY_TEST_A.public_order != 85:
		return {"ok": false, "message": "expected city public_order effect"}
	return {"ok": true}


func _test_monthly_maintenance() -> Dictionary:
	var state_result := _build_state()
	var policy := _test_policy()
	PolicySystem.activate_policy(state_result.state, policy)
	var result: Dictionary = PolicySystem.apply_monthly_maintenance(state_result.state)
	if not result.ok:
		return {"ok": false, "message": "expected maintenance success, got %s" % [result.errors]}
	if state_result.state.forces.FORCE_PLAYER.gold != 800:
		return {"ok": false, "message": "expected monthly maintenance to deduct another 100"}
	if state_result.state.active_policies.POLICY_TEST_ORDER.status != "active":
		return {"ok": false, "message": "expected policy to remain active"}
	return {"ok": true}


func _test_insufficient_gold_pauses_policy() -> Dictionary:
	var state_result := _build_state()
	var policy := _test_policy()
	PolicySystem.activate_policy(state_result.state, policy)
	state_result.state.forces.FORCE_PLAYER.gold = 50
	var result: Dictionary = PolicySystem.apply_monthly_maintenance(state_result.state)
	if not result.ok:
		return {"ok": false, "message": "maintenance should report pause through events, not fail: %s" % [result.errors]}
	if state_result.state.forces.FORCE_PLAYER.gold != 50:
		return {"ok": false, "message": "insufficient gold should not be deducted"}
	if state_result.state.active_policies.POLICY_TEST_ORDER.status != "paused":
		return {"ok": false, "message": "expected policy paused"}
	if result.events[0].type != "policy_paused":
		return {"ok": false, "message": "expected policy_paused event"}
	return {"ok": true}


func _test_invalid_effect_fails_without_cost() -> Dictionary:
	var state_result := _build_state()
	var policy := _test_policy()
	policy.effects[0].stat_key = "missing_stat"
	var result: Dictionary = PolicySystem.activate_policy(state_result.state, policy)
	if result.ok:
		return {"ok": false, "message": "expected invalid effect to fail"}
	if state_result.state.forces.FORCE_PLAYER.gold != 1000:
		return {"ok": false, "message": "gold changed after invalid policy"}
	if state_result.state.active_policies.has("POLICY_TEST_ORDER"):
		return {"ok": false, "message": "invalid policy was recorded as active"}
	return {"ok": true}


func _build_state() -> Dictionary:
	var loaded: Dictionary = CoreDataLoader.load_and_validate("res://data/prototype_v0_1/core_test_data.json")
	if not loaded.ok:
		return {"ok": false, "message": "data failed to load: %s" % [loaded.errors]}
	var state_result: Dictionary = CoreStateFactory.build_from_dataset(loaded.dataset)
	if not state_result.ok:
		return {"ok": false, "message": "state failed to build: %s" % [state_result.errors]}
	state_result.state.forces.FORCE_PLAYER.gold = 1000
	return {"ok": true, "state": state_result.state}


func _test_policy() -> Dictionary:
	return {
		"id": "POLICY_TEST_ORDER",
		"name": "测试治安令",
		"owner_force_id": "FORCE_PLAYER",
		"monthly_cost_gold": 100,
		"effects": [
			{"target_scope": "city", "target_id": "CITY_TEST_A", "stat_key": "public_order", "operation": "add_flat", "value": 5}
		],
	}

