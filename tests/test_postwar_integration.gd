extends SceneTree

const CoreDataLoader = preload("res://scripts/data/core_data_loader.gd")
const CoreStateFactory = preload("res://scripts/simulation/core_state_factory.gd")
const SortieSystem = preload("res://scripts/simulation/sortie_system.gd")
const MarchSystem = preload("res://scripts/simulation/march_system.gd")
const BattleSystem = preload("res://scripts/simulation/battle_system.gd")
const PostwarIntegrationSystem = preload("res://scripts/simulation/postwar_integration_system.gd")


var _failed := 0


func _initialize() -> void:
	_run("captured city enters occupied integration state", _test_captured_city_enters_integration_state)
	_run("integration task restores order and morale over time", _test_integration_task_progress)
	_run("normal city cannot run postwar integration", _test_normal_city_refuses_integration)
	quit(_failed)


func _run(test_name: String, test_func: Callable) -> void:
	var result: Dictionary = test_func.call()
	if result.get("ok", false):
		print("PASS: %s" % test_name)
	else:
		_failed += 1
		push_error("FAIL: %s -> %s" % [test_name, result.get("message", "no message")])


func _test_captured_city_enters_integration_state() -> Dictionary:
	var setup := _capture_city()
	if not setup.ok:
		return setup

	var city: Dictionary = setup.state.cities.CITY_TEST_B
	if city.recovery_state != "occupied":
		return {"ok": false, "message": "expected occupied state"}
	if city.integration_progress != 0:
		return {"ok": false, "message": "expected integration_progress 0"}
	if city.public_order >= 65:
		return {"ok": false, "message": "expected public_order to decrease after occupation"}
	if city.morale_public >= 60:
		return {"ok": false, "message": "expected morale_public to decrease after occupation"}
	return {"ok": true}


func _test_integration_task_progress() -> Dictionary:
	var setup := _capture_city()
	if not setup.ok:
		return setup

	for _i in 4:
		var result: Dictionary = PostwarIntegrationSystem.apply_integration_task(setup.state, "CITY_TEST_B", "OFF_TEST_PLAYER")
		if not result.ok:
			return {"ok": false, "message": "integration failed: %s" % [result.errors]}

	var city: Dictionary = setup.state.cities.CITY_TEST_B
	if city.integration_progress != 100:
		return {"ok": false, "message": "expected integration_progress 100"}
	if city.recovery_state != "normal":
		return {"ok": false, "message": "expected recovered city to return normal"}
	if city.public_order <= 45:
		return {"ok": false, "message": "expected public_order to improve"}
	if city.morale_public <= 40:
		return {"ok": false, "message": "expected morale_public to improve"}
	return {"ok": true}


func _test_normal_city_refuses_integration() -> Dictionary:
	var loaded: Dictionary = CoreDataLoader.load_and_validate("res://data/prototype_v0_1/core_test_data.json")
	var state_result: Dictionary = CoreStateFactory.build_from_dataset(loaded.dataset)
	var result: Dictionary = PostwarIntegrationSystem.apply_integration_task(state_result.state, "CITY_TEST_A", "OFF_TEST_PLAYER")
	if result.ok:
		return {"ok": false, "message": "expected normal city integration to fail"}
	for error in result.errors:
		if str(error).contains("city is not occupied"):
			return {"ok": true}
	return {"ok": false, "message": "expected occupied-state error, got %s" % [result.errors]}


func _capture_city() -> Dictionary:
	var loaded: Dictionary = CoreDataLoader.load_and_validate("res://data/prototype_v0_1/core_test_data.json")
	if not loaded.ok:
		return {"ok": false, "message": "data failed to load: %s" % [loaded.errors]}
	var state_result: Dictionary = CoreStateFactory.build_from_dataset(loaded.dataset)
	if not state_result.ok:
		return {"ok": false, "message": "state failed to build: %s" % [state_result.errors]}
	var sortie: Dictionary = SortieSystem.create_sortie(
		state_result.state,
		"CITY_TEST_A",
		"OFF_TEST_PLAYER",
		"ROUTE_TEST_A_B",
		8000,
		16000
	)
	MarchSystem.start_march(state_result.state, sortie.army_id, 12.0, 1000)
	for _i in 5:
		MarchSystem.advance_army_one_day(state_result.state, sortie.army_id)
	var battle: Dictionary = BattleSystem.resolve_city_battle(state_result.state, sortie.army_id, "CITY_TEST_B")
	if not battle.ok:
		return {"ok": false, "message": "battle failed: %s" % [battle.errors]}
	return {"ok": true, "state": state_result.state}

