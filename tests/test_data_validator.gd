extends SceneTree

const DataValidator = preload("res://scripts/data/data_validator.gd")


var _failed := 0


func _initialize() -> void:
	_run("valid core dataset passes validation", _test_valid_core_dataset)
	_run("missing required field fails validation", _test_missing_required_field)
	_run("duplicate primary key fails validation", _test_duplicate_primary_key)
	_run("invalid enum value fails validation", _test_invalid_enum_value)
	_run("invalid foreign key fails validation", _test_invalid_foreign_key)
	quit(_failed)


func _run(test_name: String, test_func: Callable) -> void:
	var result: Dictionary = test_func.call()
	if result.get("ok", false):
		print("PASS: %s" % test_name)
	else:
		_failed += 1
		push_error("FAIL: %s -> %s" % [test_name, result.get("message", "no message")])


func _test_valid_core_dataset() -> Dictionary:
	var result: Dictionary = DataValidator.validate_dataset(_valid_dataset())
	return _expect_true(result.ok, "expected valid dataset, got errors: %s" % [result.errors])


func _test_missing_required_field() -> Dictionary:
	var dataset := _valid_dataset()
	dataset.cities[0].erase("food")
	var result: Dictionary = DataValidator.validate_dataset(dataset)
	return _expect_error_contains(result, "cities[0].food")


func _test_duplicate_primary_key() -> Dictionary:
	var dataset := _valid_dataset()
	dataset.cities.append(dataset.cities[0].duplicate(true))
	var result: Dictionary = DataValidator.validate_dataset(dataset)
	return _expect_error_contains(result, "duplicate cities id CITY_TEST_A")


func _test_invalid_enum_value() -> Dictionary:
	var dataset := _valid_dataset()
	dataset.routes[0].route_type = "sky"
	var result: Dictionary = DataValidator.validate_dataset(dataset)
	return _expect_error_contains(result, "routes[0].route_type invalid enum value sky")


func _test_invalid_foreign_key() -> Dictionary:
	var dataset := _valid_dataset()
	dataset.forces[0].capital_city_id = "CITY_MISSING"
	var result: Dictionary = DataValidator.validate_dataset(dataset)
	return _expect_error_contains(result, "forces[0].capital_city_id references missing cities id CITY_MISSING")


func _expect_true(value: bool, message: String) -> Dictionary:
	if value:
		return {"ok": true}
	return {"ok": false, "message": message}


func _expect_error_contains(result: Dictionary, expected: String) -> Dictionary:
	if result.ok:
		return {"ok": false, "message": "expected validation failure containing '%s', got success" % expected}
	for error in result.errors:
		if str(error).contains(expected):
			return {"ok": true}
	return {"ok": false, "message": "expected error containing '%s', got %s" % [expected, result.errors]}


func _valid_dataset() -> Dictionary:
	return {
		"cities": [
			{
				"id": "CITY_TEST_A",
				"name": "测试甲城",
				"force_id": "FORCE_PLAYER",
				"troops": 20000,
				"food": 50000,
				"public_order": 80,
				"morale_public": 70,
				"recovery_state": "normal",
			},
			{
				"id": "CITY_TEST_B",
				"name": "测试乙城",
				"force_id": "FORCE_ENEMY",
				"troops": 12000,
				"food": 30000,
				"public_order": 65,
				"morale_public": 60,
				"recovery_state": "normal",
			},
		],
		"forces": [
			{"id": "FORCE_PLAYER", "name": "玩家测试势力", "ruler_officer_id": "OFF_TEST_PLAYER", "capital_city_id": "CITY_TEST_A", "legitimacy_base": 62, "prestige_base": 48},
			{"id": "FORCE_ENEMY", "name": "敌方测试势力", "ruler_officer_id": "OFF_TEST_ENEMY", "capital_city_id": "CITY_TEST_B", "legitimacy_base": 35, "prestige_base": 55},
		],
		"officers": [
			{"id": "OFF_TEST_PLAYER", "name": "测试主将", "force_id": "FORCE_PLAYER", "leadership": 80, "politics": 60},
			{"id": "OFF_TEST_ENEMY", "name": "测试守将", "force_id": "FORCE_ENEMY", "leadership": 70, "politics": 50},
		],
		"routes": [
			{
				"id": "ROUTE_TEST_A_B",
				"from_city_id": "CITY_TEST_A",
				"to_city_id": "CITY_TEST_B",
				"route_type": "road",
				"distance": 60.0,
				"terrain_modifier": 1.0,
				"supply_modifier": 1.0,
				"battle_trigger": "field",
			}
		],
	}
