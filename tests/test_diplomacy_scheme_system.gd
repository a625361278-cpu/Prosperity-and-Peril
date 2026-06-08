extends SceneTree

const CoreDataLoader = preload("res://scripts/data/core_data_loader.gd")
const CoreStateFactory = preload("res://scripts/simulation/core_state_factory.gd")
const DiplomacySchemeSystem = preload("res://scripts/simulation/diplomacy_scheme_system.gd")


var _failed := 0


func _initialize() -> void:
	_run("diplomacy action creates bilateral truce state and log", _test_diplomacy_truce)
	_run("diplomacy action refuses insufficient gold without state change", _test_diplomacy_insufficient_gold)
	_run("diplomacy action rejects non integer cost", _test_diplomacy_rejects_non_integer_cost)
	_run("scheme action requires actor from source force", _test_scheme_actor_force_check)
	_run("scheme action applies effect and records scheme result", _test_scheme_success)
	quit(_failed)


func _run(test_name: String, test_func: Callable) -> void:
	var result: Dictionary = test_func.call()
	if result.get("ok", false):
		print("PASS: %s" % test_name)
	else:
		_failed += 1
		push_error("FAIL: %s -> %s" % [test_name, result.get("message", "no message")])


func _test_diplomacy_truce() -> Dictionary:
	var state_result := _build_state()
	if not state_result.ok:
		return state_result
	var action := {
		"id": "DIP_TEST_TRUCE",
		"action_type": "truce",
		"source_force_id": "FORCE_PLAYER",
		"target_force_id": "FORCE_ENEMY",
		"cost_gold": 100,
		"new_state": "truce",
		"duration_days": 30,
	}
	var result: Dictionary = DiplomacySchemeSystem.execute_diplomacy_action(state_result.state, action)
	if not result.ok:
		return {"ok": false, "message": "expected diplomacy success, got %s" % [result.errors]}
	if state_result.state.forces.FORCE_PLAYER.gold != 900:
		return {"ok": false, "message": "expected source force gold 900"}
	var relation_key := DiplomacySchemeSystem.relation_key("FORCE_ENEMY", "FORCE_PLAYER")
	if not state_result.state.diplomacy_states.has(relation_key):
		return {"ok": false, "message": "expected bilateral diplomacy state"}
	if state_result.state.diplomacy_states[relation_key].state != "truce":
		return {"ok": false, "message": "expected truce state"}
	if not state_result.state.diplomacy_logs.has("DIPLOG_1"):
		return {"ok": false, "message": "expected diplomacy log"}
	return {"ok": true}


func _test_diplomacy_insufficient_gold() -> Dictionary:
	var state_result := _build_state()
	if not state_result.ok:
		return state_result
	state_result.state.forces.FORCE_PLAYER.gold = 50
	var action := {
		"id": "DIP_TEST_TRUCE",
		"action_type": "truce",
		"source_force_id": "FORCE_PLAYER",
		"target_force_id": "FORCE_ENEMY",
		"cost_gold": 100,
		"new_state": "truce",
		"duration_days": 30,
	}
	var result: Dictionary = DiplomacySchemeSystem.execute_diplomacy_action(state_result.state, action)
	if result.ok:
		return {"ok": false, "message": "expected insufficient gold failure"}
	if state_result.state.forces.FORCE_PLAYER.gold != 50:
		return {"ok": false, "message": "gold changed after failed diplomacy"}
	if not state_result.state.diplomacy_states.is_empty():
		return {"ok": false, "message": "diplomacy state changed after failed diplomacy"}
	for error in result.errors:
		if str(error).contains("source force gold is insufficient"):
			return {"ok": true}
	return {"ok": false, "message": "expected insufficient gold error, got %s" % [result.errors]}


func _test_diplomacy_rejects_non_integer_cost() -> Dictionary:
	var state_result := _build_state()
	if not state_result.ok:
		return state_result
	var action := {
		"id": "DIP_TEST_BAD_COST",
		"action_type": "truce",
		"source_force_id": "FORCE_PLAYER",
		"target_force_id": "FORCE_ENEMY",
		"cost_gold": "100",
		"new_state": "truce",
		"duration_days": 30,
	}
	var result: Dictionary = DiplomacySchemeSystem.execute_diplomacy_action(state_result.state, action)
	if result.ok:
		return {"ok": false, "message": "expected invalid cost failure"}
	if state_result.state.forces.FORCE_PLAYER.gold != 1000:
		return {"ok": false, "message": "gold changed after invalid cost"}
	for error in result.errors:
		if str(error).contains("diplomacy_action.cost_gold must be an integer"):
			return {"ok": true}
	return {"ok": false, "message": "expected integer cost error, got %s" % [result.errors]}


func _test_scheme_actor_force_check() -> Dictionary:
	var state_result := _build_state()
	if not state_result.ok:
		return state_result
	var action := _test_scheme_action()
	action.actor_officer_id = "OFF_TEST_ENEMY"
	var result: Dictionary = DiplomacySchemeSystem.execute_scheme_action(state_result.state, action)
	if result.ok:
		return {"ok": false, "message": "expected actor force mismatch failure"}
	for error in result.errors:
		if str(error).contains("scheme actor force does not match source force"):
			return {"ok": true}
	return {"ok": false, "message": "expected actor force error, got %s" % [result.errors]}


func _test_scheme_success() -> Dictionary:
	var state_result := _build_state()
	if not state_result.ok:
		return state_result
	var result: Dictionary = DiplomacySchemeSystem.execute_scheme_action(state_result.state, _test_scheme_action())
	if not result.ok:
		return {"ok": false, "message": "expected scheme success, got %s" % [result.errors]}
	if state_result.state.forces.FORCE_PLAYER.gold != 850:
		return {"ok": false, "message": "expected scheme cost to deduct gold"}
	if state_result.state.cities.CITY_TEST_B.public_order != 55:
		return {"ok": false, "message": "expected scheme effect to reduce target city order"}
	if not state_result.state.scheme_states.has("SCHEME_1"):
		return {"ok": false, "message": "expected scheme state SCHEME_1"}
	if state_result.state.scheme_states.SCHEME_1.status != "resolved_success":
		return {"ok": false, "message": "expected resolved_success scheme status"}
	return {"ok": true}


func _build_state() -> Dictionary:
	var loaded: Dictionary = CoreDataLoader.load_and_validate("res://data/prototype_v0_1/core_test_data.json")
	if not loaded.ok:
		return {"ok": false, "message": "data failed to load: %s" % [loaded.errors]}
	var state_result: Dictionary = CoreStateFactory.build_from_dataset(loaded.dataset)
	if not state_result.ok:
		return {"ok": false, "message": "state failed to build: %s" % [state_result.errors]}
	state_result.state.forces.FORCE_PLAYER.gold = 1000
	return {"ok": true, "state": state_result.state}


func _test_scheme_action() -> Dictionary:
	return {
		"id": "SCHEME_TEST_ORDER",
		"scheme_type": "sabotage_order",
		"source_force_id": "FORCE_PLAYER",
		"target_force_id": "FORCE_ENEMY",
		"actor_officer_id": "OFF_TEST_PLAYER",
		"target_scope": "city",
		"target_id": "CITY_TEST_B",
		"cost_gold": 150,
		"effects": [
			{"target_scope": "city", "target_id": "CITY_TEST_B", "stat_key": "public_order", "operation": "add_flat", "value": -10}
		],
	}
