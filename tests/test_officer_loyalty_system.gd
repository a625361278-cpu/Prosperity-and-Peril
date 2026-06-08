extends SceneTree

const CoreDataLoader = preload("res://scripts/data/core_data_loader.gd")
const CoreStateFactory = preload("res://scripts/simulation/core_state_factory.gd")
const OfficerLoyaltySystem = preload("res://scripts/simulation/officer_loyalty_system.gd")


var _failed := 0


func _initialize() -> void:
	_run("officer loyalty and relations initialize from data", _test_initializes_loyalty_and_relations)
	_run("loyalty change clamps value and writes log", _test_loyalty_change_clamps_and_logs)
	_run("defector state marks officer as watching risk", _test_defector_state_marks_risk)
	_run("loyalty change rejects missing officer without mutation", _test_missing_officer_fails)
	quit(_failed)


func _run(test_name: String, test_func: Callable) -> void:
	var result: Dictionary = test_func.call()
	if result.get("ok", false):
		print("PASS: %s" % test_name)
	else:
		_failed += 1
		push_error("FAIL: %s -> %s" % [test_name, result.get("message", "no message")])


func _test_initializes_loyalty_and_relations() -> Dictionary:
	var state_result := _build_state()
	if not state_result.ok:
		return state_result
	if state_result.state.officers.OFF_TEST_PLAYER.loyalty != 90:
		return {"ok": false, "message": "expected player officer loyalty 90"}
	if state_result.state.officers.OFF_TEST_ENEMY.loyalty != 58:
		return {"ok": false, "message": "expected enemy officer loyalty 58"}
	if not state_result.state.officer_relations.has("REL_TEST_RIVAL"):
		return {"ok": false, "message": "expected REL_TEST_RIVAL"}
	return {"ok": true}


func _test_loyalty_change_clamps_and_logs() -> Dictionary:
	var state_result := _build_state()
	if not state_result.ok:
		return state_result
	var result: Dictionary = OfficerLoyaltySystem.apply_loyalty_change(state_result.state, {
		"id": "LOY_TEST_REWARD",
		"officer_id": "OFF_TEST_ENEMY",
		"loyalty_delta": 60,
		"reason": "reward",
		"source_type": "test",
	})
	if not result.ok:
		return {"ok": false, "message": "expected loyalty change success, got %s" % [result.errors]}
	if state_result.state.officers.OFF_TEST_ENEMY.loyalty != 100:
		return {"ok": false, "message": "expected loyalty clamp to 100"}
	if not state_result.state.loyalty_logs.has("LOYLOG_1"):
		return {"ok": false, "message": "expected LOYLOG_1"}
	return {"ok": true}


func _test_defector_state_marks_risk() -> Dictionary:
	var state_result := _build_state()
	if not state_result.ok:
		return state_result
	var result: Dictionary = OfficerLoyaltySystem.create_defector_state(state_result.state, {
		"id": "DEF_TEST_JOIN",
		"officer_id": "OFF_TEST_ENEMY",
		"old_force_id": "FORCE_ENEMY",
		"new_force_id": "FORCE_PLAYER",
		"trust_initial": 25,
		"loyalty_delta": -20,
		"reason": "surrendered_after_battle",
	})
	if not result.ok:
		return {"ok": false, "message": "expected defector state success, got %s" % [result.errors]}
	if state_result.state.officers.OFF_TEST_ENEMY.force_id != "FORCE_PLAYER":
		return {"ok": false, "message": "expected defector force updated"}
	if state_result.state.officers.OFF_TEST_ENEMY.loyalty != 38:
		return {"ok": false, "message": "expected loyalty after defection 38"}
	if not state_result.state.defector_states.has("OFF_TEST_ENEMY"):
		return {"ok": false, "message": "expected defector state"}
	var risk: Dictionary = OfficerLoyaltySystem.loyalty_risk_for_officer(state_result.state, "OFF_TEST_ENEMY")
	if not risk.ok:
		return {"ok": false, "message": "expected risk read success, got %s" % [risk.errors]}
	if risk.risk_level != "high":
		return {"ok": false, "message": "expected high risk, got %s" % risk.risk_level}
	return {"ok": true}


func _test_missing_officer_fails() -> Dictionary:
	var state_result := _build_state()
	if not state_result.ok:
		return state_result
	var result: Dictionary = OfficerLoyaltySystem.apply_loyalty_change(state_result.state, {
		"id": "LOY_TEST_MISSING",
		"officer_id": "OFF_MISSING",
		"loyalty_delta": 1,
		"reason": "bad_officer",
		"source_type": "test",
	})
	if result.ok:
		return {"ok": false, "message": "expected missing officer failure"}
	if not state_result.state.loyalty_logs.is_empty():
		return {"ok": false, "message": "loyalty log changed after failure"}
	for error in result.errors:
		if str(error).contains("loyalty officer not found OFF_MISSING"):
			return {"ok": true}
	return {"ok": false, "message": "expected missing officer error, got %s" % [result.errors]}


func _build_state() -> Dictionary:
	var loaded: Dictionary = CoreDataLoader.load_and_validate("res://data/prototype_v0_1/core_test_data.json")
	if not loaded.ok:
		return {"ok": false, "message": "data failed to load: %s" % [loaded.errors]}
	var state_result: Dictionary = CoreStateFactory.build_from_dataset(loaded.dataset)
	if not state_result.ok:
		return {"ok": false, "message": "state failed to build: %s" % [state_result.errors]}
	return {"ok": true, "state": state_result.state}
