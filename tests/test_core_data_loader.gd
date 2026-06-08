extends SceneTree

const CoreDataLoader = preload("res://scripts/data/core_data_loader.gd")


var _failed := 0


func _initialize() -> void:
	_run("loads and validates Prototype V0.1 core test data", _test_loads_core_test_data)
	_run("missing data file fails loudly", _test_missing_data_file_fails)
	quit(_failed)


func _run(test_name: String, test_func: Callable) -> void:
	var result: Dictionary = test_func.call()
	if result.get("ok", false):
		print("PASS: %s" % test_name)
	else:
		_failed += 1
		push_error("FAIL: %s -> %s" % [test_name, result.get("message", "no message")])


func _test_loads_core_test_data() -> Dictionary:
	var result: Dictionary = CoreDataLoader.load_and_validate("res://data/prototype_v0_1/core_test_data.json")
	if not result.ok:
		return {"ok": false, "message": "expected load success, got %s" % [result.errors]}
	if result.dataset.cities.size() != 2:
		return {"ok": false, "message": "expected 2 cities, got %d" % result.dataset.cities.size()}
	if result.dataset.routes[0].distance != 60.0:
		return {"ok": false, "message": "expected test route distance 60.0"}
	return {"ok": true}


func _test_missing_data_file_fails() -> Dictionary:
	var result: Dictionary = CoreDataLoader.load_and_validate("res://data/prototype_v0_1/missing.json")
	if result.ok:
		return {"ok": false, "message": "expected missing file failure"}
	for error in result.errors:
		if str(error).contains("data file not found"):
			return {"ok": true}
	return {"ok": false, "message": "expected data file not found, got %s" % [result.errors]}

