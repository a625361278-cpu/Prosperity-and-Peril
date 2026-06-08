extends SceneTree

const CoreDataLoader = preload("res://scripts/data/core_data_loader.gd")
const CoreStateFactory = preload("res://scripts/simulation/core_state_factory.gd")
const SortieSystem = preload("res://scripts/simulation/sortie_system.gd")
const MarchSystem = preload("res://scripts/simulation/march_system.gd")


var _failed := 0


func _initialize() -> void:
	_run("march start calculates required days from route distance and speed", _test_start_march)
	_run("daily march advances progress and consumes food", _test_daily_march_consumes_food)
	_run("army enters engaged state after required march days", _test_march_completion)
	_run("insufficient food enters out of supply state", _test_out_of_supply)
	quit(_failed)


func _run(test_name: String, test_func: Callable) -> void:
	var result: Dictionary = test_func.call()
	if result.get("ok", false):
		print("PASS: %s" % test_name)
	else:
		_failed += 1
		push_error("FAIL: %s -> %s" % [test_name, result.get("message", "no message")])


func _test_start_march() -> Dictionary:
	var setup := _create_army(16000)
	if not setup.ok:
		return setup

	var result: Dictionary = MarchSystem.start_march(setup.state, setup.army_id, 12.0, 1000)
	if not result.ok:
		return {"ok": false, "message": "expected march start success, got %s" % [result.errors]}
	var army: Dictionary = setup.state.armies[setup.army_id]
	if army.state != "marching":
		return {"ok": false, "message": "expected marching state"}
	if army.days_required != 5:
		return {"ok": false, "message": "expected 5 required days, got %s" % army.days_required}
	return {"ok": true}


func _test_daily_march_consumes_food() -> Dictionary:
	var setup := _create_army(16000)
	if not setup.ok:
		return setup

	MarchSystem.start_march(setup.state, setup.army_id, 12.0, 1000)
	var result: Dictionary = MarchSystem.advance_army_one_day(setup.state, setup.army_id)
	if not result.ok:
		return {"ok": false, "message": "expected daily march success, got %s" % [result.errors]}
	var army: Dictionary = setup.state.armies[setup.army_id]
	if army.route_progress_days != 1:
		return {"ok": false, "message": "expected route_progress_days 1"}
	if army.food_current != 15000:
		return {"ok": false, "message": "expected food_current 15000, got %s" % army.food_current}
	if army.state != "marching":
		return {"ok": false, "message": "expected army to keep marching after one day"}
	return {"ok": true}


func _test_march_completion() -> Dictionary:
	var setup := _create_army(16000)
	if not setup.ok:
		return setup

	MarchSystem.start_march(setup.state, setup.army_id, 12.0, 1000)
	for _i in 5:
		var result: Dictionary = MarchSystem.advance_army_one_day(setup.state, setup.army_id)
		if not result.ok:
			return {"ok": false, "message": "advance failed: %s" % [result.errors]}
	var army: Dictionary = setup.state.armies[setup.army_id]
	if army.route_progress_days != 5:
		return {"ok": false, "message": "expected route_progress_days 5"}
	if army.state != "engaged":
		return {"ok": false, "message": "expected engaged state after arrival, got %s" % army.state}
	return {"ok": true}


func _test_out_of_supply() -> Dictionary:
	var setup := _create_army(1000)
	if not setup.ok:
		return setup

	MarchSystem.start_march(setup.state, setup.army_id, 12.0, 2000)
	var result: Dictionary = MarchSystem.advance_army_one_day(setup.state, setup.army_id)
	if not result.ok:
		return {"ok": false, "message": "expected out-of-supply transition success, got %s" % [result.errors]}
	var army: Dictionary = setup.state.armies[setup.army_id]
	if army.food_current != 0:
		return {"ok": false, "message": "expected food to clamp at 0"}
	if army.state != "out_of_supply":
		return {"ok": false, "message": "expected out_of_supply state"}
	if not army.out_of_supply:
		return {"ok": false, "message": "expected out_of_supply flag"}
	return {"ok": true}


func _create_army(food_amount: int) -> Dictionary:
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
		food_amount
	)
	if not sortie.ok:
		return {"ok": false, "message": "sortie failed: %s" % [sortie.errors]}
	return {"ok": true, "state": state_result.state, "army_id": sortie.army_id}

