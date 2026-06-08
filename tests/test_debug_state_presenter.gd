extends SceneTree

const CoreDataLoader = preload("res://scripts/data/core_data_loader.gd")
const CoreStateFactory = preload("res://scripts/simulation/core_state_factory.gd")
const SortieSystem = preload("res://scripts/simulation/sortie_system.gd")
const MarchSystem = preload("res://scripts/simulation/march_system.gd")
const BattleSystem = preload("res://scripts/simulation/battle_system.gd")
const DebugStatePresenter = preload("res://scripts/ui/debug_state_presenter.gd")


var _failed := 0


func _initialize() -> void:
	_run("debug snapshot exposes real runtime state", _test_debug_snapshot)
	_run("debug snapshot fails when required state is missing", _test_missing_state_fails)
	quit(_failed)


func _run(test_name: String, test_func: Callable) -> void:
	var result: Dictionary = test_func.call()
	if result.get("ok", false):
		print("PASS: %s" % test_name)
	else:
		_failed += 1
		push_error("FAIL: %s -> %s" % [test_name, result.get("message", "no message")])


func _test_debug_snapshot() -> Dictionary:
	var state_result := _build_state_after_battle()
	if not state_result.ok:
		return state_result

	var result: Dictionary = DebugStatePresenter.build_snapshot(state_result.state)
	if not result.ok:
		return {"ok": false, "message": "expected snapshot success, got %s" % [result.errors]}
	var snapshot: Dictionary = result.snapshot
	if snapshot.current_day != 0:
		return {"ok": false, "message": "expected current_day 0"}
	if snapshot.cities.size() != 2:
		return {"ok": false, "message": "expected 2 cities in debug snapshot"}
	if snapshot.forces.size() != 2:
		return {"ok": false, "message": "expected 2 forces in debug snapshot"}
	if snapshot.forces[0].legitimacy != 35 and snapshot.forces[1].legitimacy != 62:
		return {"ok": false, "message": "expected legitimacy values in force snapshot"}
	if snapshot.officers.size() != 2:
		return {"ok": false, "message": "expected 2 officers in debug snapshot"}
	if snapshot.officers[0].loyalty != 58 and snapshot.officers[1].loyalty != 90:
		return {"ok": false, "message": "expected loyalty values in officer snapshot"}
	if snapshot.armies.size() != 1:
		return {"ok": false, "message": "expected 1 army in debug snapshot"}
	if snapshot.routes.size() != 1:
		return {"ok": false, "message": "expected 1 route in debug snapshot"}
	if snapshot.battle_logs.size() != 1:
		return {"ok": false, "message": "expected 1 battle log in debug snapshot"}
	if snapshot.cities[1].recovery_state != "occupied":
		return {"ok": false, "message": "expected occupied city state to be visible"}
	if snapshot.cities[0].gentry_support != 72:
		return {"ok": false, "message": "expected gentry support to be visible"}
	if snapshot.armies[0].state != "victorious":
		return {"ok": false, "message": "expected victorious army state to be visible"}
	return {"ok": true}


func _test_missing_state_fails() -> Dictionary:
	var result: Dictionary = DebugStatePresenter.build_snapshot({"current_day": 0})
	if result.ok:
		return {"ok": false, "message": "expected missing state to fail"}
	for error in result.errors:
		if str(error).contains("debug snapshot missing state key cities"):
			return {"ok": true}
	return {"ok": false, "message": "expected missing cities error, got %s" % [result.errors]}


func _build_state_after_battle() -> Dictionary:
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
	BattleSystem.resolve_city_battle(state_result.state, sortie.army_id, "CITY_TEST_B")
	return {"ok": true, "state": state_result.state}
