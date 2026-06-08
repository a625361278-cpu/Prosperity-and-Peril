extends SceneTree

const CoreDataLoader = preload("res://scripts/data/core_data_loader.gd")
const CoreStateFactory = preload("res://scripts/simulation/core_state_factory.gd")
const SortieSystem = preload("res://scripts/simulation/sortie_system.gd")
const MarchSystem = preload("res://scripts/simulation/march_system.gd")
const BattleSystem = preload("res://scripts/simulation/battle_system.gd")
const PostwarIntegrationSystem = preload("res://scripts/simulation/postwar_integration_system.gd")
const DiplomacySchemeSystem = preload("res://scripts/simulation/diplomacy_scheme_system.gd")
const LegitimacySystem = preload("res://scripts/simulation/legitimacy_system.gd")
const LocalGovernanceSystem = preload("res://scripts/simulation/local_governance_system.gd")
const SaveSystem = preload("res://scripts/save/save_system.gd")

const SAVE_PATH := "user://prototype_v0_1_save_test.json"


var _failed := 0


func _initialize() -> void:
	_run("save and load restores dynamic runtime state", _test_save_and_load_restores_state)
	_run("save file does not copy static master names", _test_save_omits_static_names)
	_run("save file writes current schema version", _test_save_writes_current_schema_version)
	_run("missing save file fails loudly", _test_missing_save_fails)
	quit(_failed)


func _run(test_name: String, test_func: Callable) -> void:
	var result: Dictionary = test_func.call()
	if result.get("ok", false):
		print("PASS: %s" % test_name)
	else:
		_failed += 1
		push_error("FAIL: %s -> %s" % [test_name, result.get("message", "no message")])


func _test_save_and_load_restores_state() -> Dictionary:
	var setup := _build_state_after_integration()
	if not setup.ok:
		return setup
	var save_result: Dictionary = SaveSystem.save_state(setup.state, SAVE_PATH)
	if not save_result.ok:
		return {"ok": false, "message": "save failed: %s" % [save_result.errors]}

	var loaded_data: Dictionary = CoreDataLoader.load_and_validate("res://data/prototype_v0_1/core_test_data.json")
	var load_result: Dictionary = SaveSystem.load_state(loaded_data.dataset, SAVE_PATH)
	if not load_result.ok:
		return {"ok": false, "message": "load failed: %s" % [load_result.errors]}

	var loaded_state: Dictionary = load_result.state
	if loaded_state.cities.CITY_TEST_B.force_id != "FORCE_PLAYER":
		return {"ok": false, "message": "loaded city owner mismatch"}
	if loaded_state.cities.CITY_TEST_B.recovery_state != "occupied":
		return {"ok": false, "message": "loaded recovery_state mismatch"}
	if loaded_state.cities.CITY_TEST_B.integration_progress != 25:
		return {"ok": false, "message": "loaded integration_progress mismatch"}
	if loaded_state.armies.ARMY_1.state != "victorious":
		return {"ok": false, "message": "loaded army state mismatch"}
	if loaded_state.armies.ARMY_1.food_current != 11000:
		return {"ok": false, "message": "loaded army food mismatch"}
	if not loaded_state.battle_logs.has("BATTLE_1"):
		return {"ok": false, "message": "loaded battle log missing"}
	if not loaded_state.diplomacy_states.has(DiplomacySchemeSystem.relation_key("FORCE_PLAYER", "FORCE_ENEMY")):
		return {"ok": false, "message": "loaded diplomacy state missing"}
	if not loaded_state.diplomacy_logs.has("DIPLOG_1"):
		return {"ok": false, "message": "loaded diplomacy log missing"}
	if not loaded_state.scheme_states.has("SCHEME_1"):
		return {"ok": false, "message": "loaded scheme state missing"}
	if loaded_state.next_diplomacy_log_seq != 2 or loaded_state.next_scheme_seq != 2:
		return {"ok": false, "message": "loaded diplomacy or scheme seq mismatch"}
	if loaded_state.forces.FORCE_PLAYER.legitimacy != 67:
		return {"ok": false, "message": "loaded force legitimacy mismatch"}
	if not loaded_state.legitimacy_logs.has("LEGLOG_1"):
		return {"ok": false, "message": "loaded legitimacy log missing"}
	if loaded_state.next_legitimacy_log_seq != 2:
		return {"ok": false, "message": "loaded legitimacy seq mismatch"}
	if loaded_state.cities.CITY_TEST_B.gentry_support != 35:
		return {"ok": false, "message": "loaded city gentry_support mismatch"}
	if not loaded_state.local_governance_logs.has("LGOVLOG_1"):
		return {"ok": false, "message": "loaded local governance log missing"}
	if loaded_state.next_local_governance_log_seq != 2:
		return {"ok": false, "message": "loaded local governance seq mismatch"}
	return {"ok": true}


func _test_save_omits_static_names() -> Dictionary:
	var setup := _build_state_after_integration()
	if not setup.ok:
		return setup
	SaveSystem.save_state(setup.state, SAVE_PATH)
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {"ok": false, "message": "could not read save file"}
	var text := file.get_as_text()
	if text.contains("测试甲城") or text.contains("测试乙城"):
		return {"ok": false, "message": "save file copied static city names"}
	return {"ok": true}


func _test_save_writes_current_schema_version() -> Dictionary:
	var setup := _build_state_after_integration()
	if not setup.ok:
		return setup
	var save_result: Dictionary = SaveSystem.save_state(setup.state, SAVE_PATH)
	if not save_result.ok:
		return {"ok": false, "message": "save failed: %s" % [save_result.errors]}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {"ok": false, "message": "could not read save file"}
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed == null or not parsed is Dictionary:
		return {"ok": false, "message": "save file is not valid JSON"}
	if int(parsed.version) != 4:
		return {"ok": false, "message": "expected save version 4, got %s" % parsed.version}
	return {"ok": true}


func _test_missing_save_fails() -> Dictionary:
	var loaded_data: Dictionary = CoreDataLoader.load_and_validate("res://data/prototype_v0_1/core_test_data.json")
	var result: Dictionary = SaveSystem.load_state(loaded_data.dataset, "user://missing_save_file.json")
	if result.ok:
		return {"ok": false, "message": "expected missing save to fail"}
	for error in result.errors:
		if str(error).contains("save file not found"):
			return {"ok": true}
	return {"ok": false, "message": "expected missing save error, got %s" % [result.errors]}


func _build_state_after_integration() -> Dictionary:
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
	PostwarIntegrationSystem.apply_integration_task(state_result.state, "CITY_TEST_B", "OFF_TEST_PLAYER")
	state_result.state.forces.FORCE_PLAYER.gold = 1000
	var diplomacy_result: Dictionary = DiplomacySchemeSystem.execute_diplomacy_action(state_result.state, {
		"id": "DIP_SAVE_TRUCE",
		"action_type": "truce",
		"source_force_id": "FORCE_PLAYER",
		"target_force_id": "FORCE_ENEMY",
		"cost_gold": 100,
		"new_state": "truce",
		"duration_days": 30,
	})
	if not diplomacy_result.ok:
		return {"ok": false, "message": "diplomacy setup failed: %s" % [diplomacy_result.errors]}
	var scheme_result: Dictionary = DiplomacySchemeSystem.execute_scheme_action(state_result.state, {
		"id": "SCHEME_SAVE_ORDER",
		"scheme_type": "sabotage_order",
		"source_force_id": "FORCE_PLAYER",
		"target_force_id": "FORCE_ENEMY",
		"actor_officer_id": "OFF_TEST_PLAYER",
		"target_scope": "city",
		"target_id": "CITY_TEST_B",
		"cost_gold": 150,
		"effects": [
			{"target_scope": "city", "target_id": "CITY_TEST_B", "stat_key": "public_order", "operation": "add_flat", "value": -5}
		],
	})
	if not scheme_result.ok:
		return {"ok": false, "message": "scheme setup failed: %s" % [scheme_result.errors]}
	var legitimacy_result: Dictionary = LegitimacySystem.apply_force_reputation_change(state_result.state, {
		"id": "LEG_SAVE_TEST",
		"force_id": "FORCE_PLAYER",
		"legitimacy_delta": 5,
		"prestige_delta": -3,
		"reason": "postwar_reputation",
		"source_type": "save_test",
	})
	if not legitimacy_result.ok:
		return {"ok": false, "message": "legitimacy setup failed: %s" % [legitimacy_result.errors]}
	var governance_result: Dictionary = LocalGovernanceSystem.apply_gentry_pressure_rule(state_result.state, {
		"id": "LGOV_SAVE_TEST",
		"city_id": "CITY_TEST_B",
		"gentry_support_below": 40,
		"public_order_delta": -1,
		"morale_public_delta": -1,
		"integration_progress_delta": 0,
		"reason": "save_test",
	})
	if not governance_result.ok:
		return {"ok": false, "message": "local governance setup failed: %s" % [governance_result.errors]}
	return {"ok": true, "state": state_result.state}
