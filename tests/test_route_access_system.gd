extends SceneTree

const CoreDataLoader = preload("res://scripts/data/core_data_loader.gd")
const CoreStateFactory = preload("res://scripts/simulation/core_state_factory.gd")
const RouteAccessSystem = preload("res://scripts/simulation/route_access_system.gd")
const AITargetSelector = preload("res://scripts/simulation/ai_target_selector.gd")


var _failed := 0


func _initialize() -> void:
	_run("enemy controlled pass blocks movement and requires pass battle", _test_enemy_pass_blocks)
	_run("friendly controlled pass allows movement", _test_friendly_pass_allows)
	_run("river route exposes river battle hint", _test_river_route_hint)
	_run("ai ignores blocked pass route", _test_ai_ignores_blocked_pass_route)
	quit(_failed)


func _run(test_name: String, test_func: Callable) -> void:
	var result: Dictionary = test_func.call()
	if result.get("ok", false):
		print("PASS: %s" % test_name)
	else:
		_failed += 1
		push_error("FAIL: %s -> %s" % [test_name, result.get("message", "no message")])


func _test_enemy_pass_blocks() -> Dictionary:
	var state_result := _build_state()
	if not state_result.ok:
		return state_result
	var result: Dictionary = RouteAccessSystem.evaluate_route_access(state_result.state, "FORCE_PLAYER", "ROUTE_TEST_A_B_PASS")
	if not result.ok:
		return {"ok": false, "message": "expected access evaluation success, got %s" % [result.errors]}
	if result.can_pass:
		return {"ok": false, "message": "expected enemy pass to block movement"}
	if result.required_battle_type != "pass":
		return {"ok": false, "message": "expected pass battle requirement"}
	return {"ok": true}


func _test_friendly_pass_allows() -> Dictionary:
	var state_result := _build_state()
	if not state_result.ok:
		return state_result
	state_result.state.routes.ROUTE_TEST_A_B_PASS.control_force_id = "FORCE_PLAYER"
	var result: Dictionary = RouteAccessSystem.evaluate_route_access(state_result.state, "FORCE_PLAYER", "ROUTE_TEST_A_B_PASS")
	if not result.ok:
		return {"ok": false, "message": "expected access evaluation success, got %s" % [result.errors]}
	if not result.can_pass:
		return {"ok": false, "message": "expected friendly pass to allow movement"}
	return {"ok": true}


func _test_river_route_hint() -> Dictionary:
	var state_result := _build_state()
	if not state_result.ok:
		return state_result
	state_result.state.routes.ROUTE_TEST_A_B_RIVER = {
		"id": "ROUTE_TEST_A_B_RIVER",
		"from_city_id": "CITY_TEST_A",
		"to_city_id": "CITY_TEST_B",
		"route_type": "river",
		"distance": 75.0,
		"terrain_modifier": 1.2,
		"supply_modifier": 0.9,
		"battle_trigger": "river",
		"strategic_node_type": "water_route",
	}
	var result: Dictionary = RouteAccessSystem.evaluate_route_access(state_result.state, "FORCE_PLAYER", "ROUTE_TEST_A_B_RIVER")
	if not result.ok:
		return {"ok": false, "message": "expected river route success, got %s" % [result.errors]}
	if not result.can_pass:
		return {"ok": false, "message": "expected river route to be passable"}
	if result.required_battle_type != "river":
		return {"ok": false, "message": "expected river battle hint"}
	return {"ok": true}


func _test_ai_ignores_blocked_pass_route() -> Dictionary:
	var state_result := _build_state()
	if not state_result.ok:
		return state_result
	var result: Dictionary = AITargetSelector.select_attack_target(state_result.state, "FORCE_PLAYER", {
		"troop_count": 8000,
		"speed_base": 12.0,
		"food_cost_per_day": 1000,
	})
	if not result.ok:
		return {"ok": false, "message": "expected AI target selection success, got %s" % [result.errors]}
	if result.route_id != "ROUTE_TEST_A_B":
		return {"ok": false, "message": "expected AI to choose normal road route, got %s" % result.route_id}
	return {"ok": true}


func _build_state() -> Dictionary:
	var loaded: Dictionary = CoreDataLoader.load_and_validate("res://data/prototype_v0_1/core_test_data.json")
	if not loaded.ok:
		return {"ok": false, "message": "data failed to load: %s" % [loaded.errors]}
	var state_result: Dictionary = CoreStateFactory.build_from_dataset(loaded.dataset)
	if not state_result.ok:
		return {"ok": false, "message": "state failed to build: %s" % [state_result.errors]}
	return {"ok": true, "state": state_result.state}
