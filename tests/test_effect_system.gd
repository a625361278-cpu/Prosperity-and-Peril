extends SceneTree

const CoreDataLoader = preload("res://scripts/data/core_data_loader.gd")
const CoreStateFactory = preload("res://scripts/simulation/core_state_factory.gd")
const EffectSystem = preload("res://scripts/simulation/effect_system.gd")


var _failed := 0


func _initialize() -> void:
	_run("effect group applies flat city stat change", _test_flat_city_effect)
	_run("effect group applies percentage city stat change", _test_percentage_city_effect)
	_run("unknown operation fails loudly", _test_unknown_operation_fails)
	_run("missing target fails loudly", _test_missing_target_fails)
	quit(_failed)


func _run(test_name: String, test_func: Callable) -> void:
	var result: Dictionary = test_func.call()
	if result.get("ok", false):
		print("PASS: %s" % test_name)
	else:
		_failed += 1
		push_error("FAIL: %s -> %s" % [test_name, result.get("message", "no message")])


func _test_flat_city_effect() -> Dictionary:
	var state_result := _build_state()
	if not state_result.ok:
		return state_result
	var effects := [
		{"target_scope": "city", "target_id": "CITY_TEST_A", "stat_key": "public_order", "operation": "add_flat", "value": 5}
	]
	var result: Dictionary = EffectSystem.apply_effect_group(state_result.state, effects)
	if not result.ok:
		return {"ok": false, "message": "expected effect success, got %s" % [result.errors]}
	if state_result.state.cities.CITY_TEST_A.public_order != 85:
		return {"ok": false, "message": "expected public_order 85"}
	return {"ok": true}


func _test_percentage_city_effect() -> Dictionary:
	var state_result := _build_state()
	if not state_result.ok:
		return state_result
	var effects := [
		{"target_scope": "city", "target_id": "CITY_TEST_A", "stat_key": "food", "operation": "add_pct", "value": 0.1}
	]
	var result: Dictionary = EffectSystem.apply_effect_group(state_result.state, effects)
	if not result.ok:
		return {"ok": false, "message": "expected effect success, got %s" % [result.errors]}
	if state_result.state.cities.CITY_TEST_A.food != 55000:
		return {"ok": false, "message": "expected food 55000, got %s" % state_result.state.cities.CITY_TEST_A.food}
	return {"ok": true}


func _test_unknown_operation_fails() -> Dictionary:
	var state_result := _build_state()
	var effects := [
		{"target_scope": "city", "target_id": "CITY_TEST_A", "stat_key": "food", "operation": "invent", "value": 1}
	]
	var result: Dictionary = EffectSystem.apply_effect_group(state_result.state, effects)
	if result.ok:
		return {"ok": false, "message": "expected unknown operation to fail"}
	for error in result.errors:
		if str(error).contains("unknown effect operation invent"):
			return {"ok": true}
	return {"ok": false, "message": "expected unknown operation error, got %s" % [result.errors]}


func _test_missing_target_fails() -> Dictionary:
	var state_result := _build_state()
	var effects := [
		{"target_scope": "city", "target_id": "CITY_MISSING", "stat_key": "food", "operation": "add_flat", "value": 1}
	]
	var result: Dictionary = EffectSystem.apply_effect_group(state_result.state, effects)
	if result.ok:
		return {"ok": false, "message": "expected missing target to fail"}
	for error in result.errors:
		if str(error).contains("effect target city not found CITY_MISSING"):
			return {"ok": true}
	return {"ok": false, "message": "expected missing target error, got %s" % [result.errors]}


func _build_state() -> Dictionary:
	var loaded: Dictionary = CoreDataLoader.load_and_validate("res://data/prototype_v0_1/core_test_data.json")
	if not loaded.ok:
		return {"ok": false, "message": "data failed to load: %s" % [loaded.errors]}
	var state_result: Dictionary = CoreStateFactory.build_from_dataset(loaded.dataset)
	if not state_result.ok:
		return {"ok": false, "message": "state failed to build: %s" % [state_result.errors]}
	return {"ok": true, "state": state_result.state}

