extends SceneTree

const CoreDataLoader = preload("res://scripts/data/core_data_loader.gd")
const CoreStateFactory = preload("res://scripts/simulation/core_state_factory.gd")
const LocalGovernanceSystem = preload("res://scripts/simulation/local_governance_system.gd")


var _failed := 0


func _initialize() -> void:
	_run("city gentry support initializes from data", _test_gentry_support_initializes)
	_run("low gentry pressure changes morale order and logs", _test_low_gentry_pressure_changes_city)
	_run("gentry pressure rule does not mutate when not triggered", _test_rule_not_triggered_no_mutation)
	_run("gentry pressure rule fails when city field is missing", _test_missing_city_field_fails)
	quit(_failed)


func _run(test_name: String, test_func: Callable) -> void:
	var result: Dictionary = test_func.call()
	if result.get("ok", false):
		print("PASS: %s" % test_name)
	else:
		_failed += 1
		push_error("FAIL: %s -> %s" % [test_name, result.get("message", "no message")])


func _test_gentry_support_initializes() -> Dictionary:
	var state_result := _build_state()
	if not state_result.ok:
		return state_result
	if state_result.state.cities.CITY_TEST_A.gentry_support != 72:
		return {"ok": false, "message": "expected CITY_TEST_A gentry_support 72"}
	if state_result.state.cities.CITY_TEST_B.gentry_support != 35:
		return {"ok": false, "message": "expected CITY_TEST_B gentry_support 35"}
	if not state_result.state.has("local_governance_logs"):
		return {"ok": false, "message": "runtime state missing local_governance_logs"}
	return {"ok": true}


func _test_low_gentry_pressure_changes_city() -> Dictionary:
	var state_result := _build_state()
	if not state_result.ok:
		return state_result
	var result: Dictionary = LocalGovernanceSystem.apply_gentry_pressure_rule(state_result.state, _low_support_rule())
	if not result.ok:
		return {"ok": false, "message": "expected local governance success, got %s" % [result.errors]}
	if not result.triggered:
		return {"ok": false, "message": "expected low support rule to trigger"}
	if state_result.state.cities.CITY_TEST_B.public_order != 60:
		return {"ok": false, "message": "expected public_order 60"}
	if state_result.state.cities.CITY_TEST_B.morale_public != 57:
		return {"ok": false, "message": "expected morale_public 57"}
	if not state_result.state.local_governance_logs.has("LGOVLOG_1"):
		return {"ok": false, "message": "expected local governance log"}
	return {"ok": true}


func _test_rule_not_triggered_no_mutation() -> Dictionary:
	var state_result := _build_state()
	if not state_result.ok:
		return state_result
	var rule := _low_support_rule()
	rule.city_id = "CITY_TEST_A"
	var result: Dictionary = LocalGovernanceSystem.apply_gentry_pressure_rule(state_result.state, rule)
	if not result.ok:
		return {"ok": false, "message": "expected non-trigger success, got %s" % [result.errors]}
	if result.triggered:
		return {"ok": false, "message": "expected rule not to trigger"}
	if state_result.state.cities.CITY_TEST_A.public_order != 80:
		return {"ok": false, "message": "public_order changed when rule was not triggered"}
	if not state_result.state.local_governance_logs.is_empty():
		return {"ok": false, "message": "log written when rule was not triggered"}
	return {"ok": true}


func _test_missing_city_field_fails() -> Dictionary:
	var state_result := _build_state()
	if not state_result.ok:
		return state_result
	state_result.state.cities.CITY_TEST_B.erase("gentry_support")
	var result: Dictionary = LocalGovernanceSystem.apply_gentry_pressure_rule(state_result.state, _low_support_rule())
	if result.ok:
		return {"ok": false, "message": "expected missing city field failure"}
	for error in result.errors:
		if str(error).contains("city missing gentry_support CITY_TEST_B"):
			return {"ok": true}
	return {"ok": false, "message": "expected missing gentry_support error, got %s" % [result.errors]}


func _build_state() -> Dictionary:
	var loaded: Dictionary = CoreDataLoader.load_and_validate("res://data/prototype_v0_1/core_test_data.json")
	if not loaded.ok:
		return {"ok": false, "message": "data failed to load: %s" % [loaded.errors]}
	var state_result: Dictionary = CoreStateFactory.build_from_dataset(loaded.dataset)
	if not state_result.ok:
		return {"ok": false, "message": "state failed to build: %s" % [state_result.errors]}
	return {"ok": true, "state": state_result.state}


func _low_support_rule() -> Dictionary:
	return {
		"id": "LGOV_LOW_GENTRY_TEST",
		"city_id": "CITY_TEST_B",
		"gentry_support_below": 40,
		"public_order_delta": -5,
		"morale_public_delta": -3,
		"integration_progress_delta": 0,
		"reason": "low_gentry_support",
	}
