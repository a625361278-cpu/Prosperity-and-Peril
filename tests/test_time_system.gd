extends SceneTree

const CoreDataLoader = preload("res://scripts/data/core_data_loader.gd")
const CoreStateFactory = preload("res://scripts/simulation/core_state_factory.gd")
const TimeSystem = preload("res://scripts/simulation/time_system.gd")


var _failed := 0


func _initialize() -> void:
	_run("advancing one day updates runtime state", _test_advancing_one_day)
	_run("advancing thirty days emits monthly tick", _test_monthly_tick)
	_run("invalid day count fails loudly", _test_invalid_day_count_fails)
	quit(_failed)


func _run(test_name: String, test_func: Callable) -> void:
	var result: Dictionary = test_func.call()
	if result.get("ok", false):
		print("PASS: %s" % test_name)
	else:
		_failed += 1
		push_error("FAIL: %s -> %s" % [test_name, result.get("message", "no message")])


func _test_advancing_one_day() -> Dictionary:
	var state_result := _build_state()
	if not state_result.ok:
		return state_result

	var result: Dictionary = TimeSystem.advance_days(state_result.state, 1)
	if not result.ok:
		return {"ok": false, "message": "expected success, got %s" % [result.errors]}
	if state_result.state.current_day != 1:
		return {"ok": false, "message": "expected current_day 1, got %s" % state_result.state.current_day}
	if state_result.state.current_month != 1:
		return {"ok": false, "message": "expected current_month to remain 1"}
	if not result.events.is_empty():
		return {"ok": false, "message": "expected no events for a single day, got %s" % [result.events]}
	return {"ok": true}


func _test_monthly_tick() -> Dictionary:
	var state_result := _build_state()
	if not state_result.ok:
		return state_result

	var result: Dictionary = TimeSystem.advance_days(state_result.state, 30)
	if not result.ok:
		return {"ok": false, "message": "expected success, got %s" % [result.errors]}
	if state_result.state.current_day != 30:
		return {"ok": false, "message": "expected current_day 30"}
	if state_result.state.current_month != 2:
		return {"ok": false, "message": "expected current_month 2 after first monthly tick"}
	if result.events.size() != 1:
		return {"ok": false, "message": "expected exactly one monthly event, got %s" % [result.events]}
	if result.events[0].type != "monthly_tick":
		return {"ok": false, "message": "expected monthly_tick event"}
	return {"ok": true}


func _test_invalid_day_count_fails() -> Dictionary:
	var state_result := _build_state()
	if not state_result.ok:
		return state_result

	var result: Dictionary = TimeSystem.advance_days(state_result.state, 0)
	if result.ok:
		return {"ok": false, "message": "expected zero-day advance to fail"}
	for error in result.errors:
		if str(error).contains("days must be a positive integer"):
			return {"ok": true}
	return {"ok": false, "message": "expected positive integer error, got %s" % [result.errors]}


func _build_state() -> Dictionary:
	var loaded: Dictionary = CoreDataLoader.load_and_validate("res://data/prototype_v0_1/core_test_data.json")
	if not loaded.ok:
		return {"ok": false, "message": "data failed to load: %s" % [loaded.errors]}
	var state_result: Dictionary = CoreStateFactory.build_from_dataset(loaded.dataset)
	if not state_result.ok:
		return {"ok": false, "message": "state failed to build: %s" % [state_result.errors]}
	return {"ok": true, "state": state_result.state}

