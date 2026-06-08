extends SceneTree

const CoreDataLoader = preload("res://scripts/data/core_data_loader.gd")
const CoreStateFactory = preload("res://scripts/simulation/core_state_factory.gd")
const SortieSystem = preload("res://scripts/simulation/sortie_system.gd")
const MarchSystem = preload("res://scripts/simulation/march_system.gd")
const BattleSystem = preload("res://scripts/simulation/battle_system.gd")


var _failed := 0


func _initialize() -> void:
	_run("engaged army resolves battle and captures target city", _test_resolve_battle_and_capture)
	_run("battle refuses non-engaged army", _test_refuses_non_engaged_army)
	_run("battle result is written back to army and city", _test_battle_result_feedback)
	quit(_failed)


func _run(test_name: String, test_func: Callable) -> void:
	var result: Dictionary = test_func.call()
	if result.get("ok", false):
		print("PASS: %s" % test_name)
	else:
		_failed += 1
		push_error("FAIL: %s -> %s" % [test_name, result.get("message", "no message")])


func _test_resolve_battle_and_capture() -> Dictionary:
	var setup := _create_engaged_army()
	if not setup.ok:
		return setup

	var result: Dictionary = BattleSystem.resolve_city_battle(setup.state, setup.army_id, "CITY_TEST_B")
	if not result.ok:
		return {"ok": false, "message": "expected battle success, got %s" % [result.errors]}
	if result.winner != "attacker":
		return {"ok": false, "message": "expected attacker victory, got %s" % result.winner}
	if setup.state.cities.CITY_TEST_B.force_id != "FORCE_PLAYER":
		return {"ok": false, "message": "target city owner did not change to player"}
	if setup.state.cities.CITY_TEST_B.recovery_state != "occupied":
		return {"ok": false, "message": "captured city did not enter occupied state"}
	return {"ok": true}


func _test_refuses_non_engaged_army() -> Dictionary:
	var setup := _create_mobilizing_army()
	if not setup.ok:
		return setup

	var result: Dictionary = BattleSystem.resolve_city_battle(setup.state, setup.army_id, "CITY_TEST_B")
	if result.ok:
		return {"ok": false, "message": "expected non-engaged army to fail"}
	for error in result.errors:
		if str(error).contains("army must be engaged before battle"):
			return {"ok": true}
	return {"ok": false, "message": "expected engaged-state error, got %s" % [result.errors]}


func _test_battle_result_feedback() -> Dictionary:
	var setup := _create_engaged_army()
	if not setup.ok:
		return setup

	BattleSystem.resolve_city_battle(setup.state, setup.army_id, "CITY_TEST_B")
	var army: Dictionary = setup.state.armies[setup.army_id]
	var city: Dictionary = setup.state.cities.CITY_TEST_B
	if army.state != "victorious":
		return {"ok": false, "message": "expected victorious army state"}
	if army.last_battle_result != "attacker_victory":
		return {"ok": false, "message": "expected attacker_victory feedback"}
	if army.troop_count >= 8000:
		return {"ok": false, "message": "expected battle to reduce attacker troops"}
	if city.troops != 0:
		return {"ok": false, "message": "expected defender troops to be cleared after capture"}
	if not setup.state.battle_logs.has("BATTLE_1"):
		return {"ok": false, "message": "expected battle log BATTLE_1"}
	return {"ok": true}


func _create_engaged_army() -> Dictionary:
	var setup := _create_mobilizing_army()
	if not setup.ok:
		return setup
	var march_result: Dictionary = MarchSystem.start_march(setup.state, setup.army_id, 12.0, 1000)
	if not march_result.ok:
		return {"ok": false, "message": "march start failed: %s" % [march_result.errors]}
	for _i in 5:
		var advance: Dictionary = MarchSystem.advance_army_one_day(setup.state, setup.army_id)
		if not advance.ok:
			return {"ok": false, "message": "march advance failed: %s" % [advance.errors]}
	return setup


func _create_mobilizing_army() -> Dictionary:
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
	if not sortie.ok:
		return {"ok": false, "message": "sortie failed: %s" % [sortie.errors]}
	return {"ok": true, "state": state_result.state, "army_id": sortie.army_id}

