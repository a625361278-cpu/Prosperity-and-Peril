extends SceneTree

const CoreDataLoader = preload("res://scripts/data/core_data_loader.gd")
const CoreStateFactory = preload("res://scripts/simulation/core_state_factory.gd")
const LegitimacySystem = preload("res://scripts/simulation/legitimacy_system.gd")


var _failed := 0


func _initialize() -> void:
	_run("force legitimacy and prestige initialize from master data", _test_initializes_from_force_master_data)
	_run("legitimacy change clamps values and writes log", _test_change_clamps_and_logs)
	_run("legitimacy change accepts integer valued numeric input", _test_accepts_integer_valued_numeric_input)
	_run("legitimacy change rejects unknown force without mutation", _test_unknown_force_fails)
	_run("legitimacy change rejects non integer delta", _test_non_integer_delta_fails)
	quit(_failed)


func _run(test_name: String, test_func: Callable) -> void:
	var result: Dictionary = test_func.call()
	if result.get("ok", false):
		print("PASS: %s" % test_name)
	else:
		_failed += 1
		push_error("FAIL: %s -> %s" % [test_name, result.get("message", "no message")])


func _test_initializes_from_force_master_data() -> Dictionary:
	var state_result := _build_state()
	if not state_result.ok:
		return state_result
	if state_result.state.forces.FORCE_PLAYER.legitimacy != 62:
		return {"ok": false, "message": "expected FORCE_PLAYER legitimacy 62"}
	if state_result.state.forces.FORCE_PLAYER.prestige != 48:
		return {"ok": false, "message": "expected FORCE_PLAYER prestige 48"}
	if state_result.state.forces.FORCE_ENEMY.legitimacy != 35:
		return {"ok": false, "message": "expected FORCE_ENEMY legitimacy 35"}
	if not state_result.state.has("legitimacy_logs"):
		return {"ok": false, "message": "runtime state missing legitimacy_logs"}
	return {"ok": true}


func _test_change_clamps_and_logs() -> Dictionary:
	var state_result := _build_state()
	if not state_result.ok:
		return state_result
	var result: Dictionary = LegitimacySystem.apply_force_reputation_change(state_result.state, {
		"id": "LEG_TEST_WIN",
		"force_id": "FORCE_PLAYER",
		"legitimacy_delta": 50,
		"prestige_delta": 70,
		"reason": "capture_capital",
		"source_type": "test",
	})
	if not result.ok:
		return {"ok": false, "message": "expected legitimacy change success, got %s" % [result.errors]}
	if state_result.state.forces.FORCE_PLAYER.legitimacy != 100:
		return {"ok": false, "message": "expected legitimacy clamp to 100"}
	if state_result.state.forces.FORCE_PLAYER.prestige != 100:
		return {"ok": false, "message": "expected prestige clamp to 100"}
	if not state_result.state.legitimacy_logs.has("LEGLOG_1"):
		return {"ok": false, "message": "expected LEGLOG_1"}
	var log: Dictionary = state_result.state.legitimacy_logs.LEGLOG_1
	if log.legitimacy_before != 62 or log.legitimacy_after != 100:
		return {"ok": false, "message": "expected legitimacy before/after in log"}
	if log.prestige_before != 48 or log.prestige_after != 100:
		return {"ok": false, "message": "expected prestige before/after in log"}
	return {"ok": true}


func _test_unknown_force_fails() -> Dictionary:
	var state_result := _build_state()
	if not state_result.ok:
		return state_result
	var result: Dictionary = LegitimacySystem.apply_force_reputation_change(state_result.state, {
		"id": "LEG_TEST_UNKNOWN",
		"force_id": "FORCE_MISSING",
		"legitimacy_delta": 1,
		"prestige_delta": 1,
		"reason": "bad_force",
		"source_type": "test",
	})
	if result.ok:
		return {"ok": false, "message": "expected missing force failure"}
	if not state_result.state.legitimacy_logs.is_empty():
		return {"ok": false, "message": "log changed after failed change"}
	for error in result.errors:
		if str(error).contains("legitimacy force not found FORCE_MISSING"):
			return {"ok": true}
	return {"ok": false, "message": "expected missing force error, got %s" % [result.errors]}


func _test_accepts_integer_valued_numeric_input() -> Dictionary:
	var state_result := _build_state()
	if not state_result.ok:
		return state_result
	state_result.state.forces.FORCE_PLAYER.legitimacy = 62.0
	var result: Dictionary = LegitimacySystem.apply_force_reputation_change(state_result.state, {
		"id": "LEG_TEST_JSON_NUMBER",
		"force_id": "FORCE_PLAYER",
		"legitimacy_delta": 1.0,
		"prestige_delta": 0.0,
		"reason": "json_number",
		"source_type": "test",
	})
	if not result.ok:
		return {"ok": false, "message": "expected integer-valued numeric change success, got %s" % [result.errors]}
	if state_result.state.forces.FORCE_PLAYER.legitimacy != 63:
		return {"ok": false, "message": "expected legitimacy to become 63"}
	return {"ok": true}


func _test_non_integer_delta_fails() -> Dictionary:
	var state_result := _build_state()
	if not state_result.ok:
		return state_result
	var result: Dictionary = LegitimacySystem.apply_force_reputation_change(state_result.state, {
		"id": "LEG_TEST_BAD_DELTA",
		"force_id": "FORCE_PLAYER",
		"legitimacy_delta": "1",
		"prestige_delta": 0,
		"reason": "bad_delta",
		"source_type": "test",
	})
	if result.ok:
		return {"ok": false, "message": "expected non integer delta failure"}
	if state_result.state.forces.FORCE_PLAYER.legitimacy != 62:
		return {"ok": false, "message": "legitimacy changed after invalid delta"}
	for error in result.errors:
		if str(error).contains("legitimacy_change.legitimacy_delta must be an integer"):
			return {"ok": true}
	return {"ok": false, "message": "expected integer delta error, got %s" % [result.errors]}


func _build_state() -> Dictionary:
	var loaded: Dictionary = CoreDataLoader.load_and_validate("res://data/prototype_v0_1/core_test_data.json")
	if not loaded.ok:
		return {"ok": false, "message": "data failed to load: %s" % [loaded.errors]}
	var state_result: Dictionary = CoreStateFactory.build_from_dataset(loaded.dataset)
	if not state_result.ok:
		return {"ok": false, "message": "state failed to build: %s" % [state_result.errors]}
	return {"ok": true, "state": state_result.state}
