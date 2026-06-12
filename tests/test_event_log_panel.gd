extends SceneTree

const CoreDataLoader = preload("res://scripts/data/core_data_loader.gd")
const CoreStateFactory = preload("res://scripts/simulation/core_state_factory.gd")
const LegitimacySystem = preload("res://scripts/simulation/legitimacy_system.gd")
const LocalGovernanceSystem = preload("res://scripts/simulation/local_governance_system.gd")
const OfficerLoyaltySystem = preload("res://scripts/simulation/officer_loyalty_system.gd")
const DiplomacySchemeSystem = preload("res://scripts/simulation/diplomacy_scheme_system.gd")
const EventLogPresenter = preload("res://scripts/ui/event_log_presenter.gd")


var _failed := 0


func _initialize() -> void:
	_run("event log presenter aggregates real runtime logs", _test_presenter_aggregates_logs)
	_run("event log panel opens real runtime logs", _test_panel_opens_logs)
	_run("event log panel exposes empty logs", _test_panel_exposes_empty_logs)
	_run("event log presenter rejects malformed logs", _test_presenter_rejects_malformed_logs)
	quit(_failed)


func _run(test_name: String, test_func: Callable) -> void:
	var result: Dictionary = test_func.call()
	if result.get("ok", false):
		print("PASS: %s" % test_name)
	else:
		_failed += 1
		push_error("FAIL: %s -> %s" % [test_name, result.get("message", "no message")])


func _test_presenter_aggregates_logs() -> Dictionary:
	var setup := _create_logged_state()
	if not setup.ok:
		return setup
	var result: Dictionary = EventLogPresenter.build_event_index(setup.state)
	if not result.ok:
		return {"ok": false, "message": "expected event log success, got %s" % [result.errors]}
	if result.events.size() != 5:
		return {"ok": false, "message": "expected five event rows, got %s" % str(result.events.size())}
	var diplomacy: Dictionary = EventLogPresenter.build_event_index(setup.state, "diplomacy")
	if not diplomacy.ok:
		return {"ok": false, "message": "expected diplomacy filter success"}
	if diplomacy.events.size() != 2:
		return {"ok": false, "message": "expected diplomacy and scheme rows"}
	return {"ok": true}


func _test_panel_opens_logs() -> Dictionary:
	var setup := _create_logged_state()
	if not setup.ok:
		return setup
	var panel_result := _instantiate_panel()
	if not panel_result.ok:
		return panel_result
	var panel = panel_result.node
	var open_result: Dictionary = panel.open_with_state(setup.state)
	if not open_result.ok:
		panel.queue_free()
		return {"ok": false, "message": "expected event log panel open success, got %s" % [open_result.errors]}
	if panel.get_event_count() != 5:
		panel.queue_free()
		return {"ok": false, "message": "expected five event rows"}
	if panel.get_detail_text().is_empty():
		panel.queue_free()
		return {"ok": false, "message": "event detail must not be empty"}
	panel.queue_free()
	return {"ok": true}


func _test_panel_exposes_empty_logs() -> Dictionary:
	var state_result := _build_state()
	if not state_result.ok:
		return state_result
	var panel_result := _instantiate_panel()
	if not panel_result.ok:
		return panel_result
	var panel = panel_result.node
	var open_result: Dictionary = panel.open_with_state(state_result.state)
	if not open_result.ok:
		panel.queue_free()
		return {"ok": false, "message": "empty logs should be a visible empty state"}
	if panel.get_event_count() != 0:
		panel.queue_free()
		return {"ok": false, "message": "expected no event rows"}
	if not panel.get_message_text().contains("事件日志为空"):
		panel.queue_free()
		return {"ok": false, "message": "empty state message mismatch"}
	panel.queue_free()
	return {"ok": true}


func _test_presenter_rejects_malformed_logs() -> Dictionary:
	var setup := _create_logged_state()
	if not setup.ok:
		return setup
	setup.state.legitimacy_logs.LEGLOG_1.erase("reason")
	var result: Dictionary = EventLogPresenter.build_event_index(setup.state)
	if result.ok:
		return {"ok": false, "message": "expected malformed legitimacy log to fail"}
	for error in result.errors:
		if str(error).contains("event log legitimacy LEGLOG_1 missing field reason"):
			return {"ok": true}
	return {"ok": false, "message": "expected malformed log error, got %s" % [result.errors]}


func _instantiate_panel() -> Dictionary:
	var scene := load("res://scenes/event_log_panel.tscn")
	if scene == null:
		return {"ok": false, "message": "event log panel scene missing"}
	var panel: Control = scene.instantiate()
	get_root().add_child(panel)
	return {"ok": true, "node": panel}


func _create_logged_state() -> Dictionary:
	var state_result := _build_state()
	if not state_result.ok:
		return state_result
	var state: Dictionary = state_result.state
	state.forces.FORCE_PLAYER.gold = 1000
	var legitimacy: Dictionary = LegitimacySystem.apply_force_reputation_change(state, {
		"id": "LEG_TEST",
		"force_id": "FORCE_PLAYER",
		"legitimacy_delta": 3,
		"prestige_delta": 2,
		"reason": "测试正统事件",
		"source_type": "test",
	})
	if not legitimacy.ok:
		return {"ok": false, "message": "legitimacy log failed: %s" % [legitimacy.errors]}
	var governance: Dictionary = LocalGovernanceSystem.apply_gentry_pressure_rule(state, {
		"id": "LGOV_TEST",
		"city_id": "CITY_TEST_B",
		"gentry_support_below": 50,
		"public_order_delta": -5,
		"morale_public_delta": -4,
		"integration_progress_delta": 0,
		"reason": "测试士族压力",
	})
	if not governance.ok or not governance.triggered:
		return {"ok": false, "message": "local governance log failed: %s" % [governance.errors]}
	var loyalty: Dictionary = OfficerLoyaltySystem.apply_loyalty_change(state, {
		"id": "LOY_TEST",
		"officer_id": "OFF_TEST_PLAYER",
		"loyalty_delta": -5,
		"reason": "测试忠诚事件",
		"source_type": "test",
	})
	if not loyalty.ok:
		return {"ok": false, "message": "loyalty log failed: %s" % [loyalty.errors]}
	var diplomacy: Dictionary = DiplomacySchemeSystem.execute_diplomacy_action(state, {
		"id": "DIP_TEST",
		"action_type": "truce",
		"source_force_id": "FORCE_PLAYER",
		"target_force_id": "FORCE_ENEMY",
		"cost_gold": 100,
		"new_state": "truce",
		"duration_days": 30,
	})
	if not diplomacy.ok:
		return {"ok": false, "message": "diplomacy log failed: %s" % [diplomacy.errors]}
	var scheme: Dictionary = DiplomacySchemeSystem.execute_scheme_action(state, {
		"id": "SCHEME_TEST",
		"scheme_type": "sabotage_order",
		"source_force_id": "FORCE_PLAYER",
		"target_force_id": "FORCE_ENEMY",
		"actor_officer_id": "OFF_TEST_PLAYER",
		"target_scope": "city",
		"target_id": "CITY_TEST_B",
		"cost_gold": 150,
		"effects": [
			{"target_scope": "city", "target_id": "CITY_TEST_B", "stat_key": "public_order", "operation": "add_flat", "value": -1}
		],
	})
	if not scheme.ok:
		return {"ok": false, "message": "scheme log failed: %s" % [scheme.errors]}
	return {"ok": true, "state": state}


func _build_state() -> Dictionary:
	var loaded: Dictionary = CoreDataLoader.load_and_validate("res://data/prototype_v0_1/core_test_data.json")
	if not loaded.ok:
		return {"ok": false, "message": "core data failed %s" % [loaded.errors]}
	var state_result: Dictionary = CoreStateFactory.build_from_dataset(loaded.dataset)
	if not state_result.ok:
		return {"ok": false, "message": "state build failed %s" % [state_result.errors]}
	return {"ok": true, "state": state_result.state}
