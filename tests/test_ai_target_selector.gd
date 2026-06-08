extends SceneTree

const CoreDataLoader = preload("res://scripts/data/core_data_loader.gd")
const CoreStateFactory = preload("res://scripts/simulation/core_state_factory.gd")
const DiplomacySchemeSystem = preload("res://scripts/simulation/diplomacy_scheme_system.gd")
const AITargetSelector = preload("res://scripts/simulation/ai_target_selector.gd")


var _failed := 0


func _initialize() -> void:
	_run("ai selects closest valid enemy target", _test_selects_closest_valid_target)
	_run("ai refuses targets when origin supply is insufficient", _test_refuses_insufficient_supply)
	_run("ai ignores same force target city", _test_ignores_same_force_target)
	_run("ai ignores truce target", _test_ignores_truce_target)
	_run("ai fails loudly when route data is malformed", _test_malformed_route_fails_loudly)
	quit(_failed)


func _run(test_name: String, test_func: Callable) -> void:
	var result: Dictionary = test_func.call()
	if result.get("ok", false):
		print("PASS: %s" % test_name)
	else:
		_failed += 1
		push_error("FAIL: %s -> %s" % [test_name, result.get("message", "no message")])


func _test_selects_closest_valid_target() -> Dictionary:
	var state_result := _build_state_with_second_target()
	if not state_result.ok:
		return state_result
	var result: Dictionary = AITargetSelector.select_attack_target(state_result.state, "FORCE_PLAYER", _standard_options())
	if not result.ok:
		return {"ok": false, "message": "expected target selection success, got %s" % [result.errors]}
	if result.target_city_id != "CITY_TEST_B":
		return {"ok": false, "message": "expected closest target CITY_TEST_B, got %s" % result.target_city_id}
	if result.route_id != "ROUTE_TEST_A_B":
		return {"ok": false, "message": "expected route ROUTE_TEST_A_B"}
	if int(result.days_required) != 5:
		return {"ok": false, "message": "expected 5 required days"}
	if int(result.required_food) != 5000:
		return {"ok": false, "message": "expected 5000 required food"}
	return {"ok": true}


func _test_refuses_insufficient_supply() -> Dictionary:
	var state_result := _build_state()
	if not state_result.ok:
		return state_result
	state_result.state.cities.CITY_TEST_A.food = 4000
	var result: Dictionary = AITargetSelector.select_attack_target(state_result.state, "FORCE_PLAYER", _standard_options())
	if result.ok:
		return {"ok": false, "message": "expected no valid target with insufficient food"}
	if state_result.state.cities.CITY_TEST_A.food != 4000:
		return {"ok": false, "message": "selector mutated city food"}
	for error in result.errors:
		if str(error).contains("no valid attack target"):
			return {"ok": true}
	return {"ok": false, "message": "expected no valid target error, got %s" % [result.errors]}


func _test_ignores_same_force_target() -> Dictionary:
	var state_result := _build_state()
	if not state_result.ok:
		return state_result
	state_result.state.cities.CITY_TEST_B.force_id = "FORCE_PLAYER"
	var result: Dictionary = AITargetSelector.select_attack_target(state_result.state, "FORCE_PLAYER", _standard_options())
	if result.ok:
		return {"ok": false, "message": "expected no target when route target belongs to source force"}
	for error in result.errors:
		if str(error).contains("no valid attack target"):
			return {"ok": true}
	return {"ok": false, "message": "expected no valid target error, got %s" % [result.errors]}


func _test_ignores_truce_target() -> Dictionary:
	var state_result := _build_state()
	if not state_result.ok:
		return state_result
	state_result.state.forces.FORCE_PLAYER.gold = 1000
	var diplomacy_result: Dictionary = DiplomacySchemeSystem.execute_diplomacy_action(state_result.state, {
		"id": "DIP_AI_TRUCE",
		"action_type": "truce",
		"source_force_id": "FORCE_PLAYER",
		"target_force_id": "FORCE_ENEMY",
		"cost_gold": 100,
		"new_state": "truce",
		"duration_days": 30,
	})
	if not diplomacy_result.ok:
		return {"ok": false, "message": "truce setup failed: %s" % [diplomacy_result.errors]}
	var result: Dictionary = AITargetSelector.select_attack_target(state_result.state, "FORCE_PLAYER", _standard_options())
	if result.ok:
		return {"ok": false, "message": "expected truce target to be ignored"}
	for error in result.errors:
		if str(error).contains("no valid attack target"):
			return {"ok": true}
	return {"ok": false, "message": "expected no valid target error, got %s" % [result.errors]}


func _test_malformed_route_fails_loudly() -> Dictionary:
	var state_result := _build_state()
	if not state_result.ok:
		return state_result
	state_result.state.routes.ROUTE_TEST_A_B.erase("terrain_modifier")
	var result: Dictionary = AITargetSelector.select_attack_target(state_result.state, "FORCE_PLAYER", _standard_options())
	if result.ok:
		return {"ok": false, "message": "expected malformed route failure"}
	for error in result.errors:
		if str(error).contains("route missing required field terrain_modifier"):
			return {"ok": true}
	return {"ok": false, "message": "expected malformed route error, got %s" % [result.errors]}


func _build_state() -> Dictionary:
	var loaded: Dictionary = CoreDataLoader.load_and_validate("res://data/prototype_v0_1/core_test_data.json")
	if not loaded.ok:
		return {"ok": false, "message": "data failed to load: %s" % [loaded.errors]}
	var state_result: Dictionary = CoreStateFactory.build_from_dataset(loaded.dataset)
	if not state_result.ok:
		return {"ok": false, "message": "state failed to build: %s" % [state_result.errors]}
	return {"ok": true, "state": state_result.state}


func _build_state_with_second_target() -> Dictionary:
	var state_result := _build_state()
	if not state_result.ok:
		return state_result
	state_result.state.cities.CITY_TEST_C = {
		"id": "CITY_TEST_C",
		"name": "测试丙城",
		"force_id": "FORCE_ENEMY",
		"troops": 12000,
		"food": 30000,
		"public_order": 65,
		"morale_public": 60,
		"recovery_state": "normal",
	}
	state_result.state.routes.ROUTE_TEST_A_C = {
		"id": "ROUTE_TEST_A_C",
		"from_city_id": "CITY_TEST_A",
		"to_city_id": "CITY_TEST_C",
		"route_type": "road",
		"distance": 120.0,
		"terrain_modifier": 1.0,
		"supply_modifier": 1.0,
		"battle_trigger": "field",
	}
	return state_result


func _standard_options() -> Dictionary:
	return {
		"troop_count": 8000,
		"speed_base": 12.0,
		"food_cost_per_day": 1000,
	}
