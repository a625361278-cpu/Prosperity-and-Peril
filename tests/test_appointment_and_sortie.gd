extends SceneTree

const CoreDataLoader = preload("res://scripts/data/core_data_loader.gd")
const CoreStateFactory = preload("res://scripts/simulation/core_state_factory.gd")
const AppointmentSystem = preload("res://scripts/simulation/appointment_system.gd")
const SortieSystem = preload("res://scripts/simulation/sortie_system.gd")


var _failed := 0


func _initialize() -> void:
	_run("appointing same-force governor writes city and officer state", _test_appoint_governor)
	_run("appointing officer from another force fails", _test_appoint_enemy_officer_fails)
	_run("sortie deducts city troops and food and creates army", _test_sortie_creates_army)
	_run("sortie with insufficient food fails without changing city", _test_sortie_insufficient_food_fails)
	quit(_failed)


func _run(test_name: String, test_func: Callable) -> void:
	var result: Dictionary = test_func.call()
	if result.get("ok", false):
		print("PASS: %s" % test_name)
	else:
		_failed += 1
		push_error("FAIL: %s -> %s" % [test_name, result.get("message", "no message")])


func _test_appoint_governor() -> Dictionary:
	var state_result := _build_state()
	if not state_result.ok:
		return state_result

	var result: Dictionary = AppointmentSystem.appoint_governor(state_result.state, "CITY_TEST_A", "OFF_TEST_PLAYER")
	if not result.ok:
		return {"ok": false, "message": "expected appointment success, got %s" % [result.errors]}
	if state_result.state.cities.CITY_TEST_A.governor_officer_id != "OFF_TEST_PLAYER":
		return {"ok": false, "message": "city did not record governor"}
	if state_result.state.officers.OFF_TEST_PLAYER.assignment_type != "governor":
		return {"ok": false, "message": "officer did not record governor assignment"}
	if state_result.state.officers.OFF_TEST_PLAYER.assignment_target_id != "CITY_TEST_A":
		return {"ok": false, "message": "officer assignment target mismatch"}
	return {"ok": true}


func _test_appoint_enemy_officer_fails() -> Dictionary:
	var state_result := _build_state()
	if not state_result.ok:
		return state_result

	var result: Dictionary = AppointmentSystem.appoint_governor(state_result.state, "CITY_TEST_A", "OFF_TEST_ENEMY")
	if result.ok:
		return {"ok": false, "message": "expected enemy appointment to fail"}
	for error in result.errors:
		if str(error).contains("officer force does not match city owner"):
			return {"ok": true}
	return {"ok": false, "message": "expected force mismatch error, got %s" % [result.errors]}


func _test_sortie_creates_army() -> Dictionary:
	var state_result := _build_state()
	if not state_result.ok:
		return state_result

	var result: Dictionary = SortieSystem.create_sortie(
		state_result.state,
		"CITY_TEST_A",
		"OFF_TEST_PLAYER",
		"ROUTE_TEST_A_B",
		8000,
		16000
	)
	if not result.ok:
		return {"ok": false, "message": "expected sortie success, got %s" % [result.errors]}
	if result.army_id != "ARMY_1":
		return {"ok": false, "message": "expected ARMY_1, got %s" % result.army_id}
	if state_result.state.cities.CITY_TEST_A.troops != 12000:
		return {"ok": false, "message": "city troops were not deducted"}
	if state_result.state.cities.CITY_TEST_A.food != 34000:
		return {"ok": false, "message": "city food was not deducted"}
	if not state_result.state.armies.has("ARMY_1"):
		return {"ok": false, "message": "army was not added to runtime state"}
	var army: Dictionary = state_result.state.armies.ARMY_1
	if army.origin_city_id != "CITY_TEST_A":
		return {"ok": false, "message": "army origin mismatch"}
	if army.commander_officer_id != "OFF_TEST_PLAYER":
		return {"ok": false, "message": "army commander mismatch"}
	if army.state != "mobilizing":
		return {"ok": false, "message": "expected mobilizing army state"}
	if army.food_current != 16000:
		return {"ok": false, "message": "army food mismatch"}
	return {"ok": true}


func _test_sortie_insufficient_food_fails() -> Dictionary:
	var state_result := _build_state()
	if not state_result.ok:
		return state_result

	var result: Dictionary = SortieSystem.create_sortie(
		state_result.state,
		"CITY_TEST_A",
		"OFF_TEST_PLAYER",
		"ROUTE_TEST_A_B",
		8000,
		60000
	)
	if result.ok:
		return {"ok": false, "message": "expected insufficient food to fail"}
	if state_result.state.cities.CITY_TEST_A.troops != 20000:
		return {"ok": false, "message": "troops changed after failed sortie"}
	if state_result.state.cities.CITY_TEST_A.food != 50000:
		return {"ok": false, "message": "food changed after failed sortie"}
	for error in result.errors:
		if str(error).contains("city food is insufficient"):
			return {"ok": true}
	return {"ok": false, "message": "expected insufficient food error, got %s" % [result.errors]}


func _build_state() -> Dictionary:
	var loaded: Dictionary = CoreDataLoader.load_and_validate("res://data/prototype_v0_1/core_test_data.json")
	if not loaded.ok:
		return {"ok": false, "message": "data failed to load: %s" % [loaded.errors]}
	var state_result: Dictionary = CoreStateFactory.build_from_dataset(loaded.dataset)
	if not state_result.ok:
		return {"ok": false, "message": "state failed to build: %s" % [state_result.errors]}
	return {"ok": true, "state": state_result.state}

