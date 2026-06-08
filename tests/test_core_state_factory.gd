extends SceneTree

const CoreDataLoader = preload("res://scripts/data/core_data_loader.gd")
const CoreStateFactory = preload("res://scripts/simulation/core_state_factory.gd")


var _failed := 0


func _initialize() -> void:
	_run("builds indexed runtime state from core dataset", _test_builds_indexed_runtime_state)
	_run("invalid dataset fails before runtime state is created", _test_invalid_dataset_fails)
	_run("runtime state is isolated from source dataset mutation", _test_runtime_state_isolated_from_source)
	quit(_failed)


func _run(test_name: String, test_func: Callable) -> void:
	var result: Dictionary = test_func.call()
	if result.get("ok", false):
		print("PASS: %s" % test_name)
	else:
		_failed += 1
		push_error("FAIL: %s -> %s" % [test_name, result.get("message", "no message")])


func _test_builds_indexed_runtime_state() -> Dictionary:
	var loaded: Dictionary = CoreDataLoader.load_and_validate("res://data/prototype_v0_1/core_test_data.json")
	if not loaded.ok:
		return {"ok": false, "message": "test fixture failed to load: %s" % [loaded.errors]}

	var result: Dictionary = CoreStateFactory.build_from_dataset(loaded.dataset)
	if not result.ok:
		return {"ok": false, "message": "expected runtime state, got %s" % [result.errors]}

	var state: Dictionary = result.state
	if state.current_day != 0:
		return {"ok": false, "message": "expected current_day 0"}
	if state.cities.size() != 2:
		return {"ok": false, "message": "expected 2 indexed cities"}
	if state.cities.CITY_TEST_A.food != 50000:
		return {"ok": false, "message": "expected CITY_TEST_A food 50000"}
	if state.forces.FORCE_PLAYER.capital_city_id != "CITY_TEST_A":
		return {"ok": false, "message": "expected FORCE_PLAYER capital CITY_TEST_A"}
	if state.officers.OFF_TEST_PLAYER.force_id != "FORCE_PLAYER":
		return {"ok": false, "message": "expected OFF_TEST_PLAYER force FORCE_PLAYER"}
	if state.routes.ROUTE_TEST_A_B.distance != 60.0:
		return {"ok": false, "message": "expected ROUTE_TEST_A_B distance 60.0"}
	if not state.armies.is_empty():
		return {"ok": false, "message": "expected V0.1 initial armies to be empty"}
	return {"ok": true}


func _test_invalid_dataset_fails() -> Dictionary:
	var loaded: Dictionary = CoreDataLoader.load_and_validate("res://data/prototype_v0_1/core_test_data.json")
	var dataset: Dictionary = loaded.dataset.duplicate(true)
	dataset.cities[0].erase("troops")

	var result: Dictionary = CoreStateFactory.build_from_dataset(dataset)
	if result.ok:
		return {"ok": false, "message": "expected invalid dataset to fail"}
	for error in result.errors:
		if str(error).contains("cities[0].troops"):
			return {"ok": true}
	return {"ok": false, "message": "expected missing troops error, got %s" % [result.errors]}


func _test_runtime_state_isolated_from_source() -> Dictionary:
	var loaded: Dictionary = CoreDataLoader.load_and_validate("res://data/prototype_v0_1/core_test_data.json")
	var result: Dictionary = CoreStateFactory.build_from_dataset(loaded.dataset)
	if not result.ok:
		return {"ok": false, "message": "expected runtime state, got %s" % [result.errors]}

	loaded.dataset.cities[0].food = 1
	if result.state.cities.CITY_TEST_A.food != 50000:
		return {"ok": false, "message": "runtime state changed after source dataset mutation"}
	return {"ok": true}

